// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import "./interfaces/IWETH9Minimal.sol";
import "./interfaces/ISwapRouterMinimal.sol";

contract QBuyBurn {
    using SafeERC20 for IERC20;

    uint256 public i_initialTimestamp;

    uint256 public i_periodDuration;

    uint256 public firstCycleReceivedEther;

    uint256 public globalCountForDays;

    uint256 public collectedAmount;

    address public immutable NEWTOKEN; 
    
    address public immutable Q_NewToken_Pool;

    address public immutable NEW_TOKEN_FACTORY;    

    address public constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    address public constant Q_ADDRESS = 0xACA40632C51C2a03209D2714b88Aa0f1456A2101; 

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    address public constant SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    mapping(uint256 => bool) public feeAlreadyDistributed;

    uint24 public constant poolFee = 10000;

    function onQERC20Received(uint256 amount) external {
        if(msg.sender == NEW_TOKEN_FACTORY) {
           if(block.timestamp < i_initialTimestamp + i_periodDuration) {
                firstCycleReceivedEther += amount;
           } else {
                collectedAmount += amount;
           }
        }
    }

    constructor(address _newTokenAddress, uint256 _i_periodDuration) {
        i_periodDuration = _i_periodDuration;
        i_initialTimestamp = block.timestamp;
        Q_NewToken_Pool = computePoolAddress(Q_ADDRESS, _newTokenAddress, poolFee);
        NEWTOKEN = _newTokenAddress;
        NEW_TOKEN_FACTORY = msg.sender;
    }

    function burnToken(uint256 amountToBurn, uint256 deadline) public {
        require(msg.sender == tx.origin, "Use EOA!");
        require(isContract(Q_NewToken_Pool), "Pool does not exist!");
        require(block.timestamp > i_initialTimestamp + i_periodDuration, "Early burn!");
        require(amountToBurn >= 0.1 ether, "Min 0.1 ETH");

        uint256 theFiftiethPart = (firstCycleReceivedEther / 50);
        uint256 amountToCompare = collectedAmount;
        uint256 currentCycle = getCurrentCycle();

        uint256 amountETH;
        uint256 callerPercent;

        if(globalCountForDays < 50 && !feeAlreadyDistributed[currentCycle]) {
            amountToCompare = collectedAmount + theFiftiethPart;
            require(amountToCompare >= amountToBurn, "Insufficient funds!");
            
            if(collectedAmount >= amountToBurn) {
                collectedAmount -= amountToBurn;
                amountToBurn += theFiftiethPart;
            } else {
                if(amountToBurn > theFiftiethPart) {
                    if(collectedAmount >= amountToBurn - theFiftiethPart) {
                        collectedAmount -= amountToBurn - theFiftiethPart;
                    }
                } else {
                amountToBurn = theFiftiethPart;
                }
            }
            globalCountForDays ++;
            feeAlreadyDistributed[currentCycle] = true;
        } else {
            require(amountToCompare >= amountToBurn, "Insufficient funds!");
            collectedAmount -= amountToBurn;
        }
        callerPercent = amountToBurn / 100;
        amountETH = amountToBurn - callerPercent;

        uint256 amountOutExpected = _getQuote(uint128(amountETH));
        uint256 minTokenAmount = (amountOutExpected * 90) / 100;
        require(minTokenAmount > 0, "Min > 0");

        _swap(minTokenAmount, amountETH, deadline);

        IERC20(Q_ADDRESS).safeTransfer(msg.sender, callerPercent);
    }

    function _swap(uint256 amountOutMinimum, uint256 amountIn, uint256 deadline) private {
        ISwapRouterMinimal.ExactInputSingleParams memory params =
            ISwapRouterMinimal.ExactInputSingleParams({
                tokenIn: Q_ADDRESS,
                tokenOut: NEWTOKEN,
                fee: poolFee,
                recipient: BURN_ADDRESS,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            });

        ISwapRouterMinimal(SWAP_ROUTER).exactInputSingle{value: amountIn}(params);
    }

    function _getQuote(uint128 amountIn) public view returns(uint256 amountOut) {
        (int24 tick, ) = OracleLibrary.consult(Q_NewToken_Pool, 1);
        amountOut = OracleLibrary.getQuoteAtTick(tick, amountIn, Q_ADDRESS, NEWTOKEN);
    }

    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function computePoolAddress(address tokenA, address tokenB, uint24 fee) public pure returns (address pool) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        PoolAddress.PoolKey memory key = PoolAddress.PoolKey({token0: token0, token1: token1, fee: fee});
        pool = PoolAddress.computeAddress(UNISWAP_V3_FACTORY, key);
        return pool;
    }   

    function getCurrentCycle() public view returns (uint256) {
        return (block.timestamp - i_initialTimestamp) / i_periodDuration;
    }
}