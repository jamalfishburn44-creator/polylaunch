// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/dex/PolyRouter.sol";

contract DeployPolyRouter is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address factory = vm.envAddress("DEX_FACTORY");
        address weth = vm.envAddress("WETH");

        vm.startBroadcast(deployerKey);

        PolyRouter router = new PolyRouter(factory, weth);

        console2.log("PolyRouter:", address(router));

        vm.stopBroadcast();
    }
}
