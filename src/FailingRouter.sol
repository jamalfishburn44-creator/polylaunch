// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract FailingRouter {
    address public immutable dexFactory;

    constructor(address _factory) {
        dexFactory = _factory;
    }

    function factory() external view returns (address) {
        return dexFactory;
    }

    function WETH() external pure returns (address) {
        return address(0);
    }

    function addLiquidity(address, address, uint256, uint256, uint256, uint256, address, uint256)
        external
        pure
        returns (uint256, uint256, uint256)
    {
        revert("DEX liquidity failed");
    }

function addLiquidityWithFees(
    address,
    address,
    uint256,
    uint256,
    uint256,
    uint256,
    address,
    uint256,
    address,
    address
)
    external
    pure
    returns (uint256, uint256, uint256)
{
    revert("DEX liquidity failed");
}
}
