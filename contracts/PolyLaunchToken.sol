// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract PolyLaunchToken {

    string public name;
    string public symbol;
    uint256 public totalSupply;
    address public creator;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply,
        address _creator
    ) {
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply;
        creator = _creator;
    }
}
