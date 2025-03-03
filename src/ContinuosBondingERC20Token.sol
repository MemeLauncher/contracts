// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IBondingCurve } from "./interfaces/IBondingCurve.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { IUniswapV3Factory } from "./interfaces/IUniswapV3Factory.sol";
import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";
import { INonfungiblePositionManager } from "./interfaces/INonfungiblePositionManager.sol";
import { TickMath } from "./libraries/TickMath.sol";
import { IContinuousBondingERC20Token } from "./interfaces/IContinuousBondingERC20Token.sol";
import { IBondingERC20TokenFactory } from "./interfaces/IBondingERC20TokenFactory.sol";
import { FixedPoint96 } from "./libraries/FixedPoint96.sol";

event TokensBought(address indexed buyer, uint256 ethAmount, uint256 tokenBought, uint256 feeEarnedByTreasury);

event TokensSold(address indexed seller, uint256 tokenAmount, uint256 ethAmount, uint256 feeEarnedByTreasury);

event TreasuryClaimed(address indexed to, uint256 amount);

event PairCreated(uint256 ethAmount, uint256 tokenAmount, uint256 liquidity, address lpToken);

error NeedToSendETH();
error NeedToSellTokens();
error ContractNotEnoughETH();
error FailedToSendETH();
error InsufficientETH();
error InvalidSender();
error LPCanNotBeCreated();
error LiquidityGoalReached();
error InSufficientAmountReceived();
error DivisionByZero();
error TransferToUniswapV3PoolsAreNotAllowed();
error AntiWhaleFeatureEnabled();

