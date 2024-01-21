// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract wGHO is ERC20, ERC20Permit, Ownable {
    address bridge;
    bool init;
    constructor(
    )
        ERC20("wGHO", "wGHO") ERC20Permit("wGHO")
    {
        init=false;
    }

    modifier OnlyBridge(){
        require(msg.sender == bridge);
        _;
    }
    modifier OnlyOnce(){
        require(init == false);
        _;
    }

    function setBridge(address _bridge) public onlyOwner OnlyOnce {
        bridge = _bridge;
        init=true;
    }

    function mint(address user, uint256 mintAmount) public OnlyBridge {
        _mint(user, mintAmount);
    }

    function burn(uint256 value) public OnlyBridge {
        _burn(msg.sender, value);
    }
}
