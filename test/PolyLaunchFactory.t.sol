// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../src/PolyLaunchFactory.sol";
import "../src/MockUSDC.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../src/MockRouter.sol";
import "../src/MockPair.sol";
import "../src/MockFactory.sol";
import "../src/FailingRouter.sol";
import "../src/MissingPairFactory.sol";
import "../src/dex/PolyPair.sol";

contract PolyLaunchFactoryTest is Test {
    PolyLaunchFactory factory;
    MockUSDC usdc;

    address treasury = address(0x1);
    address user = address(0x2);
    MockPair pair;
    MockRouter mockRouter;
    MockFactory mockFactory;

    function setUp() public {
        usdc = new MockUSDC();
        pair = new MockPair();
        mockFactory = new MockFactory(address(pair));
        mockRouter = new MockRouter(address(pair), address(mockFactory));

        factory = new PolyLaunchFactory(treasury, address(usdc), address(mockRouter), address(mockFactory));

        usdc.mint(user, 1_000_000e6);

        vm.prank(user);
        usdc.approve(address(factory), type(uint256).max);
    }

    function testDeployment() public view {
        assertTrue(address(factory) != address(0));
    }

    function testLaunchFeeConstant() public view {
        assertEq(factory.LAUNCH_FEE(), 1e6);
    }

    function testGraduationConstant() public view {
        assertEq(factory.GRADUATION_USDC(), 150e6);
    }

    function testCreateProject() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        assertEq(factory.totalProjects(), 1);

        PolyLaunchFactory.Project memory project = factory.getProject(1);

        assertEq(project.metadataURI, "ipfs://test-metadata");
    }

    function testBuyTokens() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        uint256 buyAmount = 1000;

        vm.prank(user);

        factory.buy(1, buyAmount);

        assertEq(factory.totalProjects(), 1);

        PolyLaunchFactory.Project memory project = factory.getProject(1);

        assertEq(project.sold, buyAmount);
    }

    function testGetBuyQuote() public {
        vm.prank(user);
        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        uint256 amount = 1_000_000 ether;

        uint256 quote = factory.getBuyQuote(1, amount);

        assertGt(quote, 0);
    }

    function testGetSellQuote() public {
        vm.prank(user);
        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        uint256 amount = 1_000_000 ether;

        vm.prank(user);
        factory.buy(1, amount);

        uint256 quote = factory.getSellQuote(1, amount);

        assertGt(quote, 0);
    }

    function testSellTokens() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        uint256 buyAmount = 1000;

        vm.prank(user);
        factory.buy(1, buyAmount);

        vm.startPrank(user);

        IERC20(factory.getProject(1).token).approve(address(factory), buyAmount);

        factory.sell(1, buyAmount);

        vm.stopPrank();

        PolyLaunchFactory.Project memory project = factory.getProject(1);

        assertEq(project.sold, 0);
    }

    function testTokenAllocation() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        PolyLaunchFactory.Project memory project = factory.getProject(1);

        assertEq(project.reserveTokens, 800_000_000 ether);
        assertEq(project.liquidityTokens, 200_000_000 ether);
        assertEq(project.reserveTokens + project.liquidityTokens, project.totalSupply);
    }

    function testGraduation() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        PolyLaunchFactory.Project memory before = factory.getProject(1);

        assertEq(before.liquidityTokens, 200_000_000 ether);
        assertEq(before.reserveTokens, 800_000_000 ether);
        assertFalse(before.graduated);
        assertTrue(before.active);

        // Buy enough tokens to cross the 150 USDC graduation target.
        uint256 amount = 400_000_000 ether;

        vm.prank(user);
        factory.buy(1, amount);

        PolyLaunchFactory.Project memory afterBuy = factory.getProject(1);

        // Graduation target was reached.
        assertGe(afterBuy.reserveUSDC, factory.GRADUATION_USDC());

        // Project graduated and is no longer active.
        assertTrue(afterBuy.graduated);
        assertFalse(afterBuy.active);

        // The bonding curve sold the purchased tokens.
        assertEq(afterBuy.sold, amount);

        // The remaining bonding-curve allocation is 400M tokens.
        assertEq(afterBuy.reserveTokens, 400_000_000 ether);

        // The 20% liquidity allocation remains defined.
        assertEq(afterBuy.liquidityTokens, 200_000_000 ether);

        // The permanent token locker should hold all remaining curve tokens.
        address tokenLocker = address(factory.tokenLocker());

        assertEq(
            IERC20(afterBuy.token).balanceOf(tokenLocker),
            400_000_000 ether
        );

        (uint256 lockedTokens, bool permanentlyLocked) =
            factory.tokenLocker().locks(afterBuy.token);

        assertEq(lockedTokens, 400_000_000 ether);
        assertTrue(permanentlyLocked);

        // The Factory should retain no project tokens after graduation.
        assertEq(
            IERC20(afterBuy.token).balanceOf(address(factory)),
            0
        );

        // LP tokens should now belong to the locker.
        address locker = address(factory.lpLocker());

        uint256 lockedLP = IERC20(address(pair)).balanceOf(locker);

        assertGt(lockedLP, 0);

        // Factory should no longer hold the LP tokens.
        assertEq(IERC20(address(pair)).balanceOf(address(factory)), 0);

        // Verify the LP lock.
        (uint256 lockAmount, uint256 unlockTime, bool claimed) = factory.lpLocker().locks(address(pair));

        assertEq(lockAmount, lockedLP);
        assertGt(unlockTime, block.timestamp);
        assertFalse(claimed);
    }


   

    function testCannotBuyZeroTokens() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        vm.prank(user);

        vm.expectRevert("Invalid amount");
        factory.buy(1, 0);
    }

    function testCannotSellMoreThanSold() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        vm.prank(user);

        vm.expectRevert("Not enough sold");
        factory.sell(1, 1);
    }

    function testCannotTradeAfterGraduation() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        // Cross the graduation target.
        uint256 amount = 400_000_000 ether;

        vm.prank(user);
        factory.buy(1, amount);

        PolyLaunchFactory.Project memory project = factory.getProject(1);

        assertTrue(project.graduated);
        assertFalse(project.active);

        // Buying after graduation must fail.
        vm.prank(user);

        vm.expectRevert("Project inactive");
        factory.buy(1, 1);
    }

    function testGraduationLiquidityAccounting() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        uint256 amount = 400_000_000 ether;

        vm.prank(user);
        factory.buy(1, amount);

        PolyLaunchFactory.Project memory project = factory.getProject(1);

        assertTrue(project.graduated);
        assertFalse(project.active);

        // The dedicated 20% allocation was used for liquidity.
        assertEq(project.liquidityTokens, 200_000_000 ether);

        // The mock router received the liquidity assets.
        assertEq(IERC20(project.token).balanceOf(address(mockRouter)), 200_000_000 ether);

        assertEq(usdc.balanceOf(address(mockRouter)), project.reserveUSDC);

        // LP tokens are locked.
        address locker = address(factory.lpLocker());

        uint256 lockedLP = IERC20(address(pair)).balanceOf(locker);

        assertGt(lockedLP, 0);
    }

    function testCurvePriceIncreases() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        PolyLaunchFactory.Project memory before = factory.getProject(1);

        uint256 priceBefore = BondingCurve.currentPrice(before.sold);

        vm.prank(user);
        factory.buy(1, 100_000 ether);

        PolyLaunchFactory.Project memory afterBuy = factory.getProject(1);

        uint256 priceAfter = BondingCurve.currentPrice(afterBuy.sold);

        assertGt(priceAfter, priceBefore);
    }

    function testCannotBuyMoreThanCurveReserve() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        vm.expectRevert("Curve supply exceeded");

        vm.prank(user);
        factory.buy(1, 800_000_000 ether);
    }

    function testBuySellRoundTripAccounting() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        uint256 amount = 10_000 ether;

        vm.prank(user);
        factory.buy(1, amount);

        PolyLaunchFactory.Project memory afterBuy = factory.getProject(1);

        assertEq(afterBuy.sold, amount);

        vm.startPrank(user);

        IERC20(afterBuy.token).approve(address(factory), amount);

        factory.sell(1, amount);

        vm.stopPrank();

        PolyLaunchFactory.Project memory afterSell = factory.getProject(1);

        assertEq(afterSell.sold, 0);
    }

    function testCannotBuyMoreThanReserve() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        PolyLaunchFactory.Project memory project = factory.getProject(1);

        vm.expectRevert("Not enough tokens");

        vm.prank(user);
        factory.buy(1, project.reserveTokens + 1);
    }

    function testMultipleBuysMaintainAccounting() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        uint256 firstBuy = 10_000 ether;
        uint256 secondBuy = 20_000 ether;

        vm.prank(user);
        factory.buy(1, firstBuy);

        vm.prank(user);
        factory.buy(1, secondBuy);

        PolyLaunchFactory.Project memory project = factory.getProject(1);

        assertEq(project.sold, firstBuy + secondBuy);

        assertEq(project.reserveTokens, 800_000_000 ether - firstBuy - secondBuy);

        assertGt(project.reserveUSDC, 0);
    }

    function testMultipleBuySellAccounting() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        uint256 buyAmount = 20_000 ether;

        vm.prank(user);
        factory.buy(1, buyAmount);

        vm.startPrank(user);

        IERC20(factory.getProject(1).token).approve(address(factory), buyAmount);

        factory.sell(1, 10_000 ether);

        vm.stopPrank();

        PolyLaunchFactory.Project memory project = factory.getProject(1);

        assertEq(project.sold, 10_000 ether);

        assertEq(project.reserveTokens, 800_000_000 ether - 10_000 ether);

        assertGt(project.reserveUSDC, 0);
    }

    function testLPIsLockedFor365Days() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        uint256 amount = 400_000_000 ether;

        vm.prank(user);
        factory.buy(1, amount);

        (uint256 lockAmount, uint256 unlockTime, bool claimed) = factory.lpLocker().locks(address(pair));

        assertGt(lockAmount, 0);
        assertEq(unlockTime, block.timestamp + 365 days);
        assertFalse(claimed);
    }

    function testLPCannotUnlockEarly() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        vm.prank(user);
        factory.buy(1, 400_000_000 ether);

        LPLocker locker = factory.lpLocker();

        vm.expectRevert("Only factory");

        vm.prank(user);
        locker.unlock(address(pair));
    }

    function testLPRemainsProtectedAfter365Days() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        vm.prank(user);
        factory.buy(1, 400_000_000 ether);

        LPLocker locker = factory.lpLocker();

        vm.warp(block.timestamp + 365 days);

        vm.expectRevert("Only factory");

        vm.prank(user);
        locker.unlock(address(pair));
    }

    function testNonOwnerCannotUnlockLiquidity() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        vm.prank(user);
        factory.buy(1, 400_000_000 ether);

        LPLocker locker = factory.lpLocker();

        vm.warp(block.timestamp + 365 days);

        vm.expectRevert("Not owner");

        vm.prank(user);
        factory.unlockLiquidity(address(pair));
    }

    function testOwnerCanUnlockLiquidityAfter365Days() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        vm.prank(user);
        factory.buy(1, 400_000_000 ether);

        LPLocker locker = factory.lpLocker();

        vm.warp(block.timestamp + 365 days);

        factory.unlockLiquidity(address(pair));

        (uint256 lockAmount, uint256 unlockTime, bool claimed) = locker.locks(address(pair));

        assertGt(lockAmount, 0);
        assertEq(unlockTime, block.timestamp);
        assertTrue(claimed);
    }

    function testTransferOwnership() public {
        address newOwner = address(0x5);

        vm.prank(address(this));
        factory.transferOwnership(newOwner);

        assertEq(factory.owner(), newOwner);
    }

    function testCannotTransferOwnershipAsNonOwner() public {
        address newOwner = address(0x5);

        vm.prank(user);
        vm.expectRevert("Not owner");

        factory.transferOwnership(newOwner);
    }

    function testCannotTransferOwnershipToZeroAddress() public {
        vm.expectRevert("Invalid owner");

        factory.transferOwnership(address(0));
    }

    function testSetTreasury() public {
        address newTreasury = address(0x6);

        factory.setTreasury(newTreasury);

        assertEq(factory.treasury(), newTreasury);
    }

    function testCannotSetTreasuryAsNonOwner() public {
        address newTreasury = address(0x6);

        vm.prank(user);
        vm.expectRevert("Not owner");

        factory.setTreasury(newTreasury);
    }

    function testCannotSetTreasuryToZeroAddress() public {
        vm.expectRevert("Invalid treasury");

        factory.setTreasury(address(0));
    }

    function testCannotDeployWithZeroTreasury() public {
        vm.expectRevert("Invalid treasury");

        new PolyLaunchFactory(address(0), address(usdc), address(mockRouter), address(mockFactory));
    }

    function testCannotDeployWithZeroUSDC() public {
        vm.expectRevert("Invalid USDC");

        new PolyLaunchFactory(treasury, address(0), address(mockRouter), address(mockFactory));
    }

    function testCannotDeployWithZeroRouter() public {
        vm.expectRevert("Invalid router");

        new PolyLaunchFactory(treasury, address(usdc), address(0), address(mockFactory));
    }

    function testCannotDeployWithZeroFactory() public {
        vm.expectRevert("Invalid factory");

        new PolyLaunchFactory(treasury, address(usdc), address(mockRouter), address(0));
    }

