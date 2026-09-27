// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
interface IPolyFactory {
    function router() external view returns (address);
}

interface IERC20Minimal {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract PolyPair is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;
    address public immutable token0;
    address public immutable token1;

    uint112 private reserve0;
    uint112 private reserve1;

    address public immutable factory;

    // Optional fee recipients.
    // Zero addresses mean this is a normal pair using the legacy behavior.
    address public immutable creator;
    address public immutable treasury;

    uint256 private constant FEE_BPS = 30;
    uint256 private constant CREATOR_FEE_BPS = 10;
    uint256 private constant TREASURY_FEE_BPS = 10;
    uint256 private constant BPS = 10_000;

    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory");
        _;
    }

    constructor(
        address _token0,
        address _token1,
        address _creator,
        address _treasury
    ) ERC20("PolyLaunch LP", "PLP") {
        require(_token0 != address(0), "Zero token0");
        require(_token1 != address(0), "Zero token1");
        require(_token0 != _token1, "Identical tokens");

        token0 = _token0;
        token1 = _token1;
        factory = msg.sender;

        creator = _creator;
        treasury = _treasury;
    }

    function getReserves()
        external
        view
        returns (uint112, uint112)
    {
        return (reserve0, reserve1);
    }

    function mint(address to)
        external
        onlyFactory
        returns (uint256 liquidity)
    {
        uint256 balance0 =
            IERC20Minimal(token0).balanceOf(address(this));

        uint256 balance1 =
            IERC20Minimal(token1).balanceOf(address(this));

        uint256 amount0 = balance0 - reserve0;
        uint256 amount1 = balance1 - reserve1;

        liquidity = amount0 < amount1
            ? amount0
            : amount1;

        require(
            liquidity > 0,
            "Insufficient liquidity"
        );

        _mint(to, liquidity);

        require(balance0 <= type(uint112).max, "Reserve overflow");
        require(balance1 <= type(uint112).max, "Reserve overflow");

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
    }

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    ) external nonReentrant {
        require(
            msg.sender == IPolyFactory(factory).router(),
            "Only router"
        );

        require(
            amount0Out > 0 || amount1Out > 0,
            "Insufficient output"
        );

        require(
            amount0Out < reserve0 &&
            amount1Out < reserve1,
            "Insufficient liquidity"
        );

        require(
            to != address(0) &&
            to != token0 &&
            to != token1,
            "Invalid recipient"
        );

        if (amount0Out > 0) {
            IERC20(token0).safeTransfer(to, amount0Out);
        }

        if (amount1Out > 0) {
            IERC20(token1).safeTransfer(to, amount1Out);
        }

        uint256 balance0 =
            IERC20Minimal(token0).balanceOf(address(this));

        uint256 balance1 =
            IERC20Minimal(token1).balanceOf(address(this));

        uint256 amount0In;
        uint256 amount1In;

        uint256 expectedBalance0 =
            uint256(reserve0) - amount0Out;

        uint256 expectedBalance1 =
            uint256(reserve1) - amount1Out;

        if (balance0 > expectedBalance0) {
            amount0In = balance0 - expectedBalance0;
        }

        if (balance1 > expectedBalance1) {
            amount1In = balance1 - expectedBalance1;
        }

        require(
            amount0In > 0 || amount1In > 0,
            "Insufficient input"
        );

        // PolyLaunch pairs distribute 0.20% of input externally:
        // 0.10% creator + 0.10% treasury.
        // The remaining 0.10% stays in the pair as the LP fee.
        if (creator != address(0) && treasury != address(0)) {
            if (amount0In > 0) {
                uint256 creatorFee =
                    (amount0In * CREATOR_FEE_BPS) / BPS;

                uint256 treasuryFee =
                    (amount0In * TREASURY_FEE_BPS) / BPS;

                if (creatorFee > 0) {
                    IERC20(token0).safeTransfer(creator, creatorFee);
                }

                if (treasuryFee > 0) {
                    IERC20(token0).safeTransfer(treasury, treasuryFee);
                }
            }

            if (amount1In > 0) {
                uint256 creatorFee =
                    (amount1In * CREATOR_FEE_BPS) / BPS;

                uint256 treasuryFee =
                    (amount1In * TREASURY_FEE_BPS) / BPS;

                if (creatorFee > 0) {
                    IERC20(token1).safeTransfer(creator, creatorFee);
                }

                if (treasuryFee > 0) {
                    IERC20(token1).safeTransfer(treasury, treasuryFee);
                }
            }

            balance0 =
                IERC20Minimal(token0).balanceOf(address(this));

            balance1 =
                IERC20Minimal(token1).balanceOf(address(this));
        }

        // The full 0.30% fee is charged to the trader.
        // After the 0.20% external distribution, the remaining
        // 0.10% stays in the pair for LPs.
        // 0.30% total trader fee:
// - 0.10% creator fee (already transferred out)
// - 0.10% treasury fee (already transferred out)
// - 0.10% remains in the pair as LP fee.
//
// Because the 0.20% external fees have already left the pair,
// only the remaining 0.10% LP fee is reflected in the invariant.
uint256 lpFeeBps = FEE_BPS - CREATOR_FEE_BPS - TREASURY_FEE_BPS;

uint256 balance0Adjusted =
    balance0 * BPS - amount0In * lpFeeBps;

uint256 balance1Adjusted =
    balance1 * BPS - amount1In * lpFeeBps;

        require(
            balance0Adjusted * balance1Adjusted >=
                uint256(reserve0) *
                uint256(reserve1) *
                10_000 *
                10_000,
            "K invariant"
        );

        require(
            balance0 <= type(uint112).max,
            "Reserve overflow"
        );

        require(
            balance1 <= type(uint112).max,
            "Reserve overflow"
        );

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
    }
}
