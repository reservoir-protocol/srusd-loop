// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ReservoirLooper} from "../src/ReservoirLooper.sol";

// reservoir interfaces
import {ISavingModule} from "../src/interfaces/ISavingModule.sol";

// libraries
import "../src/libraries/ConstantsLib.sol";

contract ReservoirLooperTest is Test {
    ReservoirLooper public looper;
    ISavingModule public savingModule;

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() external {
        vm.createSelectFork(MAINNET_RPC_URL);

        looper = new ReservoirLooper();
        savingModule = ISavingModule(SAVINGMODULE_ADDRESS);
    }

    function testFuzz_preview_to_srusd(uint256 _rusdAmount) external view {
        vm.assume(_rusdAmount < 1_000_000_000_000e18);

        assertEq(
            looper.previewToSrUSD(_rusdAmount),
            (_rusdAmount * 1e8) / savingModule.currentPrice()
        );
    }

    function testFuzz_preview_to_rusd(uint256 _srusdAmount) external view {
        vm.assume(_srusdAmount < 1_000_000_000_000e18);

        assertEq(
            looper.previewToRUSD(_srusdAmount),
            (_srusdAmount * savingModule.currentPrice()) / 1e8
        );
    }
}
