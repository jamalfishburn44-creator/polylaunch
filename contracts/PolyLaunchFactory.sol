// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract PolyLaunchFactory {

    address public owner;
    address public treasury;

    uint256 public launchFee;
    uint256 public totalProjects;

    struct Project {
        uint256 id;
        address creator;
        address tokenAddress;
        string name;
        string symbol;
        uint256 totalSupply;
        bool graduated;
        uint256 createdAt;
    }

    mapping(uint256 => Project) public projects;

    event ProjectCreated(
        uint256 indexed id,
        address indexed creator,
        address tokenAddress,
        string name,
        string symbol
    );

    constructor(address _treasury, uint256 _launchFee) {
        owner = msg.sender;
        treasury = _treasury;
        launchFee = _launchFee;
        totalProjects = 0;
    }
}
