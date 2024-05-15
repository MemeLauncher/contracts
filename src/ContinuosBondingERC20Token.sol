// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import { IBondingCurve } from "./interfaces/IBondingCurve.sol";
import { BancorFormula } from "./BancorCurve/BancorFormula.sol";

error NeedToSendETH();
error NeedToSellTokens();
error ContractNotEnoughETH();
error FailedToSendETH();
error LiquidityGoalReached();
error ContributionMoreThanGoal();
error TransferNotAllowedUntilLiquidityGoalReached();
error InvalidSender();

// TODO: Review, Audit.
// 4. Add max supply.
// 5. Once liquidity goal is reached, the remanining supply is minted and added to the LP.
// 6. Make sure there are not arbitrage oportunities once LP is created. (Maybe we add a cooldown for existing holders
// 7. LP tokens should be burned after pair creation (or kept in the token contract).

contract ContinuosBondingERC20Token is ERC20, ReentrancyGuard {
  IBondingCurve public immutable bondingCurve;
  IUniswapV2Router02 public immutable router;
  IUniswapV2Factory public immutable factory;
  address public immutable WETH;
  address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
  address public immutable TREASURY_ADDRESS;
  uint256 public constant RESERVE_RATIO = 1e6; // Price factor for logarithmic curve
  uint256 public constant liquidityGoal = 400 ether; //400 avax
  uint256 public constant PERCENTAGE_DENOMINATOR = 10_000; // 100%
  uint256 public totalETHContributed;
  uint256 public treasuryClaimableETH;
  uint256 public buyFee;
  uint256 public sellFee;

  constructor(
    address _router,
    string memory _name,
    string memory _symbol,
    address _treasury,
    uint256 _buyFee,
    uint256 _sellFee,
    IBondingCurve _bondingCurve
  ) ERC20(_name, _symbol) {
    router = IUniswapV2Router02(_router);
    factory = IUniswapV2Factory(router.factory());
    WETH = router.WETH();
    TREASURY_ADDRESS = _treasury;
    buyFee = _buyFee;
    sellFee = _sellFee;
    bondingCurve = _bondingCurve;
    _mint(address(0), 1000);
  }

  function buyTokens() external payable {
    if (liquidityGoalReached()) revert LiquidityGoalReached();
    if (msg.value == 0) revert NeedToSendETH();

    uint256 ethAmount = msg.value;
    uint256 feeAmount = (ethAmount * buyFee) / PERCENTAGE_DENOMINATOR;
    uint256 remainingAmount = ethAmount - feeAmount;

    treasuryClaimableETH += feeAmount;
    uint256 tokenBought = bondingCurve.calculatePurchaseReturn(
      totalSupply(),
      totalETHContributed,
      uint32(RESERVE_RATIO),
      remainingAmount
    );
    _mint(msg.sender, tokenBought);
    totalETHContributed += ethAmount;
    if (totalETHContributed == liquidityGoal) {
      _createPair();
    } else if (totalETHContributed > liquidityGoal) {
      revert ContributionMoreThanGoal();
    }
  }

  function sellTokens(uint256 tokenAmount) external nonReentrant {
    if (liquidityGoalReached()) revert LiquidityGoalReached();
    if (tokenAmount == 0) revert NeedToSellTokens();

    uint256 reimburseAmount = bondingCurve.calculateSaleReturn(
      totalSupply(),
      totalETHContributed,
      uint32(RESERVE_RATIO),
      tokenAmount
    );
    if (address(this).balance < reimburseAmount) revert ContractNotEnoughETH();

    uint256 feeAmount = (reimburseAmount * sellFee) / PERCENTAGE_DENOMINATOR;
    reimburseAmount -= feeAmount;
    treasuryClaimableETH += feeAmount;

    _burn(msg.sender, tokenAmount);
    (bool sent, ) = msg.sender.call{ value: reimburseAmount }("");
    if (!sent) revert FailedToSendETH();
  }

  function liquidityGoalReached() public view returns (bool) {
    return (totalETHContributed >= liquidityGoal);
  }

  function calculateTokenAmount(uint256 ethAmount) public view returns (uint256) {
    bondingCurve.calculatePurchaseReturn(totalSupply(), totalETHContributed, uint32(RESERVE_RATIO), ethAmount);
  }

  function calculateETHAmount(uint256 tokenAmount) public view returns (uint256) {
    bondingCurve.calculateSaleReturn(totalSupply(), totalETHContributed, uint32(RESERVE_RATIO), tokenAmount);
  }

  function claimTreasuryBalance(address to, uint256 amount) public {
    if (msg.sender != TREASURY_ADDRESS) {
      revert InvalidSender();
    }
    // this will revert if amount requested is more than claimable
    treasuryClaimableETH -= amount;
    (bool sent, ) = to.call{ value: amount }("");
    if (!sent) revert FailedToSendETH();
  }

  // TODO change this because we will need to determine parameters to create liquidity
  function _createPair() internal {
    uint256 ethAmount = address(this).balance;
    uint256 tokenAmount = this.balanceOf(address(this));
    _approve(address(this), address(router), tokenAmount);

    // Add liquidity
    (, , uint256 liquidity) = router.addLiquidityETH{ value: ethAmount }(
      address(this),
      tokenAmount,
      tokenAmount,
      ethAmount,
      address(this),
      block.timestamp
    );

    // Burn the LP tokens received
    IERC20 lpToken = IERC20(factory.getPair(address(this), WETH));
    lpToken.transfer(BURN_ADDRESS, liquidity);
  }

  function _update(address from, address to, uint256 value) internal virtual override {
    // will revert for normal transfer till goal not reached
    if (!liquidityGoalReached() && from != address(0) && to != address(0)) {
      revert TransferNotAllowedUntilLiquidityGoalReached();
    }
    super._update(from, to, value);
  }
}
