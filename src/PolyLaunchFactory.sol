// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PolyLaunchFactory {

    address public owner;
    address public treasury;

    uint256 public launchFee = 4 ether;
    uint256 public totalProjects;

    struct Project {
        uint256 id;
        address creator;
        string name;
        string symbol;
        uint256 totalSupply;
        uint256 createdAt;
        bool active;
    }

    mapping(uint256 => Project) public projects;

    event ProjectCreated(
        uint256 indexed id,
        address indexed creator,
        string name,
        string symbol
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _treasury) {
        owner = msg.sender;
        treasury = _treasury;
    }

    function createProject(
        string memory name,
        string memory symbol,
        uint256 totalSupply
    ) external payable {

        require(msg.value >= launchFee, "Launch fee required");
        require(bytes(name).length > 0, "Invalid name");
        require(bytes(symbol).length > 0, "Invalid symbol");
        require(totalSupply > 0, "Invalid supply");

        totalProjects++;

        projects[totalProjects] = Project({
            id: totalProjects,
            creator: msg.sender,
            name: name,
            symbol: symbol,
            totalSupply: totalSupply,
            createdAt: block.timestamp,
            active: true
        });

        payable(treasury).transfer(msg.value);

        emit ProjectCreated(
            totalProjects,
            msg.sender,
            name,
            symbol
        );
    }

    function setLaunchFee(uint256 newFee) external onlyOwner {
        launchFee = newFee;
    }

    function setTreasury(address newTreasury) external onlyOwner {
        treasury = newTreasury;
    }
}
