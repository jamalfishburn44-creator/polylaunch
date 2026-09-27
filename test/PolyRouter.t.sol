// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/dex/PolyRouter.sol";
import "../src/dex/PolyFactory.sol";
import "../src/WETH9.sol";
import "../src/MockPair.sol";
import "../src/dex/PolyPair.sol";
import "../src/ReentrantToken.sol";

contract TestToken {
    string public name;
    string public symbol;
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "balance");
        require(from == msg.sender || allowance[from][msg.sender] >= amount, "allowance");

        if (from != msg.sender) {
            allowance[from][msg.sender] -= amount;
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "balance");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        return true;
    }
}

contract PolyRouterTest is Test {
    PolyFactory factory;
    PolyRouter router;
    WETH9 weth;
    TestToken token;

    address user = address(1);

function setUp() public {
    factory = new PolyFactory(address(this));
    weth = new WETH9();
    router = new PolyRouter(address(factory), address(weth));
    factory.setRouter(address(router));

    token = new TestToken("Test Token", "TEST");
    token.mint(user, 1_000 ether);

    vm.deal(user, 1_000 ether);
}

    function testDeployment() public {
    assertEq(router.factory(), address(factory));
    assertEq(router.WETH(), address(weth));
}

function testCreatePairRejectsNonRouter() public {
    TestToken tokenA = new TestToken("Token A", "A");
    TestToken tokenB = new TestToken("Token B", "B");

    vm.prank(user);
    vm.expectRevert();
    factory.createPair(address(tokenA), address(tokenB));
}

    function testAddLiquidityCreatesPair() public {
        vm.startPrank(user);

        token.approve(address(router), 100 ether);

        weth.deposit{value: 100 ether}();
        weth.approve(address(router), 100 ether);

        router.addLiquidity(
            address(token), address(weth), 100 ether, 100 ether, 100 ether, 100 ether, user, block.timestamp + 1 hours
        );

        vm.stopPrank();

        address pair = factory.getPair(address(token), address(weth));

        assertTrue(pair != address(0));
        assertTrue(IERC20Router(pair).balanceOf(user) > 0);
    }

    function testAddLiquidityReusesPair() public {
        vm.startPrank(user);

        token.approve(address(router), type(uint256).max);

        weth.deposit{value: 200 ether}();
        weth.approve(address(router), type(uint256).max);

        router.addLiquidity(
            address(token), address(weth), 100 ether, 100 ether, 100 ether, 100 ether, user, block.timestamp + 1 hours
        );

        address firstPair = factory.getPair(address(token), address(weth));

        router.addLiquidity(
            address(token), address(weth), 50 ether, 50 ether, 50 ether, 50 ether, user, block.timestamp + 1 hours
        );

        address secondPair = factory.getPair(address(token), address(weth));

        vm.stopPrank();

        assertEq(firstPair, secondPair);
        assertEq(factory.allPairsLength(), 1);
    }

    function testExpiredDeadlineReverts() public {
        vm.startPrank(user);

        token.approve(address(router), 100 ether);

        weth.deposit{value: 100 ether}();
        weth.approve(address(router), 100 ether);

        vm.expectRevert("Expired");

        router.addLiquidity(
            address(token), address(weth), 100 ether, 100 ether, 100 ether, 100 ether, user, block.timestamp - 1
        );

        vm.stopPrank();
    }

        function testSwapTokenForWeth() public {
        vm.startPrank(user);

        token.approve(
            address(router),
            type(uint256).max
        );

        weth.deposit{value: 100 ether}();
        weth.approve(
            address(router),
            type(uint256).max
        );

        router.addLiquidity(
            address(token),
            address(weth),
            100 ether,
            100 ether,
            100 ether,
            100 ether,
            user,
            block.timestamp + 1 hours
        );

        address pair =
            factory.getPair(
                address(token),
                address(weth)
            );

        uint256 wethBefore =
            weth.balanceOf(user);

        router.swapExactTokensForTokens(
            address(token),
            address(weth),
            10 ether,
            9 ether,
            user,
            block.timestamp + 1 hours
        );

        uint256 wethAfter =
            weth.balanceOf(user);

        vm.stopPrank();

        assertGt(
            wethAfter,
            wethBefore
        );

        assertEq(
            wethAfter - wethBefore,
            9066108938801491315
        );

        assertTrue(pair != address(0));
    }

    function testSwapWethForToken() public {
        vm.startPrank(user);

        token.approve(
            address(router),
            type(uint256).max
        );

        weth.deposit{value: 110 ether}();
        weth.approve(
            address(router),
            type(uint256).max
        );

        router.addLiquidity(
            address(token),
            address(weth),
            100 ether,
            100 ether,
            100 ether,
            100 ether,
            user,
            block.timestamp + 1 hours
        );

        uint256 tokenBefore =
            token.balanceOf(user);

        router.swapExactTokensForTokens(
            address(weth),
            address(token),
            10 ether,
            9 ether,
            user,
            block.timestamp + 1 hours
        );

        uint256 tokenAfter =
            token.balanceOf(user);

        vm.stopPrank();

        assertGt(
            tokenAfter,
            tokenBefore
        );

        assertEq(
            tokenAfter - tokenBefore,
            9066108938801491315
        );
    }

    function testSwapRejectsInsufficientOutput() public {
        vm.startPrank(user);

        token.approve(
            address(router),
            type(uint256).max
        );

        weth.deposit{value: 100 ether}();
        weth.approve(
            address(router),
            type(uint256).max
        );

        router.addLiquidity(
            address(token),
            address(weth),
            100 ether,
            100 ether,
            100 ether,
            100 ether,
            user,
            block.timestamp + 1 hours
        );

        vm.expectRevert(
            "Insufficient output"
        );

        router.swapExactTokensForTokens(
            address(token),
            address(weth),
            10 ether,
            10 ether,
            user,
            block.timestamp + 1 hours
        );

        vm.stopPrank();
    }

function testPairSwapRejectsUnauthorizedCaller() public {
    vm.startPrank(user);

    token.approve(address(router), type(uint256).max);

    weth.deposit{value: 100 ether}();
    weth.approve(address(router), type(uint256).max);

    router.addLiquidity(
        address(token),
        address(weth),
        100 ether,
        100 ether,
        100 ether,
        100 ether,
        user,
        block.timestamp + 1 hours
    );

    address pair = factory.getPair(address(token), address(weth));

    vm.stopPrank();

    vm.prank(address(0xBEEF));
    vm.expectRevert("Only router");

    PolyPair(pair).swap(
        1 ether,
        0,
        address(0xBEEF)
    );
}

function testSwapRejectsZeroOutput() public {
    vm.startPrank(user);

    token.approve(address(router), type(uint256).max);

    weth.deposit{value: 100 ether}();
    weth.approve(address(router), type(uint256).max);

    router.addLiquidity(
        address(token),
        address(weth),
        100 ether,
        100 ether,
        100 ether,
        100 ether,
        user,
        block.timestamp + 1 hours
    );

    vm.expectRevert("Insufficient output");

    router.swapExactTokensForTokens(
        address(token),
        address(weth),
        1,
        type(uint256).max,
        user,
        block.timestamp + 1 hours
    );

    vm.stopPrank();
}

function testSwapRejectsExcessiveOutput() public {
    vm.startPrank(user);

    token.approve(address(router), type(uint256).max);

    weth.deposit{value: 100 ether}();
    weth.approve(address(router), type(uint256).max);

    router.addLiquidity(
        address(token),
        address(weth),
        100 ether,
        100 ether,
        100 ether,
        100 ether,
        user,
        block.timestamp + 1 hours
    );

    vm.expectRevert("Insufficient output");

    router.swapExactTokensForTokens(
        address(token),
        address(weth),
        10 ether,
        100 ether,
        user,
        block.timestamp + 1 hours
    );

    vm.stopPrank();
}


    function testRepeatedSwapsMaintainReservesAndInvariant() public {
        vm.startPrank(user);

        token.approve(address(router), type(uint256).max);

        weth.deposit{value: 200 ether}();
        weth.approve(address(router), type(uint256).max);

        router.addLiquidity(
            address(token),
            address(weth),
            100 ether,
            100 ether,
            100 ether,
            100 ether,
            user,
            block.timestamp + 1 hours
        );

        address pair = factory.getPair(
            address(token),
            address(weth)
        );

        (uint112 reserve0Before, uint112 reserve1Before) =
            PolyPair(pair).getReserves();

        uint256 kBefore =
            uint256(reserve0Before) *
            uint256(reserve1Before);

        router.swapExactTokensForTokens(
            address(token),
            address(weth),
            5 ether,
            0,
            user,
            block.timestamp + 1 hours
        );

        router.swapExactTokensForTokens(
            address(weth),
            address(token),
            3 ether,
            0,
            user,
            block.timestamp + 1 hours
        );

        router.swapExactTokensForTokens(
            address(token),
            address(weth),
            7 ether,
            0,
            user,
            block.timestamp + 1 hours
        );

        router.swapExactTokensForTokens(
            address(weth),
            address(token),
            4 ether,
            0,
            user,
            block.timestamp + 1 hours
        );

        vm.stopPrank();

        (uint112 reserve0After, uint112 reserve1After) =
            PolyPair(pair).getReserves();

        uint256 kAfter =
            uint256(reserve0After) *
            uint256(reserve1After);

        assertGt(reserve0After, 0);
        assertGt(reserve1After, 0);

        assertGe(
            kAfter,
            kBefore,
            "Invariant decreased"
        );

        assertEq(
            IERC20Router(PolyPair(pair).token0()).balanceOf(pair),
            reserve0After,
            "Token0 reserve mismatch"
        );

        assertEq(
            IERC20Router(PolyPair(pair).token1()).balanceOf(pair),
            reserve1After,
            "Token1 reserve mismatch"
        );
    }

    function testPairBlocksRealReentrancyAttack() public {
        ReentrantToken malicious = new ReentrantToken();
        TestToken other = new TestToken("Other Token", "OTHER");

        malicious.mint(user, 1_000 ether);
        other.mint(user, 1_000 ether);

        vm.startPrank(user);

        malicious.approve(address(router), type(uint256).max);
        other.approve(address(router), type(uint256).max);

        router.addLiquidity(
            address(malicious),
            address(other),
            100 ether,
            100 ether,
            100 ether,
            100 ether,
            user,
            block.timestamp + 1 hours
        );

        address pair = factory.getPair(
            address(malicious),
            address(other)
        );

        malicious.configureAttack(pair);

        uint256 maliciousBefore = malicious.balanceOf(user);

        router.swapExactTokensForTokens(
            address(other),
            address(malicious),
            1 ether,
            0,
            user,
            block.timestamp + 1 hours
        );

        vm.stopPrank();

        assertTrue(
            malicious.attackAttempted(),
            "Reentrancy attack was not attempted"
        );

        assertGt(
            malicious.balanceOf(user),
            maliciousBefore,
            "Outer swap did not complete"
        );
    }

}  
            
    
