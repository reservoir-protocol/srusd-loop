// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {TestSetup} from "./TestSetup.t.sol";

contract PricePreviewTest is TestSetup {
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
