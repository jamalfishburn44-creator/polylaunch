// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./PolyLaunchToken.sol";

contract BondingCurve {

    // Addresses
    address public creator;
    address public factory;

    // Token
    PolyLaunchToken public token;

    // Bonding Curve State
    uint256 public reserveBalance;
    uint256 public currentPrice;
    uint256 public priceIncrement;
    uint256 public totalSold;
    uint256 public graduationTarget;

    bool public graduated;

    // Events
    event TokensPurchased(
        address indexed buyer,
        uint256 amount,
        uint256 cost
    );

    event TokensSold(
        address indexed seller,
        uint256 amount,
        uint256 refund
    );

    event Graduated(uint256 reserveRaised);

    constructor(
        address _factory,
        address _creator,
        address _token,
        uint256 _startingPrice,
        uint256 _priceIncrement,
        uint256 _graduationTarget
    ) {
        factory = _factory;
        creator = _creator;

        token = PolyLaunchToken(_token);

        currentPrice = _startingPrice;
        priceIncrement = _priceIncrement;
        graduationTarget = _graduationTarget;
    }

    // Returns current token price
    function getCurrentPrice() public view returns (uint256) {
        return currentPrice;
    }

    // Calculates current market cap
    function getMarketCap() public view returns (uint256) {
        return currentPrice * totalSold;
    }

    // Returns graduation progress in basis points (10000 = 100%)
    function getGraduationProgress() public view returns (uint256) {
        if (graduationTarget == 0) {
            return 0;
        }

        if (reserveBalance >= graduationTarget) {
            return 10000;
        }

        return (reserveBalance * 10000) / graduationTarget;
    }

    // Returns remaining POL until graduation
    function remainingToGraduate() public view returns (uint256) {
        if (reserveBalance >= graduationTarget) {
            return 0;
        }

        return graduationTarget - reserveBalance;
    }
}
