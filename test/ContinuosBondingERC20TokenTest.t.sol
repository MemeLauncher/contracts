// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { stdMath } from "forge-std/src/StdMath.sol";

import { BondingERC20TokenFactory } from "src/BondingERC20TokenFactory.sol";
import { ContinuosBondingERC20Token } from "src/ContinuosBondingERC20Token.sol";
import { IContinuousBondingERC20Token } from "src/interfaces/IContinuousBondingERC20Token.sol";
import { IBondingCurve } from "src/interfaces/IBondingCurve.sol";
import { AMMFormula } from "src/utils/AMMFormula.sol";

contract ContinuosBondingERC20TokenTest is Test {
  address internal treasury = makeAddr("treasury");
  address internal owner = makeAddr("owner");
  address internal user = makeAddr("user");
  uint256 internal availableTokenBalance = 800_000_000 ether;
  uint256 internal initialTokenBalance = 50 ether; // liquidity goal will be reached at (50*4) avax. formula can be
  // generalised
  uint256 internal expectedLiquidityGoal = 200 ether;
  uint256 internal MAX_TOTAL_SUPPLY = 1_000_000_000 ether;
  uint256 internal buyFee = 100;
  uint256 internal sellFee = 100;
  uint256 internal creationFee = 0;

  address internal uniswapV3Factory = makeAddr("uniswapV3Factory");
  address internal nonfungiblePositionManager = makeAddr("nonfungiblePositionManager");
  address internal WETH = makeAddr("WETH");

  BondingERC20TokenFactory internal factory;
  IBondingCurve internal bondingCurve;
  ContinuosBondingERC20Token internal bondingERC20Token;

  function setUp() public {
    uint256 forkId = vm.createFork(vm.envString("AVAX_MAINNET_RPC_URL"), 53021860);
    vm.selectFork(forkId);
    bondingCurve = new AMMFormula();
    factory = new BondingERC20TokenFactory(
      owner,
      bondingCurve,
      treasury,
      initialTokenBalance,
      availableTokenBalance,
      buyFee,
      sellFee,
      creationFee,
      uniswapV3Factory,
      nonfungiblePositionManager,
      WETH
    );

    vm.startPrank(owner);
    vm.stopPrank();

    bondingERC20Token = ContinuosBondingERC20Token(factory.deployBondingERC20TokenAndPurchase("ERC20Token", "ERC20"));
  }

  function testSetUp() public view {
    assertEq(bondingERC20Token.initialTokenBalance(), initialTokenBalance);
    assertEq(bondingERC20Token.availableTokenBalance(), availableTokenBalance);
    assertEq(bondingERC20Token.treasuryClaimableEth(), 0);
  }

  function testCanBuyToken() public {
    uint256 amount = 100 ether;
    vm.deal(user, amount);
    vm.startPrank(user);

    // uint256 beforeBalanceOfBondingToken = bondingERC20Token.balanceOf(user);

    bondingERC20Token.buyTokens{ value: amount }(0, user);

    uint256 afterBalanceOfBondingToken = bondingERC20Token.balanceOf(user);
    uint256 tokenPerWei = afterBalanceOfBondingToken / amount;

    assertGt(afterBalanceOfBondingToken, 0);
    assertGt(tokenPerWei, 0);
    assertEq(bondingERC20Token.totalEthContributed(), 99 ether); // 1% goes to treasury
    assertEq(bondingERC20Token.treasuryClaimableEth() + treasury.balance, 1 ether); // 1% treasury funds
  }

  // TODO: update test to use fork testing and sepolia uniswap v3 contracts
  // function testCanBuyTokenTillLiquidityGoal() public {
  //   vm.deal(user, 10_000 ether);
  //   vm.startPrank(user);

  //   bondingERC20Token.buyTokens{ value: 202.2 ether }(0);

  //   vm.expectRevert();
  //   bondingERC20Token.buyTokens{ value: 1 wei }(0);

  //   // pair is created
  //   assertEq(bondingERC20Token.isLpCreated(), true);
  //   assertEq(bondingERC20Token.getReserve(), 0);
  // }

  function testCanBuyTokenFuzz(uint256 amount) public {
    amount = bound(amount, 101, expectedLiquidityGoal);
    vm.deal(user, amount);
    uint256 feeAmount = amount / 100;

    vm.startPrank(user);
    bondingERC20Token.buyTokens{ value: amount }(0, user);

    assertEq(bondingERC20Token.totalEthContributed(), amount - feeAmount);
    assertEq(bondingERC20Token.treasuryClaimableEth() + treasury.balance, feeAmount);
  }

  function testPriceIncreasesAfterEachBuy() public {
    uint256 amount = 100 ether;
    uint256 halfAmount = amount / 2;

    vm.deal(user, amount);
    vm.startPrank(user);

    // uint256 beforeBalanceOfBondingToken = bondingERC20Token.balanceOf(user);
    bondingERC20Token.buyTokens{ value: halfAmount }(0, user);
    uint256 receivedAfterFirstBuy = bondingERC20Token.balanceOf(user);
    uint256 tokenPerWeiForFirstBuy = (receivedAfterFirstBuy * 1e18) / halfAmount;

    bondingERC20Token.buyTokens{ value: halfAmount }(0, user);
    uint256 receivedAfterSecondBuy = bondingERC20Token.balanceOf(user) - receivedAfterFirstBuy;
    uint256 tokenPerWeiForSecondBuy = (receivedAfterSecondBuy * 1e18) / halfAmount;
    assertGt(receivedAfterFirstBuy, receivedAfterSecondBuy);
    assertGt(tokenPerWeiForFirstBuy, tokenPerWeiForSecondBuy);
  }

  function testNearlyEqualTokenMintedForEqualInputAmount() public {
    uint256 amount = 1000 ether;

    vm.deal(user, amount);
    vm.startPrank(user);

    bondingERC20Token.buyTokens{ value: 40 ether }(0, user);
    bondingERC20Token.buyTokens{ value: 60 ether }(0, user);
    uint256 reserve1 = bondingERC20Token.getReserve();
    uint256 totalEthContributed1 = bondingERC20Token.totalEthContributed();
    uint256 treasuryClaimableEth1 = bondingERC20Token.treasuryClaimableEth();

    // resetting the state to initial
    setUp();

    vm.deal(user, amount);
    vm.startPrank(user);

    bondingERC20Token.buyTokens{ value: 50 ether }(0, user);
    bondingERC20Token.buyTokens{ value: 50 ether }(0, user);
    uint256 reserve2 = bondingERC20Token.getReserve();
    uint256 totalEthContributed2 = bondingERC20Token.totalEthContributed();
    uint256 treasuryClaimableEth2 = bondingERC20Token.treasuryClaimableEth();

    assertEq(reserve1, reserve2);
    assertEq(totalEthContributed1, totalEthContributed2);
    assertEq(treasuryClaimableEth1, treasuryClaimableEth2);
  }

  function testCanSellToken() public {
    uint256 amount = 100 ether;
    vm.deal(user, amount);
    vm.startPrank(user);

    bondingERC20Token.buyTokens{ value: amount }(0, user);

    uint256 balanceOfBondingToken = bondingERC20Token.balanceOf(user);

    uint256 ethBalanceBefore = user.balance;

    bondingERC20Token.sellTokens(balanceOfBondingToken, 0);

    uint256 ethReceived = user.balance - ethBalanceBefore;

    console2.log(ethReceived);

    assert(_withinRange(ethReceived, 99 ether - (0.01 * 99 ether), 1e2));
    assert(_withinRange(bondingERC20Token.treasuryClaimableEth() + treasury.balance, 1 ether + (0.01 * 99 ether), 2));
    assert(_withinRange(bondingERC20Token.totalEthContributed(), 0, 2));
    assertEq(bondingERC20Token.balanceOf(user), 0);
  }

  function testSellTokenRevert() public {
    uint256 amount = 100 ether;
    vm.deal(user, amount);
    vm.startPrank(user);

    bondingERC20Token.buyTokens{ value: amount }(0, user);

    uint256 balanceOfBondingToken = bondingERC20Token.balanceOf(user);

    // uint256 ethBalanceBefore = user.balance;

    vm.expectRevert();
    bondingERC20Token.sellTokens(balanceOfBondingToken + 1, 0);
  }

  function _withinRange(uint256 a, uint256 b, uint256 diff) internal pure returns (bool) {
    return (stdMath.delta(a, b) <= diff);
  }
}
