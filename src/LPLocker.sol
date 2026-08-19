// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract LPLocker {
    address public immutable factory;

    struct Lock {
        uint256 amount;
        uint256 unlockTime;
        bool claimed;
    }

    mapping(address => Lock) public locks;

    event LiquidityLocked(address indexed lpToken, uint256 amount, uint256 unlockTime);

    event LiquidityUnlocked(address indexed lpToken, uint256 amount);

    constructor() {
        factory = msg.sender;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory");
        _;
    }

    function lock(address lpToken, uint256 amount, uint256 unlockTime) external onlyFactory {
        require(amount > 0, "Zero amount");
        require(unlockTime > block.timestamp, "Invalid unlock");

        locks[lpToken] = Lock({amount: amount, unlockTime: unlockTime, claimed: false});

        emit LiquidityLocked(lpToken, amount, unlockTime);
    }

    function unlock(address lpToken) external onlyFactory {
        Lock storage info = locks[lpToken];

        require(!info.claimed, "Already unlocked");
        require(block.timestamp >= info.unlockTime, "Still locked");

        info.claimed = true;

        require(IERC20(lpToken).transfer(factory, info.amount), "LP transfer failed");

        emit LiquidityUnlocked(lpToken, info.amount);
    }

    function balanceOf(address lpToken) external view returns (uint256) {
        return IERC20(lpToken).balanceOf(address(this));
    }
}
