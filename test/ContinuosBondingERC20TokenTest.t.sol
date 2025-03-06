// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { stdMath } from "forge-std/src/StdMath.sol";

import { IUniswapV3Locker } from "src/interfaces/IUniswapV3Locker.sol";
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

    address internal uniswapV3Locker = 0xaacBE7601F589464cd27B09Ba87478fA1396Ed3C;
    address internal uniswapV3Factory = 0x62B672E531f8c11391019F6fba0b8B6143504169;
    address internal nonfungiblePositionManager = 0xC967b23826DdAB00d9AAd3702CbF5261B7Ed9a3a;

    address internal WETH = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;

    BondingERC20TokenFactory internal factory;
    IBondingCurve internal bondingCurve;
    ContinuosBondingERC20Token internal bondingERC20Token;
    IContinuousBondingERC20Token.AntiWhale internal _antiWhale =
        IContinuousBondingERC20Token.AntiWhale({ isEnabled: true, timePeriod: 0, pctSupply: 300 });

    function setUp() public {
        uint256 forkId = vm.createFork(vm.envString("AVAX_MAINNET_RPC_URL"), 58_153_914);
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
            uniswapV3Locker,
            WETH,
            _antiWhale,
            3000
        );

        vm.startPrank(owner);
        vm.stopPrank();

        bondingERC20Token =
            ContinuosBondingERC20Token(factory.deployBondingERC20TokenAndPurchase("ERC20Token", "ERC20", false));
    }

    function testSetUp() public view {
        assertEq(bondingERC20Token.initialTokenBalance(), initialTokenBalance);
        assertEq(bondingERC20Token.availableTokenBalance(), availableTokenBalance);
        assertEq(bondingERC20Token.treasuryClaimableEth(), 0);
    }

    function testAntiWhaleFeatureBasedOnMaxSupply() public {
        uint256 userInitialBalance = 100 ether; // Provide sufficient funds
        vm.deal(user, userInitialBalance); // Give user enough ETH to buy tokens

        BondingERC20TokenFactory tokenFactory = new BondingERC20TokenFactory(
            0x4dAb467dB2480422566cD57eae9624c6c273220E,
            bondingCurve,
            0x4dAb467dB2480422566cD57eae9624c6c273220E,
            25 ether,
            800_000_000 ether,
            100,
            100,
            0 ether, //// creation fee
            uniswapV3Factory,
            nonfungiblePositionManager,
            uniswapV3Locker,
            WETH,
            _antiWhale,
            3000
        );
        ContinuosBondingERC20Token token =
            ContinuosBondingERC20Token(tokenFactory.deployBondingERC20TokenAndPurchase("TestApe", "TestApe", true));

        assertEq(token.isAntiWhaleFlagEnabled(), true);

        uint256 maxSupply = token.MAX_TOTAL_SUPPLY();
        uint256 threePercenteSupply = (maxSupply * 3) / 100;

        console2.log("Max Total Supply:", maxSupply);
        console2.log("3% of MAX_TOTAL_SUPPLY:", threePercenteSupply);

        uint256 ethNeeded = token.calculateETHAmount(threePercenteSupply);
        console2.log("ETH needed to buy 3%:", ethNeeded);

        uint256 balanceBefore = token.balanceOf(user);
        console2.log("User balance before purchase:", balanceBefore);

        vm.startPrank(user);

        uint256 smallerAmount = (maxSupply * 290) / 10_000;
        uint256 ethNeededForSmallerAmount = token.calculateETHAmount(smallerAmount);

        console2.log("ETH needed for 2.9%:", ethNeededForSmallerAmount);
        token.buyTokens{ value: ethNeededForSmallerAmount }(0, user);

        vm.expectRevert(abi.encodeWithSignature("AntiWhaleFeatureEnabled()"));
        token.buyTokens{ value: 1 ether }(0, user);

        uint256 balanceAfter = token.balanceOf(user);
        console2.log("User balance after purchase:", balanceAfter);

        assertGt(balanceAfter, balanceBefore, "Balance should increase after buying within the limit");

        vm.stopPrank();
    }

    function testAntiWhaleFeature() public {
        bondingERC20Token =
            ContinuosBondingERC20Token(factory.deployBondingERC20TokenAndPurchase("ERC20Token", "ERC20", true));

        assertEq(bondingERC20Token.isAntiWhaleFlagEnabled(), true);

        uint256 amount = 100 ether;
        vm.deal(user, amount);
        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSignature("AntiWhaleFeatureEnabled()"));
        bondingERC20Token.buyTokens{ value: amount }(0, user);
        uint256 initialBalance = bondingERC20Token.balanceOf(user);
        bondingERC20Token.buyTokens{ value: 1.5 ether }(0, user);

        // Ensure the balance increased
        uint256 newBalance = bondingERC20Token.balanceOf(user);
        assertGt(newBalance, initialBalance, "Balance should increase after buying tokens");

        vm.stopPrank();
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

    function testCanBuyTokenTillLiquidityGoal() public {
        vm.deal(user, 10_000 ether);
        vm.startPrank(user);

        bondingERC20Token.buyTokens{ value: 202.2 ether }(0, user);

        vm.expectRevert();
        bondingERC20Token.buyTokens{ value: 1 wei }(0, user);

        // pair is created
        assertEq(bondingERC20Token.isLpCreated(), true);
        assertLt(bondingERC20Token.getReserve(), 1000);
        (, uint256 tokenId,) = bondingERC20Token.liquidityPosition();
        IUniswapV3Locker.LiquidityPosition memory position = (IUniswapV3Locker(uniswapV3Locker).positions(tokenId));

        assertEq(position.isLocked, true);
        assertEq(position.owner, address(bondingERC20Token));
    }

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
        assert(
            _withinRange(bondingERC20Token.treasuryClaimableEth() + treasury.balance, 1 ether + (0.01 * 99 ether), 2)
        );
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
