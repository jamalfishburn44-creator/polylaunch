// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./MockPair.sol";

contract MockRouter {
    MockPair public immutable lpToken;
    address public immutable dexFactory;

    constructor(address _lpToken, address _factory) {
        lpToken = MockPair(_lpToken);
        dexFactory = _factory;
    }

    function factory() external view returns (address) {
        return dexFactory;
    }

    function WETH() external pure returns (address) {
        return address(0);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256,
        uint256,
        address to,
        uint256
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(tokenA != address(0), "Invalid tokenA");
        require(tokenB != address(0), "Invalid tokenB");

        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountADesired), "Token transfer failed");

        require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountBDesired), "USDC transfer failed");

        amountA = amountADesired;
        amountB = amountBDesired;

        liquidity = amountADesired < amountBDesired ? amountADesired : amountBDesired;

        lpToken.mint(to, liquidity);
    }

function addLiquidityWithFees(
    address tokenA,
    address tokenB,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256,
    uint256,
    address to,
    uint256,
    address,
    address
) external returns (
    uint256 amountA,
    uint256 amountB,
    uint256 liquidity
) {
    require(tokenA != address(0), "Invalid tokenA");
    require(tokenB != address(0), "Invalid tokenB");

    require(
        IERC20(tokenA).transferFrom(
            msg.sender,
            address(this),
            amountADesired
        ),
        "Token transfer failed"
    );

    require(
        IERC20(tokenB).transferFrom(
            msg.sender,
            address(this),
            amountBDesired
        ),
        "USDC transfer failed"
    );

    amountA = amountADesired;
    amountB = amountBDesired;

    liquidity =
        amountADesired < amountBDesired
            ? amountADesired
            : amountBDesired;

    lpToken.mint(to, liquidity);
}
}
