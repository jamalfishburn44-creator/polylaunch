// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../src/PolyLaunchFactory.sol";
import "../src/MockUSDC.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract PolyLaunchFactoryTest is Test {
    PolyLaunchFactory factory;
    MockUSDC usdc;

    address treasury = address(0x1);
    address user = address(0x2);
    address router = address(0x3);
    address dexFactory = address(0x4);

    function setUp() public {
        usdc = new MockUSDC();

        factory = new PolyLaunchFactory(
            treasury,
            address(usdc),
            router,
            dexFactory
        );

        usdc.mint(user, 1_000_000e6);

        vm.prank(user);
        usdc.approve(address(factory), type(uint256).max);
    }

    function testDeployment() public view {
        assertTrue(address(factory) != address(0));
    }

    function testLaunchFeeConstant() public view {
        assertEq(factory.LAUNCH_FEE(), 4e6);
    }

    function testGraduationConstant() public view {
        assertEq(factory.GRADUATION_USDC(), 100000e6);
    }

    function testCreateProject() public {
        vm.prank(user);

        factory.createProject(
            "My Token",
            "MTK",
            1_000_000 ether
        );

        assertEq(factory.totalProjects(), 1);
    }

function testBuyTokens() public {
    vm.prank(user);

    factory.createProject(
        "My Token",
        "MTK",
        1_000_000 ether
    );

    uint256 buyAmount = 1000;

    vm.prank(user);

    factory.buy(
        1,
        buyAmount
    );

    assertEq(factory.totalProjects(), 1);

    PolyLaunchFactory.Project memory project = factory.getProject(1);

    assertEq(project.sold, buyAmount);
}

function testSellTokens() public {
    vm.prank(user);

    factory.createProject(
        "My Token",
        "MTK",
        1_000_000 ether
    );

    uint256 buyAmount = 1000;

    vm.prank(user);
    factory.buy(1, buyAmount);

    vm.startPrank(user);

    IERC20(factory.getProject(1).token).approve(
        address(factory),
        buyAmount
    );

    factory.sell(1, buyAmount);

    vm.stopPrank();

    PolyLaunchFactory.Project memory project =
        factory.getProject(1);

    assertEq(project.sold, 0);
}
}

    
