// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

library BondingCurve {
  uint256 internal constant BASE_PRICE = 1e6;
uint256 internal constant PRICE_STEP = 1000;

    function getBuyPrice(
        uint256 sold,
        uint256 amount
    ) internal pure returns (uint256) {
        uint256 total;

        for (uint256 i = 0; i < amount; i++) {
            total += BASE_PRICE + ((sold + i) * PRICE_STEP);
        }

        return total;
    }

    function getSellPrice(
        uint256 sold,
        uint256 amount
    ) internal pure returns (uint256) {
        require(amount <= sold, "Not enough sold");

        uint256 total;

        for (uint256 i = 0; i < amount; i++) {
            total += BASE_PRICE + ((sold - 1 - i) * PRICE_STEP);
        }

        return total;
    }

    function currentPrice(
        uint256 sold
    ) internal pure returns (uint256) {
        return BASE_PRICE + (sold * PRICE_STEP);
    }

function getPrice(
    uint256 reserveUSDC,
    uint256 reserveTokens
) public pure returns (uint256) {
    if (reserveTokens == 0) {
        return 1e6; // 1 USDC
    }

    return (reserveUSDC * 1e6) / reserveTokens;
}
}
