// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Staking} from "src/Staking.sol";

contract StakingScript is Script {
    address constant ZERO = address(0);

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        console.log(msg.sender, "is running the script");
        Staking staking = new Staking(ZERO, 100, 100, 100, ZERO);
        console.log("the staking contract is deployed at ", address(staking));
        vm.stopBroadcast();
    }
}
