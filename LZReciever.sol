pragma solidity ^0.8.0;

import "https://github.com/LayerZero-Labs/solidity-examples/blob/main/contracts/lzApp/NonblockingLzApp.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface wGHOInterface is IERC20 {
    function mint(address user,uint256 mintAmount) external;
    function burn(uint256 burnAmount) external;
}

contract LZReciever is NonblockingLzApp, Pausable {

    constructor(
        address _Lzendpoint, 
        address _wGHOToken,
        uint16 _senderChain
    ) NonblockingLzApp(_Lzendpoint) {
        wGHOToken = _wGHOToken;
        senderChain = _senderChain;
    }

    // Config and Mappings
    ILayerZeroEndpoint public endpoint;
    address public wGHOToken;
    uint16 public senderChain;
    
    // Events 
    event wGHOBurned(address user,uint256 amountBurned);
    event wGHOIssued(address user,uint256 amountIssued);
    event MessageSent(bytes message, uint16 dstEid);
    event MessageReceived(bytes message, uint16 srcEid);

    // User Functions
    function burnAndRedeemWGHO(uint256 _amount) external whenNotPaused {
        require(_amount>0,"Amount is Zero");
        require(wGHOInterface(wGHOToken).allowance(_msgSender(), address(this)) >= _amount, "Insufficient allowance");
        wGHOInterface(wGHOToken).transferFrom(_msgSender(), address(this), _amount);
        wGHOInterface(wGHOToken).burn(_amount);
        emit wGHOBurned(_msgSender(), _amount);
        sendClaimRequest(_msgSender(),_amount);
    }

    // Bridge Functions
    function _IssuewGHOTokens(bytes memory _messageData) internal {
        (address user, uint256 amount) = abi.decode(_messageData, (address, uint256));
        wGHOInterface(wGHOToken).mint(user,amount);
        emit wGHOIssued(user, amount);
    }

    function sendClaimRequest(address user,uint256 amount) internal{
        bytes memory _messagedata = abi.encode(user,amount);// Construct Message address and amount
        _sendViaLayerZero(senderChain,_messagedata);
    }

    // Send Message via LayerZero
    function _sendViaLayerZero(
        uint16 _dstEid,
        bytes memory _messageData
    ) internal {
        uint16 version = 1;
        uint256 gasForLzReceive = 200000;
        bytes memory adapterParams = abi.encodePacked(version, gasForLzReceive);
        (uint256 messageFee, ) = lzEndpoint.estimateFees(
            _dstEid,
            address(this),
            _messageData,
            false,
            adapterParams
        );
        bytes memory trustedRemote = trustedRemoteLookup[_dstEid];
        require(messageFee < address(this).balance,"Insufficient Fees");
        endpoint.send{value:messageFee}(
            _dstEid,
            trustedRemote,
            _messageData,
            payable(msg.sender),
            address(this),
            bytes("")
        );
        emit MessageSent(_messageData, _dstEid);
    }

    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal override {
        _IssuewGHOTokens(_payload);
        emit MessageReceived(_payload, _srcChainId);
    }

    fallback() external payable {}
    receive() external payable {}
}