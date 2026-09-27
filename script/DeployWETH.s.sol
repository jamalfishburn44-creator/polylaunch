// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/WETH9.sol";

contract DeployWETH is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        WETH9 weth = new WETH9();

        console2.log("WETH9:", address(weth));

        vm.stopBroadcast();
    }
}
