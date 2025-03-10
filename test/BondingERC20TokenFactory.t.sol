// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { BondingERC20TokenFactory } from "src/BondingERC20TokenFactory.sol";
import { IBondingCurve } from "src/interfaces/IBondingCurve.sol";
import { IContinuousBondingERC20Token } from "src/interfaces/IContinuousBondingERC20Token.sol";
import { IBondingERC20TokenFactory } from "src/interfaces/IBondingERC20TokenFactory.sol";
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
    uint256 internal creationFee = 0;
    address internal uniswapV3Locker = makeAddr("uniswapV3Locker");
    address internal uniswapV3Factory = makeAddr("uniswapV3Factory");
    address internal nonfungiblePositionManager = makeAddr("nonfungiblePositionManager");
    address internal WETH = makeAddr("WETH");
    IBondingERC20TokenFactory.AntiWhale internal _antiWhale =
        IBondingERC20TokenFactory.AntiWhale({ timePeriod: 0, pctSupply: 300 });

    function setUp() public {
        uint256 forkId = vm.createFork(vm.envString("AVAX_MAINNET_RPC_URL"), 58_153_914);
        vm.selectFork(forkId);

        router = 0x60aE616a2155Ee3d9A68541Ba4544862310933d4; // trader-joe router
        uniswapV3Locker = 0xaacBE7601F589464cd27B09Ba87478fA1396Ed3C;
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
            uniswapV3Locker,
            WETH,
            _antiWhale,
            3000
        );
    }

    function testDeployBondingERC20TokenSuccess() public {
        address bondingERC20Token = factory.deployBondingERC20TokenAndPurchase("ERC20Token", "ERC20", false);

        assertNotEq(bondingERC20Token, address(0));
        assertEq(address(IContinuousBondingERC20Token(bondingERC20Token).bondingCurve()), address(bondingCurve));
        assertEq(IContinuousBondingERC20Token(bondingERC20Token).TREASURY_ADDRESS(), treasury);
        assertEq(IContinuousBondingERC20Token(bondingERC20Token).availableTokenBalance(), availableTokenBalance);
        assertEq(IContinuousBondingERC20Token(bondingERC20Token).initialTokenBalance(), initialTokenBalance);
        assertEq(IContinuousBondingERC20Token(bondingERC20Token).isAntiWhaleFlagEnabled(), false);
    }

    function testUpdateBondingCurveSuccess() public {
        address bondingERC20TokenOldBondingCurve =
            factory.deployBondingERC20TokenAndPurchase("ERC20Token", "ERC20", false);
        IBondingCurve newBondingCurve = new AMMFormula();

        vm.startPrank(owner);
        factory.updateBondingCurve(newBondingCurve);

        address bondingERC20TokenNewBondingCurve =
            factory.deployBondingERC20TokenAndPurchase("ERC20Token", "ERC20", false);

        assertEq(
            address(IContinuousBondingERC20Token(bondingERC20TokenOldBondingCurve).bondingCurve()),
            address(bondingCurve)
        );
        assertEq(
            address(IContinuousBondingERC20Token(bondingERC20TokenNewBondingCurve).bondingCurve()),
            address(newBondingCurve)
        );
    }

    function testCreationFee() public {
        vm.prank(owner);
        factory.updateCreationFee(0.01 ether);

        vm.expectRevert();
        factory.deployBondingERC20TokenAndPurchase{ value: 0.001 ether }("ERC20Token", "ERC20", false);

        factory.deployBondingERC20TokenAndPurchase{ value: 0.01 ether }("ERC20Token", "ERC20", false);

        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(owner);
        factory.claimFees();

        uint256 treasuryBalanceAfter = treasury.balance;

        assertEq(treasuryBalanceAfter - treasuryBalanceBefore, 0.01 ether);
    }

    function testUpdateBondingCurveFail() public {
        IBondingCurve newBondingCurve = new AMMFormula();

        vm.startPrank(makeAddr("random"));
        vm.expectRevert();
        factory.updateBondingCurve(newBondingCurve);
    }

    function testUpdateTreasurySuccess() public {
        address bondingERC20TokenOldTreasury = factory.deployBondingERC20TokenAndPurchase("ERC20Token", "ERC20", false);
        address newTreasury = makeAddr("newTreasury");

        vm.startPrank(owner);
        factory.updateTreasury(newTreasury);

        address bondingERC20TokenNewTreasury = factory.deployBondingERC20TokenAndPurchase("ERC20Token", "ERC20", false);

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
