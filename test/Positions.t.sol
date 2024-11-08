// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {TestSetup} from "./TestSetup.t.sol";

import "../src/libraries/ConstantsLib.sol";
import "../src/libraries/EventsLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Position, MarketParams} from "morpho-blue/src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "morpho-blue/src/libraries/MarketParamsLib.sol";

contract PositionsTest is TestSetup {
    using MarketParamsLib for MarketParams;

    function test_open_position() public {
        uint256 initialAmount = 1_000e18;
        uint256 targetAmount = 3_000e18;

        deal(SRUSD_ADDRESS, address(this), initialAmount, true);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(this)), initialAmount);
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(this)), 0);

        Position memory position = morpho.position(
            marketParams.id(),
            address(looper)
        );

        assertEq(position.collateral, 0);

        vm.expectEmit(true, true, true, true);
        emit EventsLib.OpenPosition(
            address(this),
            initialAmount,
            targetAmount,
            block.timestamp
        );
        looper.openPosition(initialAmount, targetAmount);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(this)), 0);
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(this)), 0);

        position = morpho.position(marketParams.id(), address(looper));

        assertEq(position.collateral, 0);

        position = morpho.position(marketParams.id(), address(this));

        assertEq(position.collateral, targetAmount);
    }

    function test_close_position() public {
        uint256 initialAmount = 1_000e18;
        uint256 targetAmount = 3_000e18;

        deal(SRUSD_ADDRESS, address(this), initialAmount, true);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);

        looper.openPosition(initialAmount, targetAmount);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);

        vm.expectEmit(true, true, true, true);
        emit EventsLib.ClosePosition(address(this), block.timestamp);
        looper.closePosition();

        Position memory position = morpho.position(
            marketParams.id(),
            address(looper)
        );

        assertEq(position.collateral, 0);
        assertEq(position.supplyShares, 0);
        assertEq(position.borrowShares, 0);

        position = morpho.position(marketParams.id(), address(this));

        assertEq(position.collateral, 0);
        assertEq(position.supplyShares, 0);
        assertEq(position.borrowShares, 0);

        assertApproxEqAbs(
            IERC20(SRUSD_ADDRESS).balanceOf(address(this)),
            initialAmount,
            1
        );
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(this)), 0);
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);
    }

    function testFuzz_open_position(
        uint256 initialAmount,
        uint8 leverage
    ) public {
        vm.assume(initialAmount >= 1e18 && initialAmount <= 10_000_000e18);
        vm.assume(leverage > 1 && leverage < 50);

        initialAmount = (initialAmount / 1e18) * 1e18;

        uint256 targetAmount = initialAmount * leverage;

        deal(SRUSD_ADDRESS, address(this), initialAmount, true);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(this)), initialAmount);
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(this)), 0);

        Position memory position = morpho.position(
            marketParams.id(),
            address(looper)
        );

        assertEq(position.collateral, 0);

        vm.expectEmit(true, true, true, true);
        emit EventsLib.OpenPosition(
            address(this),
            initialAmount,
            targetAmount,
            block.timestamp
        );
        looper.openPosition(initialAmount, targetAmount);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(this)), 0);
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(this)), 0);

        position = morpho.position(marketParams.id(), address(looper));

        assertEq(position.collateral, 0);

        position = morpho.position(marketParams.id(), address(this));

        assertEq(position.collateral, targetAmount);
    }

    function testFuzz_close_position(
        uint256 initialAmount,
        uint8 leverage
    ) public {
        vm.assume(initialAmount >= 1e18 && initialAmount <= 10_000_000e18);
        vm.assume(leverage > 1 && leverage < 50);

        initialAmount = (initialAmount / 1e18) * 1e18;

        uint256 targetAmount = initialAmount * leverage;

        deal(SRUSD_ADDRESS, address(this), initialAmount, true);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);

        looper.openPosition(initialAmount, targetAmount);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);

        vm.expectEmit(true, true, true, true);
        emit EventsLib.ClosePosition(address(this), block.timestamp);
        looper.closePosition();

        Position memory position = morpho.position(
            marketParams.id(),
            address(looper)
        );

        assertEq(position.collateral, 0);
        assertEq(position.supplyShares, 0);
        assertEq(position.borrowShares, 0);

        position = morpho.position(marketParams.id(), address(this));

        assertEq(position.collateral, 0);
        assertEq(position.supplyShares, 0);
        assertEq(position.borrowShares, 0);

        assertApproxEqAbs(
            IERC20(SRUSD_ADDRESS).balanceOf(address(this)),
            initialAmount,
            1
        );
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(this)), 0);
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);
    }

    function testFuzz_open_invalid_position(
        uint256 initialAmount,
        uint256 targetAmount
    ) public {
        vm.assume(initialAmount >= 1e18 && initialAmount <= 10_000_000e18);
        vm.assume(targetAmount <= initialAmount);

        deal(SRUSD_ADDRESS, address(this), initialAmount, true);

        vm.expectRevert("invalid target amount");
        looper.openPosition(initialAmount, targetAmount);
    }

    function test_close_nonexistent_position() public {
        vm.expectRevert("inconsistent input");
        looper.closePosition();
    }
}
