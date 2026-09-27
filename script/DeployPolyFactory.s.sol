// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/dex/PolyFactory.sol";

contract DeployPolyFactory is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY");

        vm.startBroadcast(deployerKey);

        PolyFactory factory = new PolyFactory(treasury);

        console2.log("PolyFactory:", address(factory));

        vm.stopBroadcast();
    }
}
