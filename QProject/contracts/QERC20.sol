// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract QERC20 is ERC20Permit {

    address public immutable owner;

    uint256 public totalTokenAmount;

    constructor(string memory tokenName, string memory tokenSymbol, uint256 _totalSupply) ERC20(tokenName,tokenSymbol)
    ERC20Permit(tokenName) {
        owner = msg.sender;
        totalTokenAmount = _totalSupply;
    }

    function mintReward(address account, uint256 amount) external {
        require(msg.sender == owner, "Incorrect caller");
        require(super.totalSupply() < totalTokenAmount, "Already minted");
        _mint(account, amount);
    }
}
