// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/PolyLaunchFactory.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        address treasury = vm.envAddress("TREASURY");
        address usdc = vm.envAddress("USDC");
        address router = vm.envAddress("ROUTER");
        address factory = vm.envAddress("DEX_FACTORY");

        new PolyLaunchFactory(treasury, usdc, router, factory);

        vm.stopBroadcast();
    }
}
