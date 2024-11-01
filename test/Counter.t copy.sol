// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ReservoirLooper} from "../src/ReservoirLooper.sol";

contract ReservoirLooperTest is Test {
    ReservoirLooper public looper;

    function setUp() public {
        looper = new ReservoirLooper();
    }

    function test_loop() public {
        assertTrue(true);
    }
}
