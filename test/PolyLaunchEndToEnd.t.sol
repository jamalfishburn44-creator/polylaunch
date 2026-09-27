// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../src/PolyLaunchFactory.sol";
import "../src/PolyLaunchToken.sol";
import "../src/dex/PolyFactory.sol";
import "../src/dex/PolyRouter.sol";
import "../src/dex/PolyPair.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PolyLaunchEndToEndTest is Test {
    PolyFactory public dexFactory;
    PolyRouter public router;
    PolyLaunchFactory public launchFactory;
    MockUSDC public usdc;

    address public treasury = address(0x1000);
    address public user = address(0x2000);

    function setUp() public {
        usdc = new MockUSDC();

        dexFactory = new PolyFactory(address(this));

        router = new PolyRouter(
            address(dexFactory),
            address(0xBEEF)
        );

        dexFactory.setRouter(address(router));

        launchFactory = new PolyLaunchFactory(
            treasury,
            address(usdc),
            address(router),
            address(dexFactory)
        );

        usdc.mint(user, 1000 * 1e6);
    }

    function testFullLaunchToGraduationAndDEXSwap() public {
        vm.startPrank(user);

        usdc.approve(
            address(launchFactory),
            type(uint256).max
        );

        launchFactory.createProject(
            "EndToEnd",
            "E2E",
            
            "ipfs://test"
        );

        PolyLaunchFactory.Project memory before =
            launchFactory.getProject(1);

        assertTrue(before.active);
        assertFalse(before.graduated);
        assertEq(before.reserveUSDC, 0);
        assertEq(before.reserveTokens, 800_000_000 ether);
        assertEq(before.liquidityTokens, 200_000_000 ether);

        launchFactory.buy(
            1,
            400_000_000 ether
        );

        PolyLaunchFactory.Project memory project =
            launchFactory.getProject(1);

        assertTrue(project.graduated);
        assertFalse(project.active);

        assertGe(
            project.reserveUSDC,
            launchFactory.GRADUATION_USDC()
        );

        assertEq(
            project.sold,
            400_000_000 ether
        );

        // Verify DEX pair exists.
        address pair = dexFactory.getPair(
            project.token,
            address(usdc)
        );

        assertTrue(pair != address(0));

        // Verify LP was locked.
        LPLocker locker = launchFactory.lpLocker();

        (
            uint256 lockedAmount,
            uint256 unlockTime,
            bool claimed
        ) = locker.locks(pair);

        assertGt(lockedAmount, 0);
        assertEq(
            unlockTime,
            block.timestamp + 365 days
        );
        assertFalse(claimed);

        vm.stopPrank();

vm.startPrank(user);

deal(
    project.token,
    user,
    1_000 ether
);

IERC20(project.token).approve(
    address(router),
    1_000 ether
);

uint256 usdcBefore = usdc.balanceOf(user);

(uint112 reserve0, uint112 reserve1) =
    PolyPair(pair).getReserves();

address token0 = PolyPair(pair).token0();

uint256 reserveIn;
uint256 reserveOut;

if (project.token == token0) {
    reserveIn = reserve0;
    reserveOut = reserve1;
} else {
    reserveIn = reserve1;
    reserveOut = reserve0;
}

uint256 expectedOut = router.getAmountOut(
    1_000 ether,
    reserveIn,
    reserveOut
);

assertGt(expectedOut, 0);

router.swapExactTokensForTokens(
    project.token,
    address(usdc),
    1_000 ether,
    expectedOut,
    user,
    block.timestamp + 1 hours
);

uint256 usdcAfter = usdc.balanceOf(user);

assertGt(usdcAfter, usdcBefore);

vm.expectRevert("Project inactive");

launchFactory.buy(
    1,
    1
);

vm.stopPrank();
    }

function testPostGraduationFeeSplit() public {
    address creator = address(0x3000);
    address trader = address(0x4000);

    // Fund creator and trader.
    usdc.mint(creator, 1000 * 1e6);
    usdc.mint(trader, 1000 * 1e6);

    // Creator launches the token.
    vm.startPrank(creator);

    usdc.approve(
        address(launchFactory),
        type(uint256).max
    );

    launchFactory.createProject(
    "Fee Test",
    "FEE",
    "ipfs://fee-test"
);

    // Buy enough on the curve to graduate.
    launchFactory.buy(
        1,
        400_000_000 ether
    );

    vm.stopPrank();

    PolyLaunchFactory.Project memory project =
        launchFactory.getProject(1);

    assertTrue(project.graduated);

    address pair = dexFactory.getPair(
        project.token,
        address(usdc)
    );

    assertTrue(pair != address(0));

    // Give the trader tokens to sell into the DEX.
    deal(
        project.token,
        trader,
        1_000 ether
    );

    uint256 creatorBefore =
        IERC20(project.token).balanceOf(creator);

    uint256 treasuryBefore =
        IERC20(project.token).balanceOf(treasury);

    uint256 pairBefore =
        IERC20(project.token).balanceOf(pair);

    // 1,000 tokens * 0.10% = 1 token.
    uint256 expectedFee = 1 ether;

    vm.startPrank(trader);

    IERC20(project.token).approve(
        address(router),
        1_000 ether
    );

    (
        uint112 reserve0,
        uint112 reserve1
    ) = PolyPair(pair).getReserves();

    address token0 = PolyPair(pair).token0();

    uint256 reserveIn;
    uint256 reserveOut;

    if (project.token == token0) {
        reserveIn = reserve0;
        reserveOut = reserve1;
    } else {
        reserveIn = reserve1;
        reserveOut = reserve0;
    }

    uint256 expectedOut = router.getAmountOut(
        1_000 ether,
        reserveIn,
        reserveOut
    );

    router.swapExactTokensForTokens(
        project.token,
        address(usdc),
        1_000 ether,
        expectedOut,
        trader,
        block.timestamp + 1 hours
    );

    vm.stopPrank();

    uint256 creatorAfter =
        IERC20(project.token).balanceOf(creator);

    uint256 treasuryAfter =
        IERC20(project.token).balanceOf(treasury);

    uint256 pairAfter =
        IERC20(project.token).balanceOf(pair);

    // 0.10% creator fee.
    assertEq(
        creatorAfter - creatorBefore,
        expectedFee
    );

    // 0.10% treasury fee.
    assertEq(
        treasuryAfter - treasuryBefore,
        expectedFee
    );

    // 1,000 tokens enter the pair.
// 1 token goes to the creator.
// 1 token goes to the treasury.
// The remaining 998 tokens stay in the pair.
uint256 expectedPairIncrease =
    1_000 ether - (expectedFee * 2);

assertEq(
    pairAfter - pairBefore,
    expectedPairIncrease
);
}
}
