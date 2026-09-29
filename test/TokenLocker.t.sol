// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {TokenLocker} from "../src/TokenLocker.sol";

contract TokenLockerTestToken is ERC20 {
    constructor() ERC20("Locker Test Token", "LTT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TokenLockerCaller {
    TokenLocker public immutable locker;

    constructor() {
        locker = new TokenLocker();
    }

    function lock(address token, uint256 amount) external {
        IERC20(token).approve(address(locker), amount);
        locker.lock(token, amount);
    }
}

contract TokenLockerTest is Test {
    TokenLocker public locker;
    TokenLockerTestToken public token;
    TokenLockerCaller public factory;

    uint256 constant LOCK_AMOUNT = 400_000_000 ether;

    function setUp() public {
        factory = new TokenLockerCaller();
        locker = factory.locker();

        token = new TokenLockerTestToken();
        token.mint(address(factory), LOCK_AMOUNT);
    }

    function testOnlyFactoryCanLock() public {
        vm.expectRevert("Only factory");

        locker.lock(address(token), LOCK_AMOUNT);
    }

    function testRejectsZeroToken() public {
        vm.prank(address(factory));

        vm.expectRevert("Invalid token");
        locker.lock(address(0), LOCK_AMOUNT);
    }

    function testRejectsZeroAmount() public {
        vm.expectRevert("Zero amount");

        factory.lock(address(token), 0);
    }

    function testLocksExactAmount() public {
        factory.lock(address(token), LOCK_AMOUNT);

        assertEq(
            token.balanceOf(address(locker)),
            LOCK_AMOUNT
        );

        (uint256 amount, bool locked) =
            locker.locks(address(token));

        assertEq(amount, LOCK_AMOUNT);
        assertTrue(locked);
    }

    function testBalanceOfReturnsLockedAmount() public {
        factory.lock(address(token), LOCK_AMOUNT);

        assertEq(
            locker.balanceOf(address(token)),
            LOCK_AMOUNT
        );
    }

    function testCannotLockSameTokenTwice() public {
        factory.lock(address(token), LOCK_AMOUNT);

        vm.expectRevert("Already locked");

        factory.lock(address(token), 1);
    }

    function testLockedTokensRemainAfterTimePasses() public {
        factory.lock(address(token), LOCK_AMOUNT);

        vm.warp(block.timestamp + 10_000_000 days);

        assertEq(
            token.balanceOf(address(locker)),
            LOCK_AMOUNT
        );

        (uint256 amount, bool locked) =
            locker.locks(address(token));

        assertEq(amount, LOCK_AMOUNT);
        assertTrue(locked);
    }

    function testFactoryHasNoTokensAfterLock() public {
        factory.lock(address(token), LOCK_AMOUNT);

        assertEq(
            token.balanceOf(address(factory)),
            0
        );
    }
}