contract ContinuosBondingERC20Token is IContinuousBondingERC20Token, ERC20, ReentrancyGuard {
    uint256 public constant PERCENTAGE_DENOMINATOR = 10_000; // 100%
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant MAX_TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    AntiWhale private _antiWhale;

    IBondingCurve public immutable bondingCurve;
    address public immutable TREASURY_ADDRESS;
    address public immutable factory;

    uint256 public initialTokenBalance;
    uint256 public ethBalance;
    uint256 public availableTokenBalance;
    uint256 public buyFee;
    uint256 public sellFee;
    uint256 public treasuryClaimableEth;
    bool public isLpCreated;
    uint256 public creationTime;

    IUniswapV3Factory public immutable uniswapV3Factory;
    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    address public immutable WETH;

    constructor(
        address _factory,
        string memory _name,
        string memory _symbol,
        address _treasury,
        uint256 _buyFee,
        uint256 _sellFee,
        IBondingCurve _bondingCurve,
        uint256 _initialTokenBalance,
        uint256 _availableTokenBalance,
        address _uniswapV3Factory,
        address _nonfungiblePositionManager,
        address _WETH,
        AntiWhale memory _antiWhaleProps
    )
        ERC20(_name, _symbol)
    {
        factory = _factory;
        TREASURY_ADDRESS = _treasury;
        buyFee = _buyFee;
        sellFee = _sellFee;
        bondingCurve = _bondingCurve;
        _mint(address(this), MAX_TOTAL_SUPPLY);
        initialTokenBalance = _initialTokenBalance;
        ethBalance = _initialTokenBalance;
        availableTokenBalance = _availableTokenBalance;
        uniswapV3Factory = IUniswapV3Factory(_uniswapV3Factory);
        nonfungiblePositionManager = INonfungiblePositionManager(_nonfungiblePositionManager);
        WETH = _WETH;
        creationTime = block.timestamp;
        _antiWhale = _antiWhaleProps;
    }

    function buyTokens(uint256 minExpectedAmount, address recipient) external payable nonReentrant returns (uint256) {
        if (liquidityGoalReached() || isLpCreated) revert LiquidityGoalReached();
        if (msg.value == 0) revert NeedToSendETH();

        uint256 ethAmount = msg.value;
        uint256 feeAmount = (ethAmount * buyFee) / PERCENTAGE_DENOMINATOR;
        uint256 remainingAmount = ethAmount - feeAmount;

        uint256 tokenReserveBalance = getReserve();
        uint256 maxTokenToReceive = tokenReserveBalance - (MAX_TOTAL_SUPPLY - availableTokenBalance);

        uint256 tokensToReceive =
            bondingCurve.calculatePurchaseReturn(remainingAmount, ethBalance, tokenReserveBalance, bytes(""));
        uint256 ethReceivedAmount = remainingAmount;
        uint256 refund;
        if (tokensToReceive > maxTokenToReceive) {
            tokensToReceive = maxTokenToReceive;
            ethReceivedAmount = bondingCurve.getOutputPrice(tokensToReceive, ethBalance, tokenReserveBalance);
            feeAmount =
                (ethReceivedAmount * PERCENTAGE_DENOMINATOR) / (PERCENTAGE_DENOMINATOR - buyFee) - ethReceivedAmount;
            if (msg.value < (feeAmount + ethReceivedAmount)) {
                revert InsufficientETH();
            }
            refund = msg.value - (feeAmount + ethReceivedAmount);
        }
        ethBalance += ethReceivedAmount;
        treasuryClaimableEth += feeAmount;
        if (tokensToReceive < minExpectedAmount) revert InSufficientAmountReceived();

        _transfer(address(this), recipient, tokensToReceive);
        if (
            balanceOf(recipient) > ((_antiWhale.pctSupply * MAX_TOTAL_SUPPLY) / 100) && _antiWhale.isEnabled
                && (_antiWhale.timePeriod == 0 || block.timestamp - creationTime < _antiWhale.timePeriod)
        ) {
            revert AntiWhaleFeatureEnabled();
        }

        if (liquidityGoalReached()) {
            _createPair();
        }

        (bool sent,) = recipient.call{ value: refund }("");
        if (!sent) {
            revert FailedToSendETH();
        }

        if (treasuryClaimableEth >= 0.1 ether) {
            (bool treasurySent,) = TREASURY_ADDRESS.call{ value: treasuryClaimableEth }("");
            treasuryClaimableEth = 0;
            if (!treasurySent) {
                revert FailedToSendETH();
            }
        }

        emit TokensBought(recipient, ethReceivedAmount, tokensToReceive, feeAmount);

        return tokensToReceive;
    }

    function sellTokens(uint256 tokenAmount, uint256 minExpectedEth) external nonReentrant {
        if (liquidityGoalReached() || isLpCreated) revert LiquidityGoalReached();
        if (tokenAmount == 0) revert NeedToSellTokens();

        uint256 tokenReserveBalance = getReserve();
        uint256 reimburseAmount =
            bondingCurve.calculateSaleReturn(tokenAmount, tokenReserveBalance, ethBalance, bytes(""));

        uint256 feeAmount = (reimburseAmount * sellFee) / PERCENTAGE_DENOMINATOR;
        ethBalance -= reimburseAmount;
        reimburseAmount -= feeAmount;
        treasuryClaimableEth += feeAmount;

        if (reimburseAmount < minExpectedEth) revert InSufficientAmountReceived();
        if (address(this).balance < reimburseAmount + treasuryClaimableEth) revert ContractNotEnoughETH();

        _transfer(msg.sender, address(this), tokenAmount);
        (bool sent,) = msg.sender.call{ value: reimburseAmount }("");
        if (!sent) revert FailedToSendETH();

        if (treasuryClaimableEth >= 0.1 ether) {
            (bool treasurySent,) = TREASURY_ADDRESS.call{ value: treasuryClaimableEth }("");
            treasuryClaimableEth = 0;
            if (!treasurySent) {
                revert FailedToSendETH();
            }
        }

        emit TokensSold(msg.sender, tokenAmount, reimburseAmount, feeAmount);
    }

    function getReserve() public view returns (uint256) {
        return balanceOf(address(this));
    }

    function liquidityGoalReached() public view returns (bool) {
        return getReserve() <= (MAX_TOTAL_SUPPLY - availableTokenBalance);
    }

    function totalEthContributed() public view returns (uint256) {
        return ethBalance - initialTokenBalance;
    }

    function calculateTokenAmount(uint256 ethAmount) public view returns (uint256) {
        uint256 tokenReserveBalance = getReserve();
        return bondingCurve.calculatePurchaseReturn(ethAmount, ethBalance, tokenReserveBalance, bytes(""));
    }

    function calculateETHAmount(uint256 tokenAmount) public view returns (uint256) {
        uint256 tokenReserveBalance = getReserve();

        return bondingCurve.calculateSaleReturn(tokenAmount, tokenReserveBalance, ethBalance, bytes(""));
    }

    function antiWhale() public view returns (AntiWhale memory) {
        return _antiWhale;
    }

    function isAntiWhaleFlagEnabled() public view returns (bool) {
        return _antiWhale.isEnabled;
    }

    function claimTreasuryBalance(address to, uint256 amount) public {
        if (msg.sender != TREASURY_ADDRESS) {
            revert InvalidSender();
        }
        // this will revert if amount requested is more than claimable
        treasuryClaimableEth -= amount;
        (bool sent,) = to.call{ value: amount }("");
        if (!sent) revert FailedToSendETH();

        emit TreasuryClaimed(to, amount);
    }

    function _createPair() internal {
        uint256 currentTokenBalance = getReserve();
        uint256 currentEth = ethBalance - initialTokenBalance;
        currentEth = currentEth > address(this).balance ? address(this).balance : currentEth;
        isLpCreated = true;

        // Create the pool if it doesn't exist
        (address token0, address token1) = address(this) < WETH ? (address(this), WETH) : (WETH, address(this));
        (uint256 amountOfToken0, uint256 amountOfToken1) =
            (token0 == address(this)) ? (currentTokenBalance, currentEth) : (currentEth, currentTokenBalance);
        address pool = nonfungiblePositionManager.createAndInitializePoolIfNecessary(
            token0, token1, 3000, _getSqrtPriceX96(amountOfToken0, amountOfToken1)
        );
        int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();

        // Approve the position manager to spend tokens
        _approve(address(this), address(nonfungiblePositionManager), currentTokenBalance);
        IWETH(WETH).deposit{ value: currentEth }();
        IWETH(WETH).approve(address(nonfungiblePositionManager), currentEth);

        address feeRecipient = IBondingERC20TokenFactory(factory).feeRecipient();

        int24 tickLower = -887_272;
        int24 tickUpper = -tickLower;

        tickLower = -(-tickLower / tickSpacing * tickSpacing);
        tickUpper = tickUpper / tickSpacing * tickSpacing;

        // Add liquidity
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: 3000,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amountOfToken0,
            amount1Desired: amountOfToken1,
            amount0Min: 0,
            amount1Min: 0,
            recipient: feeRecipient != address(0) ? feeRecipient : address(this),
            deadline: block.timestamp
        });

        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) = nonfungiblePositionManager.mint(params);

        emit PairCreated(amount1, amount0, liquidity, pool);
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        if (
            !liquidityGoalReached() && from != address(0) && to != address(0) && from != address(this)
                && to != address(this) && !isLpCreated
        ) {
            (address token0, address token1) = address(this) < WETH ? (address(this), WETH) : (WETH, address(this));
            address pool = IUniswapV3Factory(uniswapV3Factory).getPool(token0, token1, 3000);

            if (to == address(uniswapV3Factory) || to == address(nonfungiblePositionManager) || to == pool) {
                revert TransferToUniswapV3PoolsAreNotAllowed();
            }
        }
        super._update(from, to, value);
    }

    function _getSqrtPriceX96(uint256 amountOfToken0, uint256 amountOfToken1) internal pure returns (uint160) {
        if (amountOfToken0 == 0) revert DivisionByZero();
        uint256 price = (amountOfToken1 * (2 ** 96) / amountOfToken0) * (2 ** 96);
        uint256 sqrtPrice = _sqrt(price);
        return uint160(sqrtPrice);
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
