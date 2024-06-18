// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./QERC20.sol";
import "./QBuyBurn.sol";

contract Q is ERC2771Context {
    using SafeERC20 for QERC20;
    using SafeERC20 for IERC20;

    /**
     * Used to minimise division remainder when earned fees are calculated.
     */
    uint256 constant SCALING_FACTOR = 1e40;

    /**
     * Contract creation timestamp.
     * Initialized in constructor.
     */
    uint256 immutable i_initialTimestamp;

    /**
     * Length of a reward distribution cycle. 
     * Initialized in contstructor to 1 day.
     */
    uint256 immutable i_periodDuration;

    uint256 immutable totalSupply;

    uint256 immutable batchCost;

    uint256 immutable stakePercentage;

    uint256 immutable devPercentage;

    uint256 immutable buyAndBurnPercentage;

    /**
     * Helper variable to store pending stake amount.   
     */
    uint256 public pendingStake;

    /**
     * Index (0-based) of the current cycle.
     * 
     * Updated upon cycle setup that is triggered by contract interraction 
     * (account burn tokens, claims fees, claims rewards, stakes or unstakes).
     */
    uint256 public currentCycle;

    /**
     * Helper variable to store the index of the last active cycle.
     */
    uint256 public lastStartedCycle;

    /**
     * Stores the index of the penultimate active cycle plus one.
     */
    uint256 public previousStartedCycle;

    /**
     * Helper variable to store the index of the last active cycle.
     */
    uint256 public currentStartedCycle;

    /**
     * Stores the amount of stake that will be subracted from the total
     * stake once a new cycle starts.
     */
    uint256 public pendingStakeWithdrawal;

    /**
     * Diminisher of burned ether effectivness when calculating reward.
     */
    uint256 public currentBurnDecrease;

    /**
     * Total amount of ether burned through calling {enterCycle}.
     */
    uint256 public totalNativeBurned;

    /**
     * Number of times {enterCycle} has been called during current started cycle.
     */
    uint256 public cycleInteractions;

    /**
     * 3,8% of protocol fees are added to the devFee funds.
     */
    address immutable devFee;

    /**
     * 25% of protocol fees are sent to the buy and burn of Q contract.
     */
    address public immutable tokenBuyAndBurn;

    IERC20 immutable qAddress;

    /**
     * Q Reward Token contract.
     * Initialized in constructor.
     */
    QERC20 public immutable factoryToken;
    
    uint256 public minBatchNumber;
     
    uint256 public maxBatchNumber;

    /**
     * The amount of entries an account has during given cycle.
     * Resets during a new cycle when an account performs an action
     * that updates its stats.
     */
    mapping(address => uint256) public accCycleEntries;
    
    /**
     * The total amount of entries across all accounts per cycle.
     */
    mapping(uint256 => uint256) public cycleTotalEntries;

    /**
     * The last cycle in which an account has burned.
     */
    mapping(address => uint256) public lastActiveCycle;

    /**
     * Current unclaimed rewards and staked amounts per account.
     */
    mapping(address => uint256) public accRewards;

    /**
     * The fee amount the account can withdraw.
     */
    mapping(address => uint256) public accAccruedFees;

    /**
     * Total token rewards allocated per cycle.
     */
    mapping(uint256 => uint256) public rewardPerCycle;

    /**
     * Total unclaimed token reward and stake. 
     * 
     * Updated when a new cycle starts and when an account claims rewards, stakes or unstakes externally owned tokens.
     */
    mapping(uint256 => uint256) public summedCycleStakes;

    /**
     * The last cycle in which the account had its fees updated.
     */ 
    mapping(address => uint256) public lastFeeUpdateCycle;

    /**
     * The total amount of accrued fees per cycle.
     */
    mapping(uint256 => uint256) public cycleAccruedFees;

    /**
     * Sum of previous total cycle accrued fees divided by cycle stake.
     */
    mapping(uint256 => uint256) public cycleFeesPerStakeSummed;

    /**
     * Amount an account has staked and is locked during given cycle.
     */
    mapping(address => mapping(uint256 => uint256)) public accStakeCycle;

    /**
     * Stake amount an account can currently withdraw.
     */
    mapping(address => uint256) public accWithdrawableStake;

    /**
     * Cycle in which an account's stake is locked and begins generating fees.
     */
    mapping(address => uint256) public accFirstStake;

    /**
     * Same as accFirstStake, but stores the second stake seperately 
     * in case the account stakes in two consecutive active cycles.
     */
    mapping(address => uint256) public accSecondStake;

    /**
     * Total amount of burned ether spent on {enterCycle} transactions.
     */
    mapping(uint256 => uint256) public nativeBurnedPerCycle;

    /**
     * @dev Emitted when `account` claims an amount of `fees` in native token
     * through {claimFees} in `cycle`.
     */
    event FeesClaimed(
        uint256 indexed cycle,
        address indexed account,
        uint256 fees
    );

    /**
     * @dev Emitted when `account` stakes `amount` Q tokens through
     * {stake} in `cycle`.
     */
    event Staked(
        uint256 indexed cycle,
        address indexed account,
        uint256 amount
    );

    /**
     * @dev Emitted when `account` unstakes `amount` Q tokens through
     * {unstake} in `cycle`.
     */
    event Unstaked(
        uint256 indexed cycle,
        address indexed account,
        uint256 amount
    );

    /**
     * @dev Emitted when `account` claims `amount` Q 
     * token rewards through {claimRewards} in `cycle`.
     */
    event RewardsClaimed(
        uint256 indexed cycle,
        address indexed account,
        uint256 reward
    );

    /**
     * @dev Emitted when calling {enterCycle} marking the new current `cycle`,
     * `calculatedCycleReward` and `summedCycleStakes`.
     */
    event NewCycleStarted(
        uint256 indexed cycle,
        uint256 summedCycleStakes
    );

    /**
     * @dev Emitted when calling {enterCycle} 
     */
    event CycleEntry(
        address indexed userAddress,
        uint256 entryMultiplier
    );

    /**
     * Minimal reentrancy lock using transient storage.
     */
    modifier nonReentrant {
        assembly {
            if tload(0) { revert(0, 0) }
            tstore(0, 1)
        }
        _;
        // Unlocks the guard, making the pattern composable.
        // After the function exits, it can be called again, even in the same transaction.
        assembly {
            tstore(0, 0)
        }
    }

    /**
     * @dev Checks that the caller has sent an amount that is equal or greater 
     * than the sum of the protocol fee 
     * The change is sent back to the caller.
     * 
     */
    modifier gasWrapper() {
        uint256 startGas = gasleft();
        _;
        uint256 gasConsumed = startGas - gasleft() + 30892;
        uint256 burnedAmount = gasConsumed * block.basefee;

        nativeBurnedPerCycle[currentCycle] += burnedAmount;
        totalNativeBurned += burnedAmount;
    }

    /**
     * @param forwarder forwarder contract address.
     */
    constructor(
        address forwarder,
        address _devFee,
        address _qAddress,
        string memory tokenSymbol,
        string memory tokenName,
        uint256 _totalSupply,
        uint256 _i_periodDuration,
        uint256 _minBatchNumber,
        uint256 _maxBatchNumber,
        uint256 _batchCost,
        uint256 _stakePercentage,
        uint256 _devPercentage,
        uint256 _buyAndBurnPercentage
    ) ERC2771Context(forwarder) payable {
        require(minBatchNumber > 0, "Min batch must be greater than 0!");
        require(_stakePercentage + _devPercentage + _buyAndBurnPercentage == 1000, 
            "Wrong total percentage");
        devFee = _devFee;
        qAddress = IERC20(_qAddress);

        factoryToken = new QERC20(tokenName, tokenSymbol, _totalSupply);
        tokenBuyAndBurn = address(new QBuyBurn(address(factoryToken),_i_periodDuration));
        
        i_initialTimestamp = block.timestamp;
        i_periodDuration = _i_periodDuration;

        minBatchNumber = _minBatchNumber;
        maxBatchNumber = _maxBatchNumber;

        totalSupply = _totalSupply;

        batchCost = _batchCost;

        stakePercentage = _stakePercentage;
        devPercentage = _devPercentage;
        buyAndBurnPercentage = _buyAndBurnPercentage;
    }

    /**
     * Entry point for the Q daily auction.
     * @param entryMultiplier multiplies the number of entries
     */
    function enterCycle(
        uint256 entryMultiplier
    )
        external
        payable
        nonReentrant()
        gasWrapper()
    {
        require(totalNativeBurned <= totalSupply, "Endgame reached");
        require(entryMultiplier <= maxBatchNumber, "Greater than the maximum number of batches");
        require(entryMultiplier > minBatchNumber, "Less than the minimum number of batches");

        calculateCycle();
        uint256 currentCycleMem = currentCycle;

        endCycle(currentCycleMem);
        setUpNewCycle(currentCycleMem);

        uint256 protocolFee = calculateProtocolFee(entryMultiplier);

        address user = _msgSender();
        updateStats(user, currentCycleMem);

        cycleTotalEntries[currentCycleMem] += entryMultiplier;
        accCycleEntries[user] += entryMultiplier;

        lastActiveCycle[user] = currentCycle;

        cycleInteractions++;

        distributeFees(protocolFee, currentCycleMem);

        qAddress.safeTransferFrom(user, address(this), protocolFee);
        emit CycleEntry(user, entryMultiplier);
    }

    /**
     * @dev Mints newly accrued account rewards and transfers the entire 
     * allocated amount to the transaction sender address.
     */
    function claimRewards(uint256 claimAmount)
        external
        nonReentrant()
    {
        calculateCycle();
        uint256 currentCycleMem = currentCycle;

        endCycle(currentCycleMem);

        address user = _msgSender();
        updateStats(user, currentCycleMem);

        uint256 reward = accRewards[user] - accWithdrawableStake[user];
        require(reward > 0, "No rewards");
        require(claimAmount <= reward, "Exceeds rewards");

        accRewards[user] -= claimAmount;
        if (lastStartedCycle == currentStartedCycle) {
            pendingStakeWithdrawal += claimAmount;
        } else {
            summedCycleStakes[currentCycleMem] = summedCycleStakes[currentCycleMem] - claimAmount;
        }

        factoryToken.mintReward(user, claimAmount);
        emit RewardsClaimed(currentCycleMem, user, claimAmount);
    }

    /**
     * @dev Transfers newly accrued fees to sender's address.
     */
    function claimFees(uint256 claimAmount)
        external
        nonReentrant()
    {
        calculateCycle();
        uint256 currentCycleMem = currentCycle;
        address user = _msgSender();

        endCycle(currentCycleMem);
        updateStats(user, currentCycleMem);

        uint256 fees = accAccruedFees[user];
        require(fees > 0, "Amount is zero");
        require(claimAmount <= fees, "Claim amount exceeds fees");

        accAccruedFees[user] -= claimAmount;

        qAddress.safeTransfer(user, claimAmount);
        
        emit FeesClaimed(currentCycleMem, user, claimAmount);
    }

    /**
     * @dev Stakes the given amount and increases the share of the daily allocated fees.
     * The tokens are transfered from sender account to this contract.
     * To receive the tokens back, the unstake function must be called by the same account address.
     * 
     * @param amount token amount to be staked (in wei).
     */
    function stake(uint256 amount)
        external
        nonReentrant()
    {
        calculateCycle();
        uint256 currentCycleMem = currentCycle;
        address user = _msgSender();

        endCycle(currentCycleMem);
        updateStats(user, currentCycleMem);

        require(amount > 0, "Amount is zero");
        require(currentCycleMem == currentStartedCycle, "Only stake during active cycle");

        pendingStake += amount;

        uint256 cycleToSet = currentCycleMem + 1;
        if (lastStartedCycle == currentStartedCycle) {
            cycleToSet = lastStartedCycle + 1;
        }

        if (
            (cycleToSet != accFirstStake[user] &&
                cycleToSet != accSecondStake[user])
        ) {
            if (accFirstStake[user] == 0) {
                accFirstStake[user] = cycleToSet;
            } else if (accSecondStake[user] == 0) {
                accSecondStake[user] = cycleToSet;
            }
        }

        accStakeCycle[user][cycleToSet] += amount;

        factoryToken.safeTransferFrom(user, address(this), amount);
        emit Staked(cycleToSet, user, amount);
    }

    /**
     * @dev Unstakes the given amount and decreases the share of the daily allocated fees.
     * If the balance is availabe, the tokens are transfered from this contract to the sender account.
     * 
     * @param amount token amount to be unstaked (in wei).
     */
    function unstake(uint256 amount)
        external
        nonReentrant()
    {
        calculateCycle();
        uint256 currentCycleMem = currentCycle;
        address user = _msgSender();

        endCycle(currentCycleMem);
        updateStats(user, currentCycleMem);
        
        require(amount > 0, "Q: Amount is zero");
        require(
            amount <= accWithdrawableStake[user],
            "Q: Amount greater than withdrawable stake"
        );

        if (lastStartedCycle == currentStartedCycle) {
            pendingStakeWithdrawal += amount;
        } else {
            summedCycleStakes[currentCycleMem] -= amount;
        }

        accWithdrawableStake[user] -= amount;
        accRewards[user] -= amount;

        factoryToken.safeTransfer(user, amount);
        emit Unstaked(currentCycleMem, user, amount);
    }

    /**
     * @dev Returns the index of the cycle at the current block time.
     */
    function getCurrentCycle() public view returns (uint256) {
        return (block.timestamp - i_initialTimestamp) / i_periodDuration;
    }

    /**
     * Calculates the protocol fee for entering the current cycle.
     */
    function calculateProtocolFee(uint256 entryMultiplier) internal view returns(uint256 protocolFee) {
        protocolFee = (batchCost * entryMultiplier * (1000  + cycleInteractions)) / 1000;
    }

    /**
     * Based on the protocol fee, the corresponding allocations are
     * sent to each of the predefined addresses.
     */
    function distributeFees(uint256 fees, uint256 cycle) internal {
        cycleAccruedFees[cycle] += fees * stakePercentage / 1000;


        qAddress.safeTransfer(devFee, fees * devPercentage / 1000);
        qAddress.safeTransfer(tokenBuyAndBurn, fees * buyAndBurnPercentage / 1000);
    }

    /**
     * @dev Updates the index of the cycle.
     */
    function calculateCycle() internal {
        uint256 calculatedCycle = getCurrentCycle();
        
        if (calculatedCycle > currentCycle) {
            currentCycle = calculatedCycle;
        }
        
    }

    /**
     * @dev Updates the global helper variables related to fee distribution.
     */
    function endCycle(uint256 cycle) internal {
        if (cycle != currentStartedCycle) {
            previousStartedCycle = lastStartedCycle;
            lastStartedCycle = currentStartedCycle;
        }

        uint256 lastStartedCycleMem = lastStartedCycle;

        if (
            cycle > lastStartedCycleMem &&
            cycleFeesPerStakeSummed[lastStartedCycleMem + 1] == 0
        ) {
            calculateCycleReward(lastStartedCycleMem);
            
            uint256 feePerStake = (cycleAccruedFees[lastStartedCycleMem] * SCALING_FACTOR) / 
                summedCycleStakes[lastStartedCycleMem];
            
            cycleFeesPerStakeSummed[lastStartedCycleMem + 1] = cycleFeesPerStakeSummed[previousStartedCycle + 1] + feePerStake;
        }
    }

    /**
     * Calculates the Q reward amount to be distributed to
     * the entrants of the specified cycle. 
     */
    function calculateCycleReward(uint256 cycle) internal {  
        uint256 reward = nativeBurnedPerCycle[cycle] * 100 - 
            nativeBurnedPerCycle[cycle] * currentBurnDecrease / 200;

        rewardPerCycle[cycle] = reward;
        summedCycleStakes[cycle] += reward;
            
        if(currentBurnDecrease < 19999) {
            currentBurnDecrease++;
        }
    }

    /**
     * @dev Updates the global state related to starting a new cycle along 
     * with helper state variables used in computation of staking rewards.
     */
    function setUpNewCycle(uint256 cycle) internal {
        if (cycle != currentStartedCycle) {
            currentStartedCycle = cycle;

            cycleInteractions = 0;

            summedCycleStakes[cycle] += summedCycleStakes[lastStartedCycle];
            
            if (pendingStake != 0) {
                summedCycleStakes[cycle] += pendingStake;
                pendingStake = 0;
            }
            
            if (pendingStakeWithdrawal != 0) {
                summedCycleStakes[cycle] -= pendingStakeWithdrawal;
                pendingStakeWithdrawal = 0;
            }
            
            emit NewCycleStarted(
                cycle,
                summedCycleStakes[cycle]
            );
        }
    }

    /**
     * @dev Updates various helper state variables used to compute token rewards 
     * and fees distribution for a given account.
     * 
     * @param account the address of the account to make the updates for.
     */
    function updateStats(address account, uint256 cycle) internal {
         if (	
            cycle > lastActiveCycle[account] &&	
            accCycleEntries[account] != 0	
        ) {	
            uint256 lastCycleAccReward = ((accCycleEntries[account] * rewardPerCycle[lastActiveCycle[account]]) / 	
                cycleTotalEntries[lastActiveCycle[account]]);
            accRewards[account] += lastCycleAccReward;	
            accCycleEntries[account] = 0;
        }

        uint256 lastStartedCyclePlusOne = lastStartedCycle + 1;
        if (
            cycle > lastStartedCycle &&
            lastFeeUpdateCycle[account] != lastStartedCyclePlusOne
        ) {
            accAccruedFees[account] =
                accAccruedFees[account] +
                (
                    (accRewards[account] * 
                        (cycleFeesPerStakeSummed[lastStartedCyclePlusOne] - 
                            cycleFeesPerStakeSummed[lastFeeUpdateCycle[account]]
                        )
                    )
                ) /
                SCALING_FACTOR;
            lastFeeUpdateCycle[account] = lastStartedCyclePlusOne;
        }

        if (
            accFirstStake[account] != 0 &&
            cycle > accFirstStake[account]
        ) {
            uint256 unlockedFirstStake = accStakeCycle[account][accFirstStake[account]];

            accRewards[account] += unlockedFirstStake;
            accWithdrawableStake[account] += unlockedFirstStake;
            if (lastStartedCyclePlusOne > accFirstStake[account]) {
                accAccruedFees[account] = accAccruedFees[account] + 
                (
                    (accStakeCycle[account][accFirstStake[account]] * 
                        (cycleFeesPerStakeSummed[lastStartedCyclePlusOne] - 
                            cycleFeesPerStakeSummed[accFirstStake[account]]
                        )
                    )
                ) / 
                SCALING_FACTOR;
            }

            accStakeCycle[account][accFirstStake[account]] = 0;
            accFirstStake[account] = 0;

            if (accSecondStake[account] != 0) {
                if (cycle > accSecondStake[account]) {
                    uint256 unlockedSecondStake = accStakeCycle[account][accSecondStake[account]];
                    accRewards[account] += unlockedSecondStake;
                    accWithdrawableStake[account] += unlockedSecondStake;
                    
                    if (lastStartedCyclePlusOne > accSecondStake[account]) {
                        accAccruedFees[account] = accAccruedFees[account] + 
                        (
                            (accStakeCycle[account][accSecondStake[account]] * 
                                (cycleFeesPerStakeSummed[lastStartedCyclePlusOne] - 
                                    cycleFeesPerStakeSummed[accSecondStake[account]]
                                )
                            )
                        ) / 
                        SCALING_FACTOR;
                    }

                    accStakeCycle[account][accSecondStake[account]] = 0;
                    accSecondStake[account] = 0;
                } else {
                    accFirstStake[account] = accSecondStake[account];
                    accSecondStake[account] = 0;
                }
            }
        }
    }
}