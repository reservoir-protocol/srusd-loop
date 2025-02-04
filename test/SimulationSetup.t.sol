// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/libraries/ConstantsLib.sol";

import {IReservoirLooper} from "../src/interfaces/IReservoirLooper.sol";
import {ICreditEnforcer} from "../src/interfaces/ICreditEnforcer.sol";

import {Test, console} from "forge-std/Test.sol";

contract SimulationSetup is Test {
    IReservoirLooper public looper =
        IReservoirLooper(0xF31d7c3403bb3379BabB2B2F5f3d7e7d4938675c);

    ICreditEnforcer public creditEnforcer =
        ICreditEnforcer(CREDITENFORCER_ADDRESS);

    IERC20 public srusd = IERC20(SRUSD_ADDRESS);
    IERC20 public rusd = IERC20(RUSD_ADDRESS);

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() external {
        vm.createSelectFork(MAINNET_RPC_URL, 21325447);
    }

    function test_simulation() public {
        address user;

        vm.startPrank(user);
    }

    function test_stuff() public {}
}
