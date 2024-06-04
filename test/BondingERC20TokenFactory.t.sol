// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { BondingERC20TokenFactory, TokenDeployed } from "src/BondingERC20TokenFactory.sol";
import { IBondingCurve } from "src/interfaces/IBondingCurve.sol";
import { IContinuousBondingERC20Token } from "src/interfaces/IContinuousBondingERC20Token.sol";
import { AMMFormula } from "src/utils/AMMFormula.sol";

contract BondingERC20TokenFactoryTest is Test {
  BondingERC20TokenFactory internal factory;
  IBondingCurve internal bondingCurve;
  address internal router;
  address internal treasury = makeAddr("treasury");
  address internal owner = makeAddr("owner");
  uint256 internal availableTokenBalance = 800_000_000 ether;
  uint256 internal initialTokenBalance = 50 * 10 ** 18;
  uint256 internal buyFee = 100;
  uint256 internal sellFee = 100;

  function setUp() public {
    uint256 forkId = vm.createFork(vm.envString("AVAX_RPC_URL"), 19876830);
    vm.selectFork(forkId);

    router = 0x60aE616a2155Ee3d9A68541Ba4544862310933d4; // trader-joe router
    bondingCurve = new AMMFormula();
    factory = new BondingERC20TokenFactory(
      owner,
      bondingCurve,
      treasury,
      initialTokenBalance,
      availableTokenBalance,
      buyFee,
      sellFee
    );
  }

  function testDeployBondingERC20TokenSuccess() public {
    address bondingERC20Token = factory.deployBondingERC20Token(router, "ERC20Token", "ERC20");

    assertNotEq(bondingERC20Token, address(0));
    assertEq(IContinuousBondingERC20Token(bondingERC20Token).bondingCurve(), address(bondingCurve));
    assertEq(IContinuousBondingERC20Token(bondingERC20Token).TREASURY_ADDRESS(), treasury);
    assertEq(IContinuousBondingERC20Token(bondingERC20Token).availableTokenBalance(), availableTokenBalance);
    assertEq(IContinuousBondingERC20Token(bondingERC20Token).initialTokenBalance(), initialTokenBalance);
  }

  function testUpdateBondingCurveSuccess() public {
    address bondingERC20TokenOldBondingCurve = factory.deployBondingERC20Token(router, "ERC20Token", "ERC20");
    IBondingCurve newBondingCurve = new AMMFormula();

    vm.startPrank(owner);
    factory.updateBondingCurve(newBondingCurve);

    address bondingERC20TokenNewBondingCurve = factory.deployBondingERC20Token(router, "ERC20Token", "ERC20");

    assertEq(IContinuousBondingERC20Token(bondingERC20TokenOldBondingCurve).bondingCurve(), address(bondingCurve));
    assertEq(IContinuousBondingERC20Token(bondingERC20TokenNewBondingCurve).bondingCurve(), address(newBondingCurve));
  }

  function testUpdateBondingCurveFail() public {
    IBondingCurve newBondingCurve = new AMMFormula();

    vm.startPrank(makeAddr("random"));
    vm.expectRevert();
    factory.updateBondingCurve(newBondingCurve);
  }

  function testUpdateTreasurySuccess() public {
    address bondingERC20TokenOldTreasury = factory.deployBondingERC20Token(router, "ERC20Token", "ERC20");
    address newTreasury = makeAddr("newTreasury");

    vm.startPrank(owner);
    factory.updateTreasury(newTreasury);

    address bondingERC20TokenNewTreasury = factory.deployBondingERC20Token(router, "ERC20Token", "ERC20");

    assertEq(IContinuousBondingERC20Token(bondingERC20TokenOldTreasury).TREASURY_ADDRESS(), treasury);
    assertEq(IContinuousBondingERC20Token(bondingERC20TokenNewTreasury).TREASURY_ADDRESS(), newTreasury);
  }

  function testUpdateTreasuryFail() public {
    address newTreasury = makeAddr("newTreasury");

    vm.startPrank(makeAddr("random"));
    vm.expectRevert();
    factory.updateTreasury(newTreasury);
  }
}
