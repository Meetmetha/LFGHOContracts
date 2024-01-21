pragma solidity ^0.8.0;

import "https://github.com/LayerZero-Labs/solidity-examples/blob/main/contracts/lzApp/NonblockingLzApp.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract LzSender is NonblockingLzApp, Pausable {

    constructor(
        address _Lzendpoint, 
        address _GHOToken
    ) NonblockingLzApp(_Lzendpoint) {
        endpoint = ILayerZeroEndpoint(_Lzendpoint);
        GHOToken = _GHOToken;
    }

    // Config and Mappings
    address public GHOToken;
    ILayerZeroEndpoint public endpoint;
    mapping(uint16 => bool) public destchains;
    mapping(address => uint256) public recievedGHO;

    // Events 
    event GHOLocked(address user,uint256 amountBridged,uint16 destChain);
    event GHOUnLocked(address user,uint256 amountUnlocked);
    event MessageSent(bytes message, uint16 dstEid);
    event MessageReceived(bytes message, uint16 srcEid);
    event GHOClaimAdded(address user,uint256 ghoClaimable,uint16 destChain);

    // Destination Chain Configs
    function setDestinationChain(uint16 _destChain) external  onlyOwner {
        destchains[_destChain] = true;
    }

    function pauseDestinationChain(uint16 _destChain) external  onlyOwner {
        destchains[_destChain] = false;
    }

    // User Functions
    function BridgeGHO(uint16 _destChain,uint256 _amount) external whenNotPaused {
        require(destchains[_destChain],"Chain is not supported");
        require(_amount > 0,"Amount is Zero");
        require(IERC20(GHOToken).allowance(_msgSender(), address(this)) >= _amount, "Insufficient allowance");
        IERC20(GHOToken).transferFrom(_msgSender(), address(this), _amount);
        bytes memory messagedata = abi.encode(_msgSender(),_amount);// Construct Message address and amount
        _sendViaLayerZero(_destChain,messagedata);
        emit GHOLocked(_msgSender(), _amount,_destChain);
    }

    function ClaimGHO(uint256 _amount) external whenNotPaused {
        require(recievedGHO[_msgSender()] >= _amount,"Nothing to claim");
        recievedGHO[_msgSender()]=recievedGHO[_msgSender()]-_amount;
        IERC20(GHOToken).transferFrom(address(this),_msgSender(), _amount);
        emit GHOUnLocked(_msgSender(), _amount);
    }

    function getClaimableBalance(address user) external view returns (uint256) {
        return recievedGHO[user];
    }

    // Internal Functions
    function _unlockGHOforUser(uint16 destChain, bytes memory messageData) internal{
        (address user, uint256 amount) = abi.decode(messageData, (address, uint256));
        recievedGHO[user]=recievedGHO[user]+amount;
        emit GHOClaimAdded(user, amount,destChain);
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

    // Recieve LayerZeroMessage
    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal override {
        _unlockGHOforUser(_srcChainId,_payload);
        emit MessageReceived(_payload, _srcChainId);
    }

    // Emergancy Functions
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    fallback() external payable {}
    receive() external payable {}
}