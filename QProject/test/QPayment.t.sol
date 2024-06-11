pragma solidity ^0.8.24;

import "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {QPayment} from "../contracts/QPayment.sol";
import {Q} from "../contracts/Q.sol";
import {QPaymentHandler} from "./handlers/QPaymentHandler.sol";

contract QPaymentTest is Test {
    QPayment public qPayment;
    address public user;
    address public paymentDeployer;

    uint256[] public fixtureFeeAmount = [6, 7, 8];


    function setUp() public {
        paymentDeployer = makeAddr("paymentDeployer");
        qPayment = new QPayment(paymentDeployer);
        
        user = makeAddr("user");
        vm.deal(user, 6 ether);
    }

    function test_DevFeeAddrSet() public view {
        assertEq(qPayment.devFee(), paymentDeployer);
    }

    function test_RegisterAI() public{
        vm.expectEmit(address(qPayment));
        emit QPayment.AIRegisterData(user, 5 ether, "name");

        vm.prank(user);
        qPayment.aiRegister{value: 5 ether}("name");

        assertEq(address(qPayment).balance, 5 ether);
        assertEq(qPayment.aiRegisterStatus(user), true);
        assertEq(qPayment.aiAddresses(0), user);
    }

    function test_QContractDeployment() public {
        qPayment.aiRegister{value: 5 ether}("name");

        vm.startPrank(user);
        qPayment.aiRegister{value: 5 ether}("name");

        uint256 userBalanceBeforeDeployment = user.balance;

        vm.warp(qPayment.endTime() + 1);
        qPayment.deployQContract();

        Q qContract = Q(payable(qPayment.qContractAddress()));

        assertEq(user.balance, userBalanceBeforeDeployment + 1 ether);
        assertEq(address(qContract).balance, 6.75 ether);
        assertEq(qContract.cycleAccruedFees(0), 6.75 ether);
        assertEq(qContract.isAIMinerRegistered(address(this)), true);
        assertEq(qContract.isAIMinerRegistered(user), true);
    }

    function test_QContractDeployment_NoRegistrations() public {
        vm.startPrank(user);

        uint256 userBalanceBeforeDeployment = user.balance;

        vm.warp(qPayment.endTime() + 1);

        qPayment.deployQContract();
        
        Q qContract = Q(payable(qPayment.qContractAddress()));
        

        assertEq(user.balance, userBalanceBeforeDeployment);
        assertEq(address(qContract).balance, 0);
        assertEq(qContract.cycleAccruedFees(0), 0); 
    }

    function test_QContractDeployment_OneHundredRegistrations() public{
        address currentUser;        
        for(uint256 seed = 1; seed < 101; seed++) {
            currentUser = vm.addr(seed);
            vm.deal(currentUser, 5 ether);

            vm.prank(currentUser);
            qPayment.aiRegister{value: 5 ether}("name");
        }

        vm.warp(qPayment.endTime() + 1);

        vm.prank(user);

        uint256 startGas = gasleft();
        qPayment.deployQContract();
        console.log("Q deployment tx gas: ", startGas - gasleft());

        Q qContract = Q(payable(qPayment.qContractAddress()));

        for(uint256 index = 0; index < 100; index++) {
            address registeredAIMiner = qPayment.aiAddresses(0);

            assertEq(qContract.isAIMinerRegistered(registeredAIMiner), true);
        }
    }

    function testFail_LateAIRegistration() public {
        vm.warp(3 days);

        vm.prank(user);
        qPayment.aiRegister{value: 7 ether}("name");
    }

    function testFail_InsufficientFeeSent() public {
        vm.startPrank(user);

        qPayment.aiRegister{value: 4.99 ether}("name");

        vm.warp(1 days);
        qPayment.aiRegister{value: 5.99 ether}("name");

        vm.warp(1 days);
        qPayment.aiRegister{value: 6.99 ether}("name");
    }

    function testFuzz_RegisterAI(uint96 feeAmount) public {
        vm.skip(true);
        vm.assume(feeAmount > 5 ether);
        
        vm.deal(user, feeAmount + 1 ether);

        vm.prank(user);
        qPayment.aiRegister{value: feeAmount}("name");
    }
}