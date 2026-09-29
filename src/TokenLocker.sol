// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenLocker {
    using SafeERC20 for IERC20;

    address public immutable factory;

    struct Lock {
        uint256 amount;
        bool locked;
    }

    mapping(address => Lock) public locks;

    event TokensPermanentlyLocked(
        address indexed token,
        uint256 amount
    );

    constructor() {
        factory = msg.sender;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory");
        _;
    }

    function lock(
        address token,
        uint256 amount
    ) external onlyFactory {
        require(token != address(0), "Invalid token");
        require(amount > 0, "Zero amount");
        require(!locks[token].locked, "Already locked");

        IERC20(token).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        locks[token] = Lock({
            amount: amount,
            locked: true
        });

        emit TokensPermanentlyLocked(token, amount);
    }

    function balanceOf(address token)
        external
        view
        returns (uint256)
    {
        return IERC20(token).balanceOf(address(this));
    }
}
