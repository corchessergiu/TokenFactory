// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import "./interfaces/IWETH9Minimal.sol";
import "./interfaces/ISwapRouterMinimal.sol";

contract QBuyBurn {

    uint256 public i_initialTimestamp;

    uint256 public constant i_periodDuration = 1 days;

    uint256 public firstCycleReceivedEther;

    uint256 public globalCountForDays;

    uint256 public collectedAmount;

    address public immutable Q; 
    
    address public immutable Q_WETH9_Pool;    

    address public constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; 

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    address public constant SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    mapping(uint256 => bool) public feeAlreadyDistributed;

    uint24 public constant poolFee = 10000;

    receive() external payable {
        if(block.timestamp < i_initialTimestamp + 1 days) {
            firstCycleReceivedEther += msg.value;
         } else {
            collectedAmount += msg.value;
         }
    }

    constructor(address _qAddress) {
        i_initialTimestamp = block.timestamp;
        Q_WETH9_Pool = computePoolAddress(WETH9, _qAddress, poolFee);
        Q = _qAddress;
    }

    function burnToken(uint256 amountToBurn, uint256 deadline) public {
        require(msg.sender == tx.origin, "Use EOA!");
        require(isContract(Q_WETH9_Pool), "Pool does not exist!");
        require(block.timestamp > i_initialTimestamp + 1 days, "Early burn!");
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

        (bool success,) = payable(msg.sender).call{value: callerPercent}("");
        require(success, "Transfer failed.");
    }

    function _swap(uint256 amountOutMinimum, uint256 amountIn, uint256 deadline) private {
        ISwapRouterMinimal.ExactInputSingleParams memory params =
            ISwapRouterMinimal.ExactInputSingleParams({
                tokenIn: WETH9,
                tokenOut: Q,
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
        (int24 tick, ) = OracleLibrary.consult(Q_WETH9_Pool, 1);
        amountOut = OracleLibrary.getQuoteAtTick(tick, amountIn, WETH9, Q);
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