function testCannotDeployWithMismatchedRouterFactory() public {
    MockFactory wrongFactory = new MockFactory(address(pair));
    MockRouter wrongRouter = new MockRouter(
        address(pair),
        address(wrongFactory)
    );

    vm.expectRevert("Router factory mismatch");

    new PolyLaunchFactory(
        treasury,
        address(usdc),
        address(wrongRouter),
        address(mockFactory)
    );
}
    function testReentrancyProtection() public {
        usdc.setAttack(address(factory), true);

        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        assertTrue(usdc.attackAttempted());
        assertFalse(usdc.attackSucceeded());

        // The reentrant createProject call must not create another project.
        assertEq(factory.totalProjects(), 1);
    }

    function testCurveRejectsFullSupplyPurchase() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        vm.expectRevert("Curve supply exceeded");

        vm.prank(user);
        factory.buy(1, 800_000_000 ether);
    }

    function testGraduationCreatesExactLPLock() public {
        vm.prank(user);

        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        uint256 amount = 400_000_000 ether;

        vm.prank(user);
        factory.buy(1, amount);

        address pairAddress = address(pair);

        (uint256 lockAmount, uint256 unlockTime, bool claimed) = factory.lpLocker().locks(pairAddress);

        uint256 actualLP = IERC20(pairAddress).balanceOf(address(factory.lpLocker()));

        assertGt(lockAmount, 0);
        assertEq(lockAmount, actualLP);
        assertEq(unlockTime, block.timestamp + 365 days);
        assertFalse(claimed);
    }

    function testGraduationRevertsWhenRouterFails() public {
        FailingRouter failingRouter = new FailingRouter(address(mockFactory));

        PolyLaunchFactory failingFactory =
            new PolyLaunchFactory(treasury, address(usdc), address(failingRouter), address(mockFactory));

        usdc.mint(address(this), 1_000_000e6);

        usdc.approve(address(failingFactory), type(uint256).max);

        failingFactory.createProject("Fail Token", "FAIL", "ipfs://test-metadata");

        vm.expectRevert("DEX liquidity failed");

        failingFactory.buy(1, 400_000_000 ether);

        PolyLaunchFactory.Project memory project = failingFactory.getProject(1);

        assertFalse(project.graduated);
        assertTrue(project.active);
    }

    function testGraduationRevertsWhenPairMissing() public {
        MissingPairFactory missingPairFactory = new MissingPairFactory();

MockRouter missingPairRouter =
    new MockRouter(address(pair), address(missingPairFactory));

PolyLaunchFactory failingFactory =
    new PolyLaunchFactory(
        treasury,
        address(usdc),
        address(missingPairRouter),
        address(missingPairFactory)
    );

        usdc.mint(address(this), 1_000_000e6);

        usdc.approve(address(failingFactory), type(uint256).max);

        failingFactory.createProject("Missing Pair", "PAIR", "ipfs://test-metadata");

        vm.expectRevert("Pair not found");

        failingFactory.buy(1, 400_000_000 ether);

        PolyLaunchFactory.Project memory project = failingFactory.getProject(1);

        assertFalse(project.graduated);
        assertTrue(project.active);
    }

    function testGraduationOvershoot() public {
    vm.prank(user);
    factory.createProject("Overshoot", "OVR", "ipfs://overshoot");

    vm.prank(user);
    vm.expectRevert("Purchase exceeds graduation target");
    factory.buy(1, 401_000_000 ether);

    PolyLaunchFactory.Project memory project = factory.getProject(1);

    assertFalse(project.graduated);
    assertTrue(project.active);
    assertEq(project.reserveUSDC, 0);
    assertEq(project.sold, 0);
}
    function testCurveBuyFeeAccounting() public {
        vm.prank(user);
        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        uint256 amount = 1_000_000 ether;

        uint256 curveCost = BondingCurve.getBuyPrice(0, amount);
        uint256 fee = (curveCost * factory.CURVE_FEE_BPS()) / factory.BPS();
        uint256 creatorFee = (curveCost * factory.CURVE_CREATOR_FEE_BPS()) / factory.BPS();
        uint256 protocolFee = fee - creatorFee;
        uint256 totalCost = curveCost + fee;

        uint256 userBefore = usdc.balanceOf(user);
        uint256 treasuryBefore = usdc.balanceOf(treasury);

        vm.prank(user);
        factory.buy(1, amount);

        PolyLaunchFactory.Project memory project = factory.getProject(1);

        assertEq(userBefore - usdc.balanceOf(user), totalCost);
        assertEq(project.reserveUSDC, curveCost);
        assertEq(factory.creatorFees(1), creatorFee);
        assertEq(usdc.balanceOf(treasury) - treasuryBefore, protocolFee);
    }

    function testBuyQuoteIncludesCurveFee() public {
        vm.prank(user);
        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        uint256 amount = 1_000_000 ether;

        uint256 curveCost = BondingCurve.getBuyPrice(0, amount);
        uint256 fee = (curveCost * factory.CURVE_FEE_BPS()) / factory.BPS();
        uint256 expected = curveCost + fee;

        uint256 quote = factory.getBuyQuote(1, amount);

        assertEq(quote, expected);
    }

    function testCurveSellFeeAccounting() public {
        vm.prank(user);
        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        uint256 buyAmount = 1000 ether;

        vm.prank(user);
        factory.buy(1, buyAmount);

        uint256 curvePayout = BondingCurve.getSellPrice(buyAmount, buyAmount);
        uint256 fee = (curvePayout * factory.CURVE_FEE_BPS()) / factory.BPS();
        uint256 creatorFee = (curvePayout * factory.CURVE_CREATOR_FEE_BPS()) / factory.BPS();
        uint256 protocolFee = fee - creatorFee;
        uint256 expectedNetPayout = curvePayout - fee;

        uint256 userBefore = usdc.balanceOf(user);
        uint256 treasuryBefore = usdc.balanceOf(treasury);
        uint256 creatorFeesBefore = factory.creatorFees(1);

        vm.startPrank(user);
        IERC20(factory.getProject(1).token).approve(address(factory), buyAmount);
        factory.sell(1, buyAmount);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user) - userBefore, expectedNetPayout);
        assertEq(usdc.balanceOf(treasury) - treasuryBefore, protocolFee);
        assertEq(
            factory.creatorFees(1),
            creatorFeesBefore + creatorFee
        );
    }

    function testSellQuoteReturnsNetPayout() public {
        vm.prank(user);
        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        uint256 amount = 1_000_000 ether;

        vm.prank(user);
        factory.buy(1, amount);

        uint256 curvePayout = BondingCurve.getSellPrice(amount, amount);
        uint256 fee = (curvePayout * factory.CURVE_FEE_BPS()) / factory.BPS();
        uint256 expected = curvePayout - fee;

        uint256 quote = factory.getSellQuote(1, amount);

        assertEq(quote, expected);
    }

    function testCreatorCanClaimFees() public {
        vm.prank(user);
        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        uint256 amount = 1_000_000 ether;

        vm.prank(user);
        factory.buy(1, amount);

        uint256 fees = factory.creatorFees(1);
        uint256 creatorBefore = usdc.balanceOf(user);

        vm.prank(user);
        factory.claimCreatorFees(1);

        assertEq(usdc.balanceOf(user) - creatorBefore, fees);
        assertEq(factory.creatorFees(1), 0);
    }

    function testNonCreatorCannotClaimFees() public {
        vm.prank(user);
        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        uint256 amount = 1_000_000 ether;

        vm.prank(user);
        factory.buy(1, amount);

        address attacker = address(0x99);

        vm.expectRevert("Not creator");
        vm.prank(attacker);
        factory.claimCreatorFees(1);
    }

    function testGraduationReserveExcludesTradingFees() public {
        vm.prank(user);
        factory.createProject("My Token", "MTK", "ipfs://test-metadata");

        // Keep this below graduation so the reserve remains in the factory.
        uint256 amount = 100_000 ether;

        uint256 curveCost = BondingCurve.getBuyPrice(0, amount);
        uint256 fee = (curveCost * factory.CURVE_FEE_BPS()) / factory.BPS();

        vm.prank(user);
        factory.buy(1, amount);

        PolyLaunchFactory.Project memory project = factory.getProject(1);

        assertEq(project.reserveUSDC, curveCost);
        assertEq(
            factory.creatorFees(1),
            (curveCost * factory.CURVE_CREATOR_FEE_BPS()) / factory.BPS()
        );

        assertEq(
            usdc.balanceOf(address(factory)),
            curveCost + factory.creatorFees(1)
        );
    }
   
}
