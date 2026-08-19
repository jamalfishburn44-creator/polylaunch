// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./PolyLaunchToken.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "./BondingCurve.sol";
import "./LPLocker.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Factory.sol";

contract PolyLaunchFactory is ReentrancyGuard {
    address public owner;
    address public treasury;

    IERC20 public immutable usdc;
IUniswapV2Router public immutable router;
IUniswapV2Factory public immutable factory;
LPLocker public lpLocker;

uint256 public constant LAUNCH_FEE = 4 * 1e6; // 4 USDC
uint256 public constant GRADUATION_USDC = 150 * 1e6;
uint256 public constant CURVE_BPS = 8000; // 80%
uint256 public constant LIQUIDITY_BPS = 2000; // 20%

uint256 public totalProjects;

    struct Project {
    uint256 id;
    address creator;
    address token;
    string name;
    string symbol;
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

    event ProjectCreated(
        uint256 indexed id,
        address indexed creator,
        address token,
        string name,
        string symbol
    );

event TokenPurchased(
    uint256 indexed projectId,
    address indexed buyer,
    uint256 amount,
    uint256 cost
);

event TokenSold(
    uint256 indexed projectId,
    address indexed seller,
    uint256 amount,
    uint256 payout
);

event ProjectGraduated(
    uint256 indexed projectId,
    address indexed token,
    uint256 reserveUSDC,
    uint256 reserveTokens
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

    constructor(
    address _treasury,
    address _usdc,
    address _router,
    address _factory
    ) {
    require(_treasury != address(0), "Invalid treasury");
    require(_usdc != address(0), "Invalid USDC");
    require(_router != address(0), "Invalid router");
    require(_factory != address(0), "Invalid factory");

    owner = msg.sender;
    treasury = _treasury;
    usdc = IERC20(_usdc);
    router = IUniswapV2Router(_router);
    factory = IUniswapV2Factory(_factory);

    lpLocker = new LPLocker();
}

    function createProject(
        string memory name,
        string memory symbol,
        uint256 totalSupply
    ) external nonReentrant {
        require(bytes(name).length > 0, "Invalid name");
        require(bytes(symbol).length > 0, "Invalid symbol");
        require(totalSupply > 0, "Invalid supply");

require(
    usdc.transferFrom(msg.sender, treasury, LAUNCH_FEE),
    "Launch fee payment failed"
);

uint256 supply = totalSupply * 1e18;

PolyLaunchToken token = new PolyLaunchToken(
    name,
    symbol,
    supply,
    address(this)
);

uint256 liquidityTokens =
    (supply * LIQUIDITY_BPS) / 10000;

uint256 curveTokens =
    supply - liquidityTokens;

totalProjects++;

        projects[totalProjects] = Project({
            id: totalProjects,
            creator: msg.sender,
            token: address(token),
            name: name,
            symbol: symbol,
            totalSupply: supply,
            createdAt: block.timestamp,
            active: true,
reserveUSDC: 0,
reserveTokens: curveTokens,
liquidityTokens: liquidityTokens,
sold: 0,
graduated: false
        });

        emit ProjectCreated(
            totalProjects,
            msg.sender,
            address(token),
            name,
            symbol
        );
    }

function buy(uint256 projectId, uint256 amount) external nonReentrant {
    require(projectId > 0 && projectId <= totalProjects, "Invalid project");

    Project storage project = projects[projectId];

    require(project.active, "Project inactive");
    require(amount > 0, "Invalid amount");
    require(project.reserveTokens >= amount, "Not enough tokens");

    uint256 cost = BondingCurve.getBuyPrice(
        project.sold,
        amount
    );

    require(
        usdc.transferFrom(msg.sender, address(this), cost),
        "USDC payment failed"
    );

    project.reserveUSDC += cost;
project.reserveTokens -= amount;
project.sold += amount;

require(
    IERC20(project.token).transfer(msg.sender, amount),
    "Token transfer failed"
);

if (project.reserveUSDC >= GRADUATION_USDC) {
    _graduateProject(projectId);
}

emit TokenPurchased(
    projectId,
    msg.sender,
    amount,
    cost
);
}
function getBuyQuote(
    uint256 projectId,
    uint256 amount
) external view returns (uint256) {
    require(projectId > 0 && projectId <= totalProjects, "Invalid project");

    Project storage project = projects[projectId];

    require(project.active, "Project inactive");
    require(amount > 0, "Invalid amount");
    require(project.reserveTokens >= amount, "Not enough tokens");

    return BondingCurve.getBuyPrice(project.sold, amount);
}

function getSellQuote(
    uint256 projectId,
    uint256 amount
) external view returns (uint256) {
    require(projectId > 0 && projectId <= totalProjects, "Invalid project");

    Project storage project = projects[projectId];

    require(project.active, "Project inactive");
    require(amount > 0, "Invalid amount");
    require(project.sold >= amount, "Not enough sold");

    return BondingCurve.getSellPrice(project.sold, amount);
}

function sell(uint256 projectId, uint256 amount) external nonReentrant {
    require(projectId > 0 && projectId <= totalProjects, "Invalid project");

    Project storage project = projects[projectId];

    require(project.active, "Project inactive");
    require(amount > 0, "Invalid amount");
    require(project.sold >= amount, "Not enough sold");

    uint256 payout = BondingCurve.getSellPrice(
    project.sold,
    amount
);

require(
    payout <= project.reserveUSDC,
    "Insufficient reserve"
);

require(
    IERC20(project.token).transferFrom(
        msg.sender,
        address(this),
        amount
    ),
    "Token transfer failed"
);

    require(
        usdc.transfer(msg.sender, payout),
        "USDC payout failed"
    );

    project.reserveUSDC -= payout;
project.reserveTokens += amount;
project.sold -= amount;

emit TokenSold(
    projectId,
    msg.sender,
    amount,
    payout
);
}
    
   

function getProject(uint256 projectId)
    external
    view
    returns (Project memory)
{
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
    IERC20(project.token).approve(
        address(router),
        tokenAmount
    );

    // Approve the DEX router to use the accumulated USDC.
    usdc.approve(
        address(router),
        usdcAmount
    );

    // Add the liquidity. LP tokens are sent directly to this factory.
    (, , uint256 liquidity) = router.addLiquidity(
        project.token,
        address(usdc),
        tokenAmount,
        usdcAmount,
        0,
        0,
        address(this),
        block.timestamp
    );

    require(liquidity > 0, "No LP tokens");

    // Find the LP token/pair created by the DEX.
    address pair = factory.getPair(
        project.token,
        address(usdc)
    );

    require(pair != address(0), "Pair not found");

    // Send LP tokens to the locker.
    require(
        IERC20(pair).transfer(
            address(lpLocker),
            liquidity
        ),
        "LP transfer failed"
    );

    // Lock LP tokens for one year.
    lpLocker.lock(
        pair,
        liquidity,
        block.timestamp + 365 days
    );

    // Finalize the project.
    project.graduated = true;
    project.active = false;

    emit ProjectGraduated(
        projectId,
        project.token,
        usdcAmount,
        tokenAmount
    );
}
  }
