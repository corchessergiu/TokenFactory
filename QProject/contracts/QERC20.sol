// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract QERC20 is ERC20Permit {

    address public immutable owner;

    constructor() ERC20("Q Token", "Q")
    ERC20Permit("Q Token") {
        owner = msg.sender;
    }

    function mintReward(address account, uint256 amount) external {
        require(msg.sender == owner, "Q: Incorrect caller");
        require(super.totalSupply() < 120000000000000000000000000, "Q: Already minted");
        _mint(account, amount);
    }
}
