// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./PolyLaunchToken.sol";

contract BondingCurve {

    PolyLaunchToken public token;

    uint256 public reserveBalance;
    uint256 public currentPrice;
    uint256 public priceIncrement;
    uint256 public totalSold;
    uint256 public graduationTarget;

    bool public graduated;

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
        address _token,
        uint256 _startingPrice,
        uint256 _priceIncrement,
        uint256 _graduationTarget
    ) {
        token = PolyLaunchToken(_token);
        currentPrice = _startingPrice;
        priceIncrement = _priceIncrement;
        graduationTarget = _graduationTarget;
    }
}
