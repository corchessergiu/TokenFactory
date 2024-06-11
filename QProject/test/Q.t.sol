pragma solidity ^0.8.24;

import "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {Q} from "../contracts/Q.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract QTest is Test {
    Q public qContract;
    IERC20 public qERC20;

    address constant nxdDSV = 0xE05430D42842C7B757E5633D19ca65350E01aE11;
    address public constant forwarder = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;
    address public constant dxnBuyAndBurn = 0x8ff4596Cdad4F8B1e1eFaC1592a5B7b586BC5eF3;
    address public devFee = makeAddr("devFee");
    address public defaultAIMiner = makeAddr("defaultAIMiner");
    address public user = makeAddr("user");

    function setUp() public {
        address[] memory aiMiner = new address[](1);
        aiMiner[0] = defaultAIMiner;

        qContract = new Q(
            forwarder,
            devFee,
            dxnBuyAndBurn,
            nxdDSV,
            aiMiner
        );

        qERC20 = qContract.qToken();

        vm.deal(user, 1_000_000 ether);
        vm.deal(defaultAIMiner, 1_000_000 ether);
    }

    function test_BasicCycleEntryFirstCycle() public {    
        vm.startPrank(user);

        uint256 multiplier = 1;
        uint256 entryProtocolFee = calculateQProtocolFee(multiplier);
        qContract.enterCycle{value: entryProtocolFee}(defaultAIMiner, multiplier);

        uint256 retainedFeeInQContract = entryProtocolFee * 70 / 100;

        assertEq(address(qContract).balance, retainedFeeInQContract);
        assertEq(qContract.cycleAccruedFees(0), retainedFeeInQContract);
        assertEq(qContract.cycleTotalEntries(0), multiplier * 100);
        assertEq(qContract.accCycleEntries(user), multiplier * 95);
        assertEq(qContract.accCycleEntries(defaultAIMiner), multiplier * 5);
        assertEq(nxdDSV.balance, entryProtocolFee * 2 / 1000);
        assertEq(devFee.balance, entryProtocolFee * 38 / 1000);
        assertEq(dxnBuyAndBurn.balance, entryProtocolFee / 100);
        assertEq(qContract.qBuyAndBurn().balance, entryProtocolFee * 25 / 100);
    }

    function test_ProtocolFeeSurplusIsReturned() public {
        vm.startPrank(user);

        uint256 entryProtocolFee = calculateQProtocolFee(1);

        uint256 userBalanceBefore = user.balance;
        qContract.enterCycle{value: entryProtocolFee + 1 ether}(defaultAIMiner, 1);
    
        uint256 userBalanceAfter = user.balance;

        assertEq(userBalanceAfter, userBalanceBefore - entryProtocolFee);
    }

    function test_RankMultiplierAffectsOnlySecondCycle() public {
        vm.prank(defaultAIMiner);
        qContract.addFundsForAIMiner{value: 0.1 ether}(defaultAIMiner);

        vm.startPrank(user);

        vm.fee(1 gwei);
        uint256 entryProtocolFee = calculateQProtocolFee(1);
        qContract.enterCycle{value: entryProtocolFee, gas: 1 gwei}(defaultAIMiner, 1);

        assertEq(qContract.cycleTotalEntries(0), 100);
        assertEq(qContract.accCycleEntries(user), 95);
        assertEq(qContract.accCycleEntries(defaultAIMiner), 5);

        skip(1 days);
       
        qContract.enterCycle{value: entryProtocolFee}(defaultAIMiner, 1);

        assertEq(qContract.cycleTotalEntries(1), 200);
        assertEq(qContract.accCycleEntries(user), 190);
        assertEq(qContract.accCycleEntries(defaultAIMiner), 10);
    }

    function test_BasicRewardClaim() public {
        vm.startPrank(user);

        vm.fee(1 gwei);
        
        uint256 entryProtocolFee = calculateQProtocolFee(1);
        qContract.enterCycle{value: entryProtocolFee, gas: 1 gwei}(defaultAIMiner, 1);

        assertEq(qContract.cycleTotalEntries(0), 100);
        assertEq(qContract.accCycleEntries(user), 95);
        assertEq(qContract.accCycleEntries(defaultAIMiner), 5);

        skip(1 days);

        uint256 rewardFirstCycle = qContract.nativeBurnedPerCycle(0) * 100;
        uint256 userMaxClaimableReward = rewardFirstCycle * 95 / 100;
        qContract.claimRewards(userMaxClaimableReward);
        assertEq(qERC20.balanceOf(user), userMaxClaimableReward);

        uint256 defaultAIMinerMaxClaimableReward = rewardFirstCycle * 5 / 100;
        vm.startPrank(defaultAIMiner);
        qContract.claimRewards(defaultAIMinerMaxClaimableReward);
        assertEq(qERC20.balanceOf(defaultAIMiner), defaultAIMinerMaxClaimableReward);
    }

    function test_CoupleParticipantsRewardClaim() public {
        for(uint256 i = 1; i < 4; i++) {
            enterCycle(
            vm.addr(i), 
            defaultAIMiner,
            1,
            9 gwei + i * 1 gwei);
        }

        vm.startPrank(user);
        vm.fee(1 gwei);

        qContract.enterCycle{value: calculateQProtocolFee(1)}(defaultAIMiner, 1);

        skip(1 days);

        uint256 rewardFirstCycle = qContract.nativeBurnedPerCycle(0) * 100;
        uint256 userMaxClaimableReward = rewardFirstCycle * 
            qContract.accCycleEntries(user) / qContract.cycleTotalEntries(0);
        qContract.claimRewards(userMaxClaimableReward);
        assertEq(qERC20.balanceOf(user), userMaxClaimableReward);
    }

    function testFuzz_ClaimRewardInBatches(uint256 batches) public {
        batches = bound(batches, 1, 2000);
        vm.startPrank(user);

        vm.fee(10 gwei);
        
        uint256 entryProtocolFee = calculateQProtocolFee(1);
        qContract.enterCycle{value: entryProtocolFee, gas: 1 gwei}(defaultAIMiner, 1);

        skip(1 days);

        uint256 rewardFirstCycle = qContract.nativeBurnedPerCycle(0) * 100;
        uint256 userMaxClaimableReward = rewardFirstCycle * 
            qContract.accCycleEntries(user) / qContract.cycleTotalEntries(0);

        uint256 claimPerBatch = userMaxClaimableReward / batches;
        for(uint256 batch = 0; batch < batches; batch++) {
            qContract.claimRewards(claimPerBatch);
        }
        assertEq(qERC20.balanceOf(user), claimPerBatch * batches);
    }

    function testFuzz_ClaimFeesInBatches(uint256 batches) public {
        batches = bound(batches, 1, 2000);
        vm.startPrank(user);

        vm.fee(10 gwei);
        
        uint256 entryProtocolFee = calculateQProtocolFee(1);
        qContract.enterCycle{value: entryProtocolFee}(defaultAIMiner, 1);

        skip(1 days);
        qContract.claimRewards(1);

        uint256 userFeeRewards = qContract.accAccruedFees(user);
        console.log("user fee rewards: ", userFeeRewards);
        uint256 claimPerBatch = userFeeRewards / batches;
        uint256 userBalanceBefore = user.balance;
        vm.fee(0);
        for(uint256 batch = 0; batch < batches; batch++) {
            qContract.claimFees(claimPerBatch);
        }
        assertEq(user.balance - userBalanceBefore, claimPerBatch * batches);
    }

    function test_basicStake() public {
        enterCycle(
            user,
            defaultAIMiner,
            1,
            10
        );

        skip(1 days);

        //vm.startPrank(user);

        uint256 rewardFirstCycle = qContract.nativeBurnedPerCycle(0) * 100;
        uint256 userMaxClaimableReward = rewardFirstCycle * 
            qContract.accCycleEntries(user) / qContract.cycleTotalEntries(0);
    
        
        address staker = makeAddr("Staker");
        qContract.claimRewards(userMaxClaimableReward);
        qERC20.transfer(staker, userMaxClaimableReward);


        enterCycle(
            user,
            defaultAIMiner,
            1,
            10
        );

        vm.deal(staker, 1 ether);
        vm.startPrank(staker);

        qERC20.approve(address(qContract), userMaxClaimableReward);
        qContract.stake(userMaxClaimableReward);
    }

    function enterCycle(
        address participant,
        address aiMiner,
        uint256 multiplier,
        uint256 baseFee
    ) internal {
        vm.startPrank(participant);
        vm.fee(baseFee);

        vm.deal(participant, 10 ether);
        qContract.enterCycle{value: calculateQProtocolFee(multiplier)}(aiMiner, multiplier);
    }

    function calculateQProtocolFee(uint256 entryMultiplier) internal view returns(uint256 protocolFee){
        uint256 cycleInteractions = qContract.cycleInteractions();

        protocolFee =(0.01 ether * entryMultiplier * (1000  + cycleInteractions)) / 1000;
    }
}