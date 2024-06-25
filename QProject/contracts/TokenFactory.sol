pragma solidity ^0.8.25;

import "./Q.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenFactory is Ownable {
    event TokenLaunched(
        address deployer,
        address factoryToken
    );

    uint256 public constant tokenLaunchGas = 5054544;
    address public constant forwarder = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;

    constructor(){}

    function launchToken(
        address _devFee,
        Q.TokenConfig calldata config
    ) external payable returns(address deployedToken){
        uint256 launchFee = 2 * tokenLaunchGas * tx.gasprice;
        require(msg.value >= launchFee,
            "Less than 2x deployment cost");

        deployedToken = address(new Q(
            forwarder,
            _devFee,
            config
        ));

        emit TokenLaunched(msg.sender, deployedToken);

        _sendViaCall(msg.value - launchFee, msg.sender);
    }

    function withdraw(uint256 amount) external onlyOwner {
        _sendViaCall(amount, msg.sender);
    }

    function _sendViaCall(uint256 amount, address to) internal {
        (bool success,) = payable(to).call{value: amount}("");
        require(success, "Transfer failed.");
    }
}