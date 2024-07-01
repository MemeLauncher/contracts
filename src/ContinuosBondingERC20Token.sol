// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IJoeRouter02 } from "./interfaces/IJoeRouter02.sol";
import { IUniswapV2Router02 } from "./interfaces/IUniswapV2Router02.sol";
import { IFactory } from "./interfaces/IFactory.sol";
import { IBondingCurve } from "./interfaces/IBondingCurve.sol";
import { LP_POOL } from "./BondingERC20TokenFactory.sol";

event TokensBought(address indexed buyer, uint256 ethAmount, uint256 tokenBought, uint256 feeEarnedByTreasury);

event TokensSold(address indexed seller, uint256 tokenAmount, uint256 ethAmount, uint256 feeEarnedByTreasury);

event TreasuryClaimed(address indexed to, uint256 amount);

event PairCreated(uint256 ethAmount, uint256 tokenAmount, uint256 liquidity, address lpToken);

error NeedToSendETH();
error NeedToSellTokens();
error ContractNotEnoughETH();
error FailedToSendETH();
error InsufficientETH();
error TransferNotAllowedUntilLiquidityGoalReached();
error InvalidSender();
error LPCanNotBeCreated();
error LiquidityGoalReached();
error InSufficientAmountReceived();

contract ContinuosBondingERC20Token is ERC20, ReentrancyGuard {
    uint256 public constant PERCENTAGE_DENOMINATOR = 10_000; // 100%
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant MAX_TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    IBondingCurve public immutable bondingCurve;
    address public immutable router;
    IFactory public immutable factory;
    address public immutable TREASURY_ADDRESS;

    uint256 public initialTokenBalance;
    uint256 public ethBalance;
    uint256 public availableTokenBalance;
    uint256 public buyFee;
    uint256 public sellFee;
    uint256 public treasuryClaimableEth;
    bool public isLpCreated;
    LP_POOL public poolType;

    constructor(
        address _router,
        string memory _name,
        string memory _symbol,
        address _treasury,
        uint256 _buyFee,
        uint256 _sellFee,
        IBondingCurve _bondingCurve,
        uint256 _initialTokenBalance,
        uint256 _availableTokenBalance,
        LP_POOL _poolType
    )
        ERC20(_name, _symbol)
    {
        router = _router;
        factory = IFactory(IJoeRouter02(router).factory());
        TREASURY_ADDRESS = _treasury;
        buyFee = _buyFee;
        sellFee = _sellFee;
        bondingCurve = _bondingCurve;
        _mint(address(this), MAX_TOTAL_SUPPLY);
        initialTokenBalance = _initialTokenBalance;
        ethBalance = _initialTokenBalance;
        availableTokenBalance = _availableTokenBalance;
        poolType = _poolType;
    }

    function buyTokens(uint256 minExpectedAmount) external payable nonReentrant returns (uint256) {
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
            feeAmount = (ethReceivedAmount * buyFee) / PERCENTAGE_DENOMINATOR;
            if (msg.value < (feeAmount + ethReceivedAmount)) {
                revert InsufficientETH();
            }
            refund = msg.value - (feeAmount + ethReceivedAmount);
        }
        ethBalance += ethReceivedAmount;
        treasuryClaimableEth += feeAmount;
        if (tokensToReceive < minExpectedAmount) revert InSufficientAmountReceived();

        _transfer(address(this), msg.sender, tokensToReceive);

        if (liquidityGoalReached()) {
            _createPair();
        }

        (bool sent,) = msg.sender.call{ value: refund }("");
        if (!sent) {
            revert FailedToSendETH();
        }

        if (treasuryClaimableEth >= 0.1 ether) {
            (bool sent,) = TREASURY_ADDRESS.call{ value: treasuryClaimableEth }("");
            treasuryClaimableEth = 0;
            if (!sent) {
                revert FailedToSendETH();
            }
        }

        emit TokensBought(msg.sender, ethReceivedAmount, tokensToReceive, feeAmount);

        return tokensToReceive;
    }

    function sellTokens(uint256 tokenAmount, uint256 minExpectedEth) external nonReentrant returns (uint256) {
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
        if (address(this).balance < reimburseAmount) revert ContractNotEnoughETH();

        _transfer(msg.sender, address(this), tokenAmount);
        (bool sent,) = msg.sender.call{ value: reimburseAmount }("");
        if (!sent) revert FailedToSendETH();

        if (treasuryClaimableEth >= 0.1 ether) {
            (bool sent,) = TREASURY_ADDRESS.call{ value: treasuryClaimableEth }("");
            treasuryClaimableEth = 0;
            if (!sent) {
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
        isLpCreated = true;

        _approve(address(this), address(router), currentTokenBalance);

        address wNative;
        uint256 liquidity;
        if (poolType == LP_POOL.Uniswap) {
            wNative = IUniswapV2Router02(router).WETH();
            (,, liquidity) = IUniswapV2Router02(router).addLiquidityETH{ value: currentEth }(
                address(this), currentTokenBalance, currentTokenBalance, currentEth, address(this), block.timestamp
            );
        } else if (poolType == LP_POOL.TraderJoe) {
            wNative = IJoeRouter02(router).WAVAX();
            (,, liquidity) = IJoeRouter02(router).addLiquidityAVAX{ value: currentEth }(
                address(this), currentTokenBalance, currentTokenBalance, currentEth, address(this), block.timestamp
            );
        }
        // Burn the LP tokens received
        IERC20 lpToken = IERC20(factory.getPair(address(this), wNative));
        lpToken.transfer(BURN_ADDRESS, liquidity);

        emit PairCreated(currentEth, currentTokenBalance, liquidity, address(lpToken));
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        // will revert for normal transfer till goal not reached
        if (
            !liquidityGoalReached() && from != address(0) && to != address(0) && from != address(this)
                && to != address(this) && !isLpCreated
        ) {
            revert TransferNotAllowedUntilLiquidityGoalReached();
        }
        super._update(from, to, value);
    }
}
