// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {ReservoirLooperSrusdUsdcTestSetup} from "./ReservoirLooperSrusdUsdcTestSetup.t.sol";

import "../../src/libraries/ConstantsLib.sol";
import "../../src/libraries/EventsLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Position, MarketParams} from "morpho-blue/src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "morpho-blue/src/libraries/MarketParamsLib.sol";

import {console} from "forge-std/Test.sol";

contract ReservoirLooperSrusdUsdcFlowTest is ReservoirLooperSrusdUsdcTestSetup {
    using MarketParamsLib for MarketParams;

    function test_open_position() public {
        uint256 initialAmount = 1_000e18;
        uint256 targetAmount = 3_000e18;

        deal(SRUSD_ADDRESS, address(this), initialAmount, true);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(this)), initialAmount);
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(this)), 0);

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
        assertTrue(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(this)), 0);
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
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);

        looper.openPosition(initialAmount, targetAmount);

        assertTrue(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);

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

        //  redemption fee
        assertApproxEqRel(
            IERC20(SRUSD_ADDRESS).balanceOf(address(this)),
            (initialAmount * (1e6 - savingModule.redeemFee())) / 1e6,
            0.01e18
        );
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(this)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(this)), 0);
        assertTrue(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertTrue(IERC20(RUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);
    }

    function testFuzz_open_position(
        uint256 initialAmount,
        uint8 leverage
    ) public {
        vm.assume(initialAmount >= 1e18 && initialAmount <= 10_000_000e18);
        vm.assume(leverage > 1 && leverage < 12);

        initialAmount = (initialAmount / 1e18) * 1e18;

        uint256 targetAmount = initialAmount * leverage;

        deal(SRUSD_ADDRESS, address(this), initialAmount, true);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(this)), initialAmount);
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(this)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(this)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);

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
        assertTrue(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(this)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(this)), 0);

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
        vm.assume(leverage > 1 && leverage < 12);

        initialAmount = (initialAmount / 1e18) * 1e18;

        uint256 targetAmount = initialAmount * leverage;

        deal(SRUSD_ADDRESS, address(this), initialAmount, true);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);

        looper.openPosition(initialAmount, targetAmount);

        assertTrue(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);

        // vm.expectEmit(true, true, true, true);
        // emit EventsLib.ClosePosition(address(this), block.timestamp);
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

        assertApproxEqRel(
            IERC20(SRUSD_ADDRESS).balanceOf(address(this)),
            initialAmount,
            0.01e18
        );
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(this)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(this)), 0);
        assertTrue(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertTrue(IERC20(RUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);
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

    function test_multiple_positions() public {
        looper.grantRole(looper.WHITELIST(), address(1));
        looper.grantRole(looper.WHITELIST(), address(2));
        looper.grantRole(looper.WHITELIST(), address(3));

        vm.startPrank(address(1));
        morpho.setAuthorization(address(looper), true);
        IERC20(SRUSD_ADDRESS).approve(address(looper), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(address(2));
        morpho.setAuthorization(address(looper), true);
        IERC20(SRUSD_ADDRESS).approve(address(looper), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(address(3));
        morpho.setAuthorization(address(looper), true);
        IERC20(SRUSD_ADDRESS).approve(address(looper), type(uint256).max);
        vm.stopPrank();

        deal(SRUSD_ADDRESS, address(1), 1_000_000e18, true);
        deal(SRUSD_ADDRESS, address(2), 1_000_000e18, true);
        deal(SRUSD_ADDRESS, address(3), 1_000_000e18, true);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(1)), 1_000_000e18);
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(2)), 1_000_000e18);
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(3)), 1_000_000e18);

        Position memory position = morpho.position(
            marketParams.id(),
            address(looper)
        );

        assertEq(position.collateral, 0);

        vm.prank(address(1));
        looper.openPosition(400_000e18, 2_000_000e18);

        vm.prank(address(2));
        looper.openPosition(1_000_000e18, 9_000_000e18);

        assertTrue(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(1)), 600_000e18);
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(2)), 0);
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(3)), 1_000_000e18);

        position = morpho.position(marketParams.id(), address(looper));
        assertEq(position.collateral, 0);
        assertEq(position.borrowShares, 0);

        position = morpho.position(marketParams.id(), address(1));
        assertEq(position.collateral, 2_000_000e18);
        assertTrue(position.borrowShares > 0);

        position = morpho.position(marketParams.id(), address(2));
        assertEq(position.collateral, 9_000_000e18);
        assertTrue(position.borrowShares > 0);

        position = morpho.position(marketParams.id(), address(3));
        assertEq(position.collateral, 0);
        assertEq(position.borrowShares, 0);

        vm.prank(address(1));
        looper.closePosition();

        assertTrue(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertTrue(IERC20(RUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertApproxEqRel(
            IERC20(SRUSD_ADDRESS).balanceOf(address(1)),
            1_000_000e18,
            0.01e18
        );
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(2)), 0);
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(3)), 1_000_000e18);

        position = morpho.position(marketParams.id(), address(looper));
        assertEq(position.collateral, 0);
        assertEq(position.borrowShares, 0);

        position = morpho.position(marketParams.id(), address(1));
        assertEq(position.collateral, 0);
        assertEq(position.borrowShares, 0);

        position = morpho.position(marketParams.id(), address(2));
        assertEq(position.collateral, 9_000_000e18);
        assertTrue(position.borrowShares > 0);

        position = morpho.position(marketParams.id(), address(3));
        assertEq(position.collateral, 0);
        assertEq(position.borrowShares, 0);

        vm.prank(address(3));
        looper.openPosition(900_000e18, 9_900_000e18);

        assertTrue(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertTrue(IERC20(RUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertApproxEqRel(
            IERC20(SRUSD_ADDRESS).balanceOf(address(1)),
            1_000_000e18,
            0.01e18
        );
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(2)), 0);
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(3)), 100_000e18);

        position = morpho.position(marketParams.id(), address(looper));
        assertEq(position.collateral, 0);
        assertEq(position.borrowShares, 0);

        position = morpho.position(marketParams.id(), address(1));
        assertEq(position.collateral, 0);
        assertEq(position.borrowShares, 0);

        position = morpho.position(marketParams.id(), address(2));
        assertEq(position.collateral, 9_000_000e18);
        assertTrue(position.borrowShares > 0);

        position = morpho.position(marketParams.id(), address(3));
        assertEq(position.collateral, 9_900_000e18);
        assertTrue(position.borrowShares > 0);

        vm.prank(address(2));
        looper.closePosition();

        assertTrue(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertTrue(IERC20(RUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertApproxEqRel(
            IERC20(SRUSD_ADDRESS).balanceOf(address(1)),
            1_000_000e18,
            0.01e18
        );
        assertApproxEqRel(
            IERC20(SRUSD_ADDRESS).balanceOf(address(2)),
            1_000_000e18,
            0.01e18
        );
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(3)), 100_000e18);

        position = morpho.position(marketParams.id(), address(looper));
        assertEq(position.collateral, 0);
        assertEq(position.borrowShares, 0);

        position = morpho.position(marketParams.id(), address(1));
        assertEq(position.collateral, 0);
        assertEq(position.borrowShares, 0);

        position = morpho.position(marketParams.id(), address(2));
        assertEq(position.collateral, 0);
        assertEq(position.borrowShares, 0);

        position = morpho.position(marketParams.id(), address(3));
        assertEq(position.collateral, 9_900_000e18);
        assertTrue(position.borrowShares > 0);

        vm.prank(address(3));
        looper.closePosition();

        assertTrue(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertTrue(IERC20(RUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertApproxEqRel(
            IERC20(SRUSD_ADDRESS).balanceOf(address(1)),
            1_000_000e18,
            0.01e18
        );
        assertApproxEqRel(
            IERC20(SRUSD_ADDRESS).balanceOf(address(2)),
            1_000_000e18,
            0.01e18
        );
        assertApproxEqRel(
            IERC20(SRUSD_ADDRESS).balanceOf(address(3)),
            1_000_000e18,
            0.01e18
        );
        position = morpho.position(marketParams.id(), address(looper));
        assertEq(position.collateral, 0);
        assertEq(position.borrowShares, 0);

        position = morpho.position(marketParams.id(), address(1));
        assertEq(position.collateral, 0);
        assertEq(position.borrowShares, 0);

        position = morpho.position(marketParams.id(), address(2));
        assertEq(position.collateral, 0);
        assertEq(position.borrowShares, 0);

        position = morpho.position(marketParams.id(), address(3));
        assertEq(position.collateral, 0);
        assertEq(position.borrowShares, 0);
    }

    function test_open_position_twice_and_close() public {
        deal(SRUSD_ADDRESS, address(this), 1_000_000e18, true);

        looper.openPosition(200_000e18, 1_400_000e18);

        looper.openPosition(800_000e18, 3_000_000e18);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(this)), 0);
        assertTrue(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(this)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(this)), 0);

        Position memory position = morpho.position(
            marketParams.id(),
            address(looper)
        );

        assertEq(position.collateral, 0);

        position = morpho.position(marketParams.id(), address(this));

        assertEq(position.collateral, 1_400_000e18 + 3_000_000e18);

        looper.closePosition();

        position = morpho.position(marketParams.id(), address(looper));

        assertEq(position.collateral, 0);
        assertEq(position.supplyShares, 0);
        assertEq(position.borrowShares, 0);

        position = morpho.position(marketParams.id(), address(this));

        assertEq(position.collateral, 0);
        assertEq(position.supplyShares, 0);
        assertEq(position.borrowShares, 0);

        assertApproxEqRel(
            IERC20(SRUSD_ADDRESS).balanceOf(address(this)),
            1_000_000e18,
            0.01e18
        );
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(this)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(this)), 0);
        assertTrue(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertTrue(IERC20(RUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);
    }

    function test_reduce_position() public {
        uint256 initialAmount = 10_000e18;
        uint256 targetAmount = 30_000e18;
        uint256 collateralToWithdraw = 20_000e18;

        deal(SRUSD_ADDRESS, address(this), initialAmount, true);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);

        looper.openPosition(initialAmount, targetAmount);

        assertTrue(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);

        looper.reducePosition(collateralToWithdraw);

        Position memory position = morpho.position(
            marketParams.id(),
            address(this)
        );

        assertEq(position.collateral, targetAmount - collateralToWithdraw);
    }

    function testFuzz_reduce_position(
        uint256 initialAmount,
        uint8 leverage,
        uint256 collateralToWithdraw
    ) public {
        vm.assume(initialAmount >= 1e18 && initialAmount <= 10_000_000e18);
        vm.assume(leverage > 1 && leverage < 12);

        initialAmount = (initialAmount / 1e18) * 1e18;
        uint256 targetAmount = initialAmount * leverage;

        deal(SRUSD_ADDRESS, address(this), initialAmount, true);

        looper.openPosition(initialAmount, targetAmount);

        collateralToWithdraw = bound(collateralToWithdraw, 1e18, targetAmount);

        collateralToWithdraw = (collateralToWithdraw / 1e18) * 1e18;

        looper.reducePosition(collateralToWithdraw);

        Position memory position = morpho.position(
            marketParams.id(),
            address(this)
        );

        assertEq(position.collateral, targetAmount - collateralToWithdraw);
    }

    function testFuzz_reduce_all_position(
        uint256 initialAmount,
        uint8 leverage
    ) public {
        vm.assume(initialAmount >= 1e18 && initialAmount <= 10_000_000e18);
        vm.assume(leverage > 1 && leverage < 12);

        initialAmount = (initialAmount / 1e18) * 1e18;
        uint256 targetAmount = initialAmount * leverage;
        uint256 collateralToWithdraw = targetAmount;

        deal(SRUSD_ADDRESS, address(this), initialAmount, true);

        looper.openPosition(initialAmount, targetAmount);

        looper.reducePosition(collateralToWithdraw);

        Position memory position = morpho.position(
            marketParams.id(),
            address(this)
        );

        assertEq(position.collateral, 0);
        assertEq(position.borrowShares, 0);
    }

    function test_reduce_position_multiple() public {
        uint256 initialAmount = 10_000e18;
        uint256 targetAmount = 30_000e18;
        uint256 collateralToWithdraw = 5_000e18;

        deal(SRUSD_ADDRESS, address(this), initialAmount, true);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);

        looper.openPosition(initialAmount, targetAmount);

        assertTrue(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)) < 1e18); // dust amount
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(looper)), 0);

        looper.reducePosition(collateralToWithdraw);
        looper.reducePosition(collateralToWithdraw);
        looper.reducePosition(collateralToWithdraw);
        looper.reducePosition(collateralToWithdraw);

        Position memory position = morpho.position(
            marketParams.id(),
            address(this)
        );

        assertEq(position.collateral, targetAmount - collateralToWithdraw * 4);
    }
}
