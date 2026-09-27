// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

interface IReentrantPair {
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    ) external;
}

contract ReentrantToken is ERC20 {
    address public targetPair;
    bool public attackEnabled;
    bool public attackAttempted;

    constructor() ERC20("Reentrant Token", "REENT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function configureAttack(address pair) external {
        targetPair = pair;
        attackEnabled = true;
        attackAttempted = false;
    }

    function disableAttack() external {
        attackEnabled = false;
    }

    function _update(
    address from,
    address to,
    uint256 amount
) internal override {
    super._update(from, to, amount);

    if (
        attackEnabled &&
        !attackAttempted &&
        from == targetPair &&
        targetPair != address(0)
    ) {
        attackAttempted = true;

        try IReentrantPair(targetPair).swap(
            1,
            0,
            address(this)
        ) {} catch {}
    }
}
        
}
