// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract ERC20TokenTest is ERC20Permit {

    address public immutable owner;

    constructor() ERC20("Q Token", "Q")
    ERC20Permit("Q Token") {
        owner = msg.sender;
    }

    function mintReward(address account, uint256 amount) external {
        require(msg.sender == owner, "DBXen: caller is not DBXen contract.");
        require(super.totalSupply() < 5010000000000000000000000, "DBXen: max supply already minted");
        _mint(account, amount);
    }
}
