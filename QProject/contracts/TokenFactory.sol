pragma solidity ^0.8.25;

import "./Q.sol";

contract TokenFactory {
    uint256 public constant tokenLaunchGas = 5054544;
    address public constant forwarder = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;

    constructor(){}

    function launchToken(
        address _devFee,
        Q.TokenConfig calldata config
    ) external payable returns(address deployedToken){
        require(msg.value >= 2 * tokenLaunchGas * tx.gasprice,
            "Less than 2x deployment cost");

        deployedToken = address(new Q(
            forwarder,
            _devFee,
            config
        ));
    }
}