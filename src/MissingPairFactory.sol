// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MissingPairFactory {
    function createPair(address, address) external pure returns (address) {
        return address(0);
    }

    function getPair(address, address) external pure returns (address) {
        return address(0);
    }
}
