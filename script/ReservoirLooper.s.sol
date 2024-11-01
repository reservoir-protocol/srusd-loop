// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ReservoirLooper} from "../src/ReservoirLooper.sol";

contract ReservoirLooperScript is Script {
    ReservoirLooper public looper;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        looper = new ReservoirLooper();

        vm.stopBroadcast();
    }
}