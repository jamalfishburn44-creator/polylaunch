// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./PolyLaunchToken.sol";

contract PolyLaunchFactory {

    address public owner;
    address public treasury;
    uint256 public launchFee;
    uint256 public totalProjects;

    struct Project {
        address creator;
        address token;
        string name;
        string symbol;
        uint256 supply;
        uint256 createdAt;
        bool graduated;
    }

    mapping(uint256 => Project) public projects;

    event ProjectCreated(
        uint256 indexed projectId,
        address indexed creator,
        address token,
        string name,
        string symbol
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _treasury, uint256 _launchFee) {
        owner = msg.sender;
        treasury = _treasury;
        launchFee = _launchFee;
    }

    function setLaunchFee(uint256 _newFee) external onlyOwner {
        launchFee = _newFee;
    }

    function setTreasury(address _newTreasury) external onlyOwner {
        treasury = _newTreasury;
    }

    function createProject(
        string memory _name,
        string memory _symbol,
        uint256 _supply
    ) external payable {

        require(msg.value >= launchFee, "Launch fee not paid");
        require(bytes(_name).length > 0, "Name required");
        require(bytes(_symbol).length > 0, "Symbol required");
        require(_supply > 0, "Invalid supply");

        payable(treasury).transfer(msg.value);

        PolyLaunchToken token = new PolyLaunchToken(
            _name,
            _symbol,
            _supply,
            msg.sender
        );

        totalProjects++;

        projects[totalProjects] = Project({
            creator: msg.sender,
            token: address(token),
            name: _name,
            symbol: _symbol,
            supply: _supply,
            createdAt: block.timestamp,
            graduated: false
        });

        emit ProjectCreated(
            totalProjects,
            msg.sender,
            address(token),
            _name,
            _symbol
        );
    }
}
