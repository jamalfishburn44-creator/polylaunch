// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./PolyLaunchToken.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "./BondingCurve.sol";
import "./LPLocker.sol";
import "./TokenLocker.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Factory.sol";

contract PolyLaunchFactory is ReentrancyGuard {
using SafeERC20 for IERC20;
    address public owner;
    address public treasury;

    IERC20 public immutable usdc;
    IUniswapV2Router public immutable router;
    IUniswapV2Factory public immutable factory;
    LPLocker public lpLocker;
    TokenLocker public immutable tokenLocker;

    uint256 public constant LAUNCH_FEE = 1 * 1e6; // 1 USDC
uint256 public constant TOTAL_SUPPLY = 1_000_000_000;
    uint256 public constant GRADUATION_USDC = 150 * 1e6;
    uint256 public constant CURVE_BPS = 8000; // 80%
    uint256 public constant LIQUIDITY_BPS = 2000; // 20%
    uint256 public constant BPS = 10_000;
    uint256 public constant CURVE_FEE_BPS = 100; // 1.00%
    uint256 public constant CURVE_CREATOR_FEE_BPS = 25; // 0.25%
    uint256 public constant CURVE_PROTOCOL_FEE_BPS = 75; // 0.75%

    uint256 public totalProjects;

    struct Project {
        uint256 id;
        address creator;
        address token;
        string name;
        string symbol;
        string metadataURI;
        uint256 totalSupply;
        uint256 createdAt;
        bool active;

        uint256 reserveUSDC;
        uint256 reserveTokens;
        uint256 liquidityTokens;
        uint256 sold;

        bool graduated;
    }

    mapping(uint256 => Project) public projects;
    mapping(uint256 => uint256) public creatorFees;

    event ProjectCreated(uint256 indexed id, address indexed creator, address token, string name, string symbol);

    event TokenPurchased(uint256 indexed projectId, address indexed buyer, uint256 amount, uint256 cost);

    event TokenSold(uint256 indexed projectId, address indexed seller, uint256 amount, uint256 payout);

    event ProjectGraduated(
        uint256 indexed projectId, address indexed token, uint256 reserveUSDC, uint256 reserveTokens
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        owner = newOwner;
    }

    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury");
        treasury = newTreasury;
    }

    constructor(address _treasury, address _usdc, address _router, address _factory) {
        require(_treasury != address(0), "Invalid treasury");
require(_usdc != address(0), "Invalid USDC");
require(_router != address(0), "Invalid router");
require(_factory != address(0), "Invalid factory");

require(
    IUniswapV2Router(_router).factory() == _factory,
    "Router factory mismatch"
);

        owner = msg.sender;
        treasury = _treasury;
        usdc = IERC20(_usdc);
        router = IUniswapV2Router(_router);
        factory = IUniswapV2Factory(_factory);

        lpLocker = new LPLocker();
        tokenLocker = new TokenLocker();
    }

    function createProject(
    string memory name,
    string memory symbol,
    string memory metadataURI
)
        external
        nonReentrant
    {
        require(bytes(name).length > 0, "Invalid name");
        require(bytes(symbol).length > 0, "Invalid symbol");
        
        require(bytes(metadataURI).length > 0, "Invalid metadata");

        usdc.safeTransferFrom(msg.sender, treasury, LAUNCH_FEE);

        uint256 supply = TOTAL_SUPPLY * 1e18;

        PolyLaunchToken token = new PolyLaunchToken(name, symbol, supply, address(this));

        uint256 liquidityTokens = (supply * LIQUIDITY_BPS) / 10000;

        uint256 curveTokens = supply - liquidityTokens;

        totalProjects++;

        projects[totalProjects] = Project({
            id: totalProjects,
            creator: msg.sender,
            token: address(token),
            name: name,
            symbol: symbol,
            metadataURI: metadataURI,
            totalSupply: supply,
            createdAt: block.timestamp,
            active: true,
            reserveUSDC: 0,
            reserveTokens: curveTokens,
            liquidityTokens: liquidityTokens,
            sold: 0,
            graduated: false
        });

        emit ProjectCreated(totalProjects, msg.sender, address(token), name, symbol);
    }

    function buy(uint256 projectId, uint256 amount) external nonReentrant {
        require(projectId > 0 && projectId <= totalProjects, "Invalid project");

        Project storage project = projects[projectId];

        require(project.active, "Project inactive");
        require(amount > 0, "Invalid amount");
        require(project.reserveTokens >= amount, "Not enough tokens");

        uint256 curveCost = BondingCurve.getBuyPrice(project.sold, amount);
require(
    project.reserveUSDC + curveCost <= GRADUATION_USDC,
    "Purchase exceeds graduation target"
);

        uint256 fee = (curveCost * CURVE_FEE_BPS) / BPS;
        uint256 creatorFee = (curveCost * CURVE_CREATOR_FEE_BPS) / BPS;
        uint256 protocolFee = fee - creatorFee;
        uint256 totalCost = curveCost + fee;

        
        usdc.safeTransferFrom(msg.sender, address(this), totalCost);

        // Only the bonding-curve cost counts toward graduation.
        project.reserveUSDC += curveCost;
        project.reserveTokens -= amount;
        project.sold += amount;

        creatorFees[projectId] += creatorFee;
        usdc.safeTransfer(treasury, protocolFee);

        IERC20(project.token).safeTransfer(msg.sender, amount);

        if (project.reserveUSDC >= GRADUATION_USDC) {
            _graduateProject(projectId);
        }

        emit TokenPurchased(projectId, msg.sender, amount, totalCost);
    }

    function getBuyQuote(uint256 projectId, uint256 amount) external view returns (uint256) {
        require(projectId > 0 && projectId <= totalProjects, "Invalid project");

        Project storage project = projects[projectId];

        require(project.active, "Project inactive");
        require(amount > 0, "Invalid amount");
        require(project.reserveTokens >= amount, "Not enough tokens");

        uint256 curveCost = BondingCurve.getBuyPrice(project.sold, amount);
        uint256 fee = (curveCost * CURVE_FEE_BPS) / BPS;

        return curveCost + fee;
    }

    function getSellQuote(uint256 projectId, uint256 amount) external view returns (uint256) {
        require(projectId > 0 && projectId <= totalProjects, "Invalid project");

        Project storage project = projects[projectId];

        require(project.active, "Project inactive");
        require(amount > 0, "Invalid amount");
        require(project.sold >= amount, "Not enough sold");

        uint256 curvePayout = BondingCurve.getSellPrice(project.sold, amount);
        uint256 fee = (curvePayout * CURVE_FEE_BPS) / BPS;

        return curvePayout - fee;
    }

    function sell(uint256 projectId, uint256 amount) external nonReentrant {
        require(projectId > 0 && projectId <= totalProjects, "Invalid project");

        Project storage project = projects[projectId];

        require(project.active, "Project inactive");
        require(amount > 0, "Invalid amount");
        require(project.sold >= amount, "Not enough sold");

        uint256 curvePayout = BondingCurve.getSellPrice(project.sold, amount);

        require(curvePayout <= project.reserveUSDC, "Insufficient reserve");

        uint256 fee = (curvePayout * CURVE_FEE_BPS) / BPS;
        uint256 creatorFee = (curvePayout * CURVE_CREATOR_FEE_BPS) / BPS;
        uint256 protocolFee = fee - creatorFee;
        uint256 netPayout = curvePayout - fee;

        IERC20(project.token).safeTransferFrom(msg.sender, address(this), amount);

        project.reserveUSDC -= curvePayout;
        project.reserveTokens += amount;
        project.sold -= amount;

        creatorFees[projectId] += creatorFee;
        usdc.safeTransfer(treasury, protocolFee);
        usdc.safeTransfer(msg.sender, netPayout);

        emit TokenSold(projectId, msg.sender, amount, netPayout);
    }

    function claimCreatorFees(uint256 projectId) external nonReentrant {
        require(projectId > 0 && projectId <= totalProjects, "Invalid project");

        Project storage project = projects[projectId];
        require(msg.sender == project.creator, "Not creator");

        uint256 amount = creatorFees[projectId];
        require(amount > 0, "No creator fees");

        creatorFees[projectId] = 0;

        usdc.safeTransfer(msg.sender, amount);
    }

    function getProject(uint256 projectId) external view returns (Project memory) {
        require(projectId > 0 && projectId <= totalProjects, "Invalid project");
        return projects[projectId];
    }

    function _graduateProject(uint256 projectId) internal {
        Project storage project = projects[projectId];

        require(project.active, "Project inactive");
        require(!project.graduated, "Already graduated");
        require(project.reserveUSDC >= GRADUATION_USDC, "Target not reached");

        uint256 tokenAmount = project.liquidityTokens;
        uint256 usdcAmount = project.reserveUSDC;

        require(tokenAmount > 0, "No liquidity tokens");
        require(usdcAmount > 0, "No USDC");

        // Approve the DEX router to use the 20% liquidity allocation.
        IERC20(project.token).forceApprove(address(router), tokenAmount);

        // Approve the DEX router to use the accumulated USDC.
        usdc.forceApprove(address(router), usdcAmount);

        // Add the liquidity. LP tokens are sent directly to this factory.
        (,, uint256 liquidity) = router.addLiquidityWithFees(
            project.token,
            address(usdc),
            tokenAmount,
            usdcAmount,
            0,
            0,
            address(this),
            block.timestamp,
            project.creator,
            treasury
        );

        require(liquidity > 0, "No LP tokens");

        // Find the LP token/pair created by the DEX.
        address pair = factory.getPair(project.token, address(usdc));

        require(pair != address(0), "Pair not found");

        // Send LP tokens to the locker.
        IERC20(pair).safeTransfer(address(lpLocker), liquidity);

        // Lock LP tokens for one year.
        lpLocker.lock(pair, liquidity, block.timestamp + 365 days);

        // Permanently lock all remaining bonding-curve tokens.
        uint256 remainingTokens = project.reserveTokens;

        require(remainingTokens > 0, "No remaining tokens");

        IERC20(project.token).forceApprove(
            address(tokenLocker),
            remainingTokens
        );

        tokenLocker.lock(
            project.token,
            remainingTokens
        );

        // Finalize the project.
        project.graduated = true;
        project.active = false;

        emit ProjectGraduated(projectId, project.token, usdcAmount, tokenAmount);
    }

    function unlockLiquidity(address lpToken) external onlyOwner {
        lpLocker.unlock(lpToken);
    }
}
