pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {QPayment} from "../../contracts/QPayment.sol";
import {Q} from "../../contracts/Q.sol";

contract QPaymentHandler is Test {
    QPayment public qpaymentInstance;

    uint256 public totalFees;

    uint192 public actorSeed = 1;

    address internal currentActor;

    modifier useActor() {
        currentActor = vm.addr(actorSeed);

        vm.startPrank(currentActor);
        _;
        vm.stopPrank();

        actorSeed++;
    }

    constructor(QPayment _qpaymentInstance) {
        qpaymentInstance = _qpaymentInstance;
    }

    function callRegistration(uint256 feeAmount, uint256 waitDays) public useActor {
        uint256 registrationEndTime = qpaymentInstance.endTime();
        if(block.timestamp > registrationEndTime) {
            return;
        }

        waitDays = bound(waitDays, 1, 3 days);

        if(waitDays <= 1 days) {
            feeAmount = bound(feeAmount, 5 ether, 1e30);
        } else if(waitDays <= 2 days) { 
            feeAmount = bound(feeAmount, 6 ether, 1e30);
        } else {
            feeAmount = bound(feeAmount, 7 ether, 1e30);
        }

        vm.deal(currentActor, feeAmount);

        vm.warp(waitDays);
        qpaymentInstance.aiRegister{value: feeAmount}("name");

        if(waitDays <= 1 days) {
            totalFees += 5 ether;
        } else if(waitDays <= 2 days) { 
            totalFees += 6 ether;
        } else {
            totalFees += 7 ether;
        }
    }

    function callDeployQContract(uint192 addressSeed) public { 
        address qContract = qpaymentInstance.qContractAddress();
        if(qContract != address(0)) {
            return;
        }
        
        vm.warp(qpaymentInstance.endTime() + 1);

        vm.assume(addressSeed != 0);
        address qDeployer = vm.addr(addressSeed);

        hoax(qDeployer);

        qpaymentInstance.deployQContract();

        totalFees = 0;
    }
}