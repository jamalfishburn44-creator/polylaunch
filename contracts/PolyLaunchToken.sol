// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract PolyLaunchToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;

    address public factory;
    address public creator;

    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 value);

    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _supply,
        address _creator
    ) {
        name = _name;
        symbol = _symbol;
        creator = _creator;
        factory = msg.sender;

        totalSupply = _supply;
        balanceOf[_creator] = _supply;

        emit Transfer(address(0), _creator, _supply);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(to != address(0), "Invalid address");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);

        return true;
    }
}
