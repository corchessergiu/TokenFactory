// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IWETH9Minimal {
    function approve(address guy, uint256 wad) external returns(bool);

    function deposit() external payable;
}