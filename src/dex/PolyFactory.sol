// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./PolyPair.sol";

contract PolyFactory {
    address public feeToSetter;
    address public router;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    event RouterSet(address indexed router);

    constructor(address _feeToSetter) {
        require(_feeToSetter != address(0), "Zero fee setter");
        feeToSetter = _feeToSetter;
    }

    modifier onlyFeeToSetter() {
        require(msg.sender == feeToSetter, "Only fee setter");
        _;
    }

    modifier onlyRouter() {
        require(msg.sender == router, "Only router");
        _;
    }

    function setRouter(address _router)
        external
        onlyFeeToSetter
    {
        require(_router != address(0), "Zero router");
        require(router == address(0), "Router already set");

        router = _router;

        emit RouterSet(_router);
    }

    function allPairsLength()
        external
        view
        returns (uint256)
    {
        return allPairs.length;
    }

    function createPair(
    address tokenA,
    address tokenB
)
    external
    onlyRouter
    returns (address pair)
    {
        require(tokenA != address(0), "Zero token");
        require(tokenB != address(0), "Zero token");
        require(tokenA != tokenB, "Identical tokens");

        (address token0, address token1) =
            tokenA < tokenB
                ? (tokenA, tokenB)
                : (tokenB, tokenA);

        require(
            getPair[token0][token1] == address(0),
            "Pair exists"
        );

        pair = address(
            new PolyPair(
                token0,
                token1,
                address(0),
                feeToSetter
            )
        );

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;

        allPairs.push(pair);

        emit PairCreated(
            token0,
            token1,
            pair,
            allPairs.length
        );
    }

    function createPairWithFees(
        address tokenA,
        address tokenB,
        address creator,
        address treasury
    )
        external
        onlyRouter
        returns (address pair)
    {
        require(tokenA != address(0), "Zero token");
        require(tokenB != address(0), "Zero token");
        require(tokenA != tokenB, "Identical tokens");
        require(creator != address(0), "Zero creator");
        require(treasury != address(0), "Zero treasury");

        (address token0, address token1) =
            tokenA < tokenB
                ? (tokenA, tokenB)
                : (tokenB, tokenA);

        require(
            getPair[token0][token1] == address(0),
            "Pair exists"
        );

        pair = address(
            new PolyPair(
                token0,
                token1,
                creator,
                treasury
            )
        );

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;

        allPairs.push(pair);

        emit PairCreated(
            token0,
            token1,
            pair,
            allPairs.length
        );
    }

    function mintLiquidity(
        address pair,
        address to
    )
        external
        onlyRouter
        returns (uint256 liquidity)
    {
        require(pair != address(0), "Zero pair");
        require(to != address(0), "Zero recipient");

        liquidity = PolyPair(pair).mint(to);
    }
}
