// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import { IBondingCurve } from "./interfaces/IBondingCurve.sol";

error NeedToSendETH();
error NeedToSellTokens();
error ContractNotEnoughETH();
error FailedToSendETH();
error InsufficientETH();
error TransferNotAllowedUntilLiquidityGoalReached();
error InvalidSender();
error LPCanNotBeCreated();
error LiquidityGoalReached();

contract ContinuosBondingERC20Token is ERC20, ReentrancyGuard {
  uint256 public constant PERCENTAGE_DENOMINATOR = 10_000; // 100%
  address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
  uint256 public constant MAX_TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;

  IBondingCurve public immutable bondingCurve;
  IUniswapV2Router02 public immutable router;
  IUniswapV2Factory public immutable factory;
  address public immutable WETH;
  address public immutable TREASURY_ADDRESS;

  uint256 public initialTokenBalance;
  uint256 public ethBalance;
  uint256 public availableTokenBalance;
  uint256 public buyFee;
  uint256 public sellFee;
  uint256 public treasuryClaimableEth;
  bool public isLpCreated;

  constructor(
    address _router,
    string memory _name,
    string memory _symbol,
    address _treasury,
    uint256 _buyFee,
    uint256 _sellFee,
    IBondingCurve _bondingCurve,
    uint256 _initialTokenBalance,
    uint256 _availableTokenBalance
  ) ERC20(_name, _symbol) {
    router = IUniswapV2Router02(_router);
    factory = IUniswapV2Factory(router.factory());
    WETH = router.WETH();
    TREASURY_ADDRESS = _treasury;
    buyFee = _buyFee;
    sellFee = _sellFee;
    bondingCurve = _bondingCurve;
    _mint(address(this), MAX_TOTAL_SUPPLY);
    initialTokenBalance = _initialTokenBalance;
    ethBalance = _initialTokenBalance;
    availableTokenBalance = _availableTokenBalance;
  }

  function buyTokens() external payable nonReentrant returns (uint256) {
    if (liquidityGoalReached()) revert LiquidityGoalReached();
    if (msg.value == 0) revert NeedToSendETH();

    uint256 ethAmount = msg.value;
    uint256 feeAmount = (ethAmount * buyFee) / PERCENTAGE_DENOMINATOR;
    uint256 remainingAmount = ethAmount - feeAmount;

    uint256 tokenReserveBalance = getReserve();
    uint256 maxTokenToReceive = tokenReserveBalance - (MAX_TOTAL_SUPPLY - availableTokenBalance);

    uint256 tokensToReceive = bondingCurve.calculatePurchaseReturn(
      remainingAmount,
      ethBalance,
      tokenReserveBalance,
      bytes("")
    );
    uint256 ethReceivedAmount = remainingAmount;
    uint256 refund;
    if (tokensToReceive > maxTokenToReceive) {
      tokensToReceive = maxTokenToReceive;
      ethReceivedAmount = getOutputPrice(tokensToReceive, ethBalance, tokenReserveBalance);
      feeAmount = (ethReceivedAmount * buyFee) / PERCENTAGE_DENOMINATOR;
      if (msg.value < (feeAmount + ethReceivedAmount)) {
        revert InsufficientETH();
      }
      refund = msg.value - (feeAmount + ethReceivedAmount);
    }
    ethBalance += remainingAmount;
    treasuryClaimableEth += feeAmount;

    _transfer(address(this), msg.sender, tokensToReceive);

    (bool sent, ) = msg.sender.call{ value: refund }("");
    if (!sent) {
      revert FailedToSendETH();
    }

    if (liquidityGoalReached()) {
      _createPair();
    }

    return tokensToReceive;
  }

  function sellTokens(uint256 tokenAmount) external nonReentrant returns (uint256) {
    if (liquidityGoalReached()) revert LiquidityGoalReached();
    if (tokenAmount == 0) revert NeedToSellTokens();

    uint256 tokenReserveBalance = getReserve();
    uint256 reimburseAmount = bondingCurve.calculateSaleReturn(tokenAmount, tokenReserveBalance, ethBalance, bytes(""));

    uint256 feeAmount = (reimburseAmount * sellFee) / PERCENTAGE_DENOMINATOR;
    ethBalance -= reimburseAmount;
    reimburseAmount -= feeAmount;
    treasuryClaimableEth += feeAmount;

    if (address(this).balance < reimburseAmount) revert ContractNotEnoughETH();

    _transfer(msg.sender, address(this), tokenAmount);
    (bool sent, ) = msg.sender.call{ value: reimburseAmount }("");
    if (!sent) revert FailedToSendETH();
  }

  function getReserve() public view returns (uint256) {
    return balanceOf(address(this));
  }

  function getOutputPrice(
    uint256 outputAmount,
    uint256 inputReserve,
    uint256 outputReserve
  ) public pure returns (uint256) {
    require(inputReserve > 0 && outputReserve > 0, "Reserves must be greater than 0");
    uint256 numerator = inputReserve * outputAmount;
    uint256 denominator = (outputReserve - outputAmount);
    return numerator / denominator + 1;
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
    (bool sent, ) = to.call{ value: amount }("");
    if (!sent) revert FailedToSendETH();
  }

  function _createPair() internal {
    uint256 currentTokenBalance = getReserve();
    uint256 currentEth = ethBalance - initialTokenBalance;
    isLpCreated = true;

    _approve(address(this), address(router), currentTokenBalance);

    // // Add liquidity
    (, , uint256 liquidity) = router.addLiquidityETH{ value: currentEth }(
      address(this),
      currentTokenBalance,
      currentTokenBalance,
      currentEth,
      address(this),
      block.timestamp
    );
    // // Burn the LP tokens received
    IERC20 lpToken = IERC20(factory.getPair(address(this), WETH));
    lpToken.transfer(BURN_ADDRESS, liquidity);
  }

  function _update(address from, address to, uint256 value) internal virtual override {
    // will revert for normal transfer till goal not reached
    if (
      !liquidityGoalReached() && from != address(0) && to != address(0) && from != address(this) && to != address(this)
    ) {
      revert TransferNotAllowedUntilLiquidityGoalReached();
    }
    super._update(from, to, value);
  }
}
