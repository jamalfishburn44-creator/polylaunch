// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockFactory {
    address public immutable pair;

    constructor(address _pair) {
        pair = _pair;
    }

    function createPair(address, address) external view returns (address) {
        return pair;
    }

    function getPair(address, address) external view returns (address) {
        return pair;
    }
}
