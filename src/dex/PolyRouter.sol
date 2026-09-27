// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./PolyFactory.sol";
import "./PolyPair.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface IERC20Router {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function transfer(
        address to,
        uint256 amount
    ) external returns (bool);

    function balanceOf(
        address account
    ) external view returns (uint256);

    function approve(
        address spender,
        uint256 amount
    ) external returns (bool);
}

contract PolyRouter {
    using SafeERC20 for IERC20;
    address public immutable factory;
    address public immutable WETH;

    // Generic / legacy pair fee: 0.30% retained by LPs.
    uint256 private constant FEE_NUMERATOR = 997;
    uint256 private constant FEE_DENOMINATOR = 1000;

    // PolyLaunch pairs still charge 0.30% total.
    // The pair distributes 0.20% externally and retains 0.10%.
    uint256 private constant POLY_FEE_NUMERATOR = 997;
    uint256 private constant POLY_FEE_DENOMINATOR = 1000;

    constructor(
        address _factory,
        address _WETH
    ) {
        require(_factory != address(0), "Zero factory");
        require(_WETH != address(0), "Zero WETH");

        factory = _factory;
        WETH = _WETH;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        require(block.timestamp <= deadline, "Expired");
        require(to != address(0), "Zero recipient");

        address pair =
            PolyFactory(factory).getPair(tokenA, tokenB);

        if (pair == address(0)) {
            pair = PolyFactory(factory).createPair(
                tokenA,
                tokenB
            );
        }

        amountA = amountADesired;
        amountB = amountBDesired;

        require(
            amountA >= amountAMin,
            "Insufficient A"
        );

        require(
            amountB >= amountBMin,
            "Insufficient B"
        );

        IERC20(tokenA).safeTransferFrom(
    msg.sender,
    pair,
    amountA
);

        IERC20(tokenB).safeTransferFrom(
    msg.sender,
    pair,
    amountB
);

        liquidity = PolyFactory(factory).mintLiquidity(
            pair,
            to
        );
    }

    function addLiquidityWithFees(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        address creator,
        address treasury
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        require(block.timestamp <= deadline, "Expired");
        require(to != address(0), "Zero recipient");
        require(creator != address(0), "Zero creator");
        require(treasury != address(0), "Zero treasury");

        address pair =
            PolyFactory(factory).getPair(tokenA, tokenB);

        require(
            pair == address(0),
            "Pair exists"
        );

        pair = PolyFactory(factory).createPairWithFees(
            tokenA,
            tokenB,
            creator,
            treasury
        );

        amountA = amountADesired;
        amountB = amountBDesired;

        require(
            amountA >= amountAMin,
            "Insufficient A"
        );

        require(
            amountB >= amountBMin,
            "Insufficient B"
        );

        IERC20(tokenA).safeTransferFrom(
    msg.sender,
    pair,
    amountA
);

        IERC20(tokenB).safeTransferFrom(
    msg.sender,
    pair,
    amountB
);

        liquidity = PolyFactory(factory).mintLiquidity(
            pair,
            to
        );
    }

    function getPair(
        address tokenA,
        address tokenB
    )
        external
        view
        returns (address)
    {
        return PolyFactory(factory).getPair(
            tokenA,
            tokenB
        );
    }

    // Generic 0.30% quote retained for compatibility.
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    )
        public
        pure
        returns (uint256 amountOut)
    {
        return _getAmountOut(
            amountIn,
            reserveIn,
            reserveOut,
            FEE_NUMERATOR,
            FEE_DENOMINATOR
        );
    }

    function getAmountOutForPair(
        address pair,
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    )
        public
        view
        returns (uint256 amountOut)
    {
        require(pair != address(0), "Zero pair");

        if (PolyPair(pair).creator() != address(0)) {
            return _getAmountOut(
                amountIn,
                reserveIn,
                reserveOut,
                POLY_FEE_NUMERATOR,
                POLY_FEE_DENOMINATOR
            );
        }

        return _getAmountOut(
            amountIn,
            reserveIn,
            reserveOut,
            FEE_NUMERATOR,
            FEE_DENOMINATOR
        );
    }

    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeNumerator,
        uint256 feeDenominator
    )
        internal
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "Zero input");

        require(
            reserveIn > 0 && reserveOut > 0,
            "Insufficient liquidity"
        );

        uint256 amountInWithFee =
            amountIn * feeNumerator;

        amountOut =
            (amountInWithFee * reserveOut) /
            (
                reserveIn * feeDenominator +
                amountInWithFee
            );

        require(
            amountOut > 0,
            "Insufficient output"
        );
    }

    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    )
        external
        returns (uint256 amountOut)
    {
        require(
            block.timestamp <= deadline,
            "Expired"
        );

        require(
            tokenIn != address(0) &&
            tokenOut != address(0),
            "Zero token"
        );

        require(
            tokenIn != tokenOut,
            "Identical tokens"
        );

        require(
            to != address(0),
            "Zero recipient"
        );

        address pair =
            PolyFactory(factory).getPair(
                tokenIn,
                tokenOut
            );

        require(
            pair != address(0),
            "Pair does not exist"
        );

        (
            uint112 reserve0,
            uint112 reserve1
        ) = PolyPair(pair).getReserves();

        address token0 =
            PolyPair(pair).token0();

        uint256 reserveIn;
        uint256 reserveOut;

        if (tokenIn == token0) {
            reserveIn = reserve0;
            reserveOut = reserve1;
        } else {
            require(
                tokenIn == PolyPair(pair).token1(),
                "Invalid token"
            );

            reserveIn = reserve1;
            reserveOut = reserve0;
        }

        amountOut = getAmountOutForPair(
            pair,
            amountIn,
            reserveIn,
            reserveOut
        );

        require(
            amountOut >= amountOutMin,
            "Insufficient output"
        );

        IERC20(tokenIn).safeTransferFrom(
    msg.sender,
    pair,
    amountIn
);

        uint256 amount0Out;
        uint256 amount1Out;

        if (tokenIn == token0) {
            amount1Out = amountOut;
        } else {
            amount0Out = amountOut;
        }

        PolyPair(pair).swap(
            amount0Out,
            amount1Out,
            to
        );
    }
}
