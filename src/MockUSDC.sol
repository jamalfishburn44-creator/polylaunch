// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    address public attackTarget;
    bool public attackEnabled;
    bool public attackAttempted;
    bool public attackSucceeded;
    bool private attacking;

    constructor() ERC20("Mock USDC", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setAttack(address target, bool enabled) external {
        attackTarget = target;
        attackEnabled = enabled;
        attackAttempted = false;
        attackSucceeded = false;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (attackEnabled && !attacking && attackTarget != address(0)) {
            attacking = true;
            attackAttempted = true;

            (bool success,) = attackTarget.call(
                abi.encodeWithSignature("createProject(string,string,uint256)", "Reentrant", "RENT", 1_000_000 ether)
            );

            attackSucceeded = success;
            attacking = false;
        }

        return super.transferFrom(from, to, amount);
    }
}
