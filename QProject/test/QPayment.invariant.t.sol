pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {QPayment} from "../contracts/QPayment.sol";
import {QPaymentHandler} from "./handlers/QPaymentHandler.sol";

import "forge-std/console.sol";

contract QPaymentTest is Test {
    QPayment public qPayment;
    QPaymentHandler public qPaymentHandler;
    address public paymentDeployer;

    function setUp() public {
        paymentDeployer = makeAddr("paymentDeployer");
        qPayment = new QPayment(paymentDeployer);

        qPaymentHandler = new QPaymentHandler(qPayment);
        targetContract(address(qPaymentHandler));
    }

    function invariant_QPaymentBalance_Eq_RegistrationFees_Untill_QDeployment() public view {
        assertEq(address(qPayment).balance, qPaymentHandler.totalFees());
    }
}