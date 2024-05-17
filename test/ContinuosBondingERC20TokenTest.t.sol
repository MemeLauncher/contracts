// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { BondingERC20TokenFactory } from "src/BondingERC20TokenFactory.sol";
import { ContinuosBondingERC20Token } from "src/ContinuosBondingERC20Token.sol";
import { IContinuousBondingERC20Token } from "src/interfaces/IContinuousBondingERC20Token.sol";
import { IBondingCurve } from "src/interfaces/IBondingCurve.sol";
import { BancorFormula } from "src/BancorCurve/BancorFormula.sol";

contract ContinuosBondingERC20TokenTest is Test {
  BondingERC20TokenFactory internal factory;
  IBondingCurve internal bondingCurve;
  address internal router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  address internal treasury = makeAddr("treasury");
  address internal owner = makeAddr("owner");
  address internal user = makeAddr("user");
  ContinuosBondingERC20Token internal bondingERC20Token;

  function setUp() public {
    uint256 forkId = vm.createFork(vm.envString("ETH_RPC_URL"), 19876830);
    vm.selectFork(forkId);

    bondingCurve = new BancorFormula();
    factory = new BondingERC20TokenFactory(owner, bondingCurve, treasury);
    bondingERC20Token = ContinuosBondingERC20Token(
      factory.deployBondingERC20Token(router, "ERC20Token", "ERC20", 100, 100)
    );
  }

  function testCanBuyToken() public {
    uint256 amount = 100 ether;
    vm.deal(user, amount);
    vm.startPrank(user);

    uint256 beforeBalanceOfBondingToken = bondingERC20Token.balanceOf(user);

    bondingERC20Token.buyTokens{ value: amount }();

    uint256 afterBalanceOfBondingToken = bondingERC20Token.balanceOf(user);
    uint256 tokenPerWei = afterBalanceOfBondingToken / amount;

    assertGt(afterBalanceOfBondingToken, 0);
    assertGt(tokenPerWei, 0);
    assertEq(bondingERC20Token.totalETHContributed(), 99 ether); // 1% goes to treasury
    assertEq(bondingERC20Token.treasuryClaimableETH(), 1 ether); // 1% treasury funds

    //user has tokens worth roughly equivalent to 99 ether.
    uint256 ethUserShouldGet = bondingERC20Token.calculateETHAmount(afterBalanceOfBondingToken);
    assertEq(ethUserShouldGet, 99 ether - 1 wei); // 1 wei stays in the contract because curve started from 1 wei when totalEthContributed was 0
  }

  function testCanSellToken() public {
    testCanBuyToken();

    uint256 balanceOfBondingToken = bondingERC20Token.balanceOf(user);

    uint256 ethBalanceBefore = user.balance;

    bondingERC20Token.sellTokens(balanceOfBondingToken);

    uint256 ethReceived = user.balance - ethBalanceBefore;

    assertEq(ethReceived, 99 ether - (0.01 * 99 ether));
    assertEq(bondingERC20Token.treasuryClaimableETH(), 1 ether + 0.01 * 99 ether - 1 wei);
    assertEq(bondingERC20Token.totalETHContributed(), 1 wei);
    assertEq(bondingERC20Token.totalSupply(), 1000);
  }
}
