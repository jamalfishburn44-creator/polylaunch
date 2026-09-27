// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library BondingCurve {
    uint256 internal constant ONE = 1e6;

    // PolyLaunch V1 fixed token economics:
    // 1,000,000,000 total tokens
    // 800,000,000 tokens on the bonding curve
    // 200,000,000 tokens reserved for graduation liquidity
    uint256 internal constant VIRTUAL_USDC = 150 * ONE;
    uint256 internal constant VIRTUAL_TOKENS = 800_000_000 * 1e18;

    function getBuyPrice(
        uint256 sold,
        uint256 amount
    ) internal pure returns (uint256) {
        require(amount > 0, "Invalid amount");

        uint256 currentVirtualTokens =
            VIRTUAL_TOKENS - sold;

        require(
            amount < currentVirtualTokens,
            "Curve supply exceeded"
        );

        uint256 newVirtualTokens =
            currentVirtualTokens - amount;

        uint256 currentUSDC =
            (VIRTUAL_USDC * VIRTUAL_TOKENS) /
            currentVirtualTokens;

        uint256 newUSDC =
            (VIRTUAL_USDC * VIRTUAL_TOKENS) /
            newVirtualTokens;

        return newUSDC - currentUSDC;
    }

    function getSellPrice(
        uint256 sold,
        uint256 amount
    ) internal pure returns (uint256) {
        require(amount > 0, "Invalid amount");
        require(amount <= sold, "Not enough sold");

        uint256 currentVirtualTokens =
            VIRTUAL_TOKENS - sold;

        uint256 newVirtualTokens =
            currentVirtualTokens + amount;

        uint256 currentUSDC =
            (VIRTUAL_USDC * VIRTUAL_TOKENS) /
            currentVirtualTokens;

        uint256 newUSDC =
            (VIRTUAL_USDC * VIRTUAL_TOKENS) /
            newVirtualTokens;

        require(
            currentUSDC >= newUSDC,
            "Invalid curve"
        );

        return currentUSDC - newUSDC;
    }

    function currentPrice(
        uint256 sold
    ) internal pure returns (uint256) {
        uint256 currentVirtualTokens =
            VIRTUAL_TOKENS - sold;

        require(
            currentVirtualTokens > 0,
            "Curve complete"
        );

        return
            (VIRTUAL_USDC * 1e36) /
            currentVirtualTokens;
    }

    function getPrice(
        uint256 reserveUSDC,
        uint256 reserveTokens
    ) public pure returns (uint256) {
        if (reserveTokens == 0) {
            return ONE;
        }

        return
            (reserveUSDC * ONE) /
            reserveTokens;
    }
}
