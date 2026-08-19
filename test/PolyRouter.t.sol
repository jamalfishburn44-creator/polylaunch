// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/dex/PolyRouter.sol";
import "../src/dex/PolyFactory.sol";
import "../src/WETH9.sol";
import "../src/MockPair.sol";

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

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(balanceOf[from] >= amount, "balance");
        require(
            from == msg.sender || allowance[from][msg.sender] >= amount,
            "allowance"
        );

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

    function testAddLiquidityCreatesPair() public {
        vm.startPrank(user);

        token.approve(address(router), 100 ether);

        weth.deposit{value: 100 ether}();
        weth.approve(address(router), 100 ether);

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

        vm.stopPrank();

        address pair = factory.getPair(address(token), address(weth));

        assertTrue(pair != address(0));
        assertTrue(
            IERC20Router(pair).balanceOf(user) > 0
        );
    }

    function testAddLiquidityReusesPair() public {
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

        address firstPair = factory.getPair(
            address(token),
            address(weth)
        );

        router.addLiquidity(
            address(token),
            address(weth),
            50 ether,
            50 ether,
            50 ether,
            50 ether,
            user,
            block.timestamp + 1 hours
        );

        address secondPair = factory.getPair(
            address(token),
            address(weth)
        );

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
            address(token),
            address(weth),
            100 ether,
            100 ether,
            100 ether,
            100 ether,
            user,
            block.timestamp - 1
        );

        vm.stopPrank();
    }
}
