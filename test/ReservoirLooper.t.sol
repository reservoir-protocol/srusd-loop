// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ReservoirLooper} from "../src/ReservoirLooper.sol";

// morpho-blue
import {IMorpho, MarketParams, Id, Position} from "morpho-blue/src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "morpho-blue/src/libraries/MarketParamsLib.sol";

// reservoir interfaces
import {ICreditEnforcer} from "../src/interfaces/ICreditEnforcer.sol";

// openzeppelin
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// libraries
import "../src/libraries/ConstantsLib.sol";
import "../src/libraries/EventsLib.sol";
import "../src/libraries/ErrorsLib.sol";

contract ReservoirLooperTest is Test {
    using MarketParamsLib for MarketParams;

    ReservoirLooper public looper;

    IMorpho public morpho = IMorpho(MORPHO_ADDRESS);

    MarketParams public marketParams;

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() external {
        vm.createSelectFork(MAINNET_RPC_URL);

        looper = new ReservoirLooper();

        looper.grantRole(looper.MORPHO_ROLE(), MORPHO_ADDRESS);

        // configure CreditEnforcer
        vm.startPrank(0x4E8a4894275780f571AaD53122e641D9f50Ff04f);
        ICreditEnforcer(CREDITENFORCER_ADDRESS).setSMDebtMax(type(uint256).max);
        ICreditEnforcer(CREDITENFORCER_ADDRESS).setAssetRatioMin(0);
        ICreditEnforcer(CREDITENFORCER_ADDRESS).setEquityRatioMin(0);
        ICreditEnforcer(CREDITENFORCER_ADDRESS).setLiquidityRatioMin(0);
        vm.stopPrank();

        marketParams.loanToken = RUSD_ADDRESS;
        marketParams.collateralToken = SRUSD_ADDRESS;
        marketParams.oracle = ORACLE_ADDRESS;
        marketParams.irm = IRM_ADDRESS;
        marketParams.lltv = LLTV;

        // provide rusd liquiditiy to the market
        deal(RUSD_ADDRESS, address(1), 1_000_000_000_000e18, true);
        vm.startPrank(address(1));
        IERC20(RUSD_ADDRESS).approve(address(morpho), 1_000_000_000_000e18);
        morpho.supply(marketParams, 1_000_000_000_000e18, 0, address(1), "");
        vm.stopPrank();
    }

    function test_open_position() public {
        uint256 initialAmount = 1_000e18;
        uint256 targetAmount = 3_000e18;

        looper.grantRole(looper.WHITELIST(), address(this));

        deal(SRUSD_ADDRESS, address(this), initialAmount, true);

        IERC20(SRUSD_ADDRESS).approve(address(looper), initialAmount);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(this)), initialAmount);
        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(this)), 0);

        Position memory position = morpho.position(
            marketParams.id(),
            address(looper)
        );

        assertEq(position.collateral, 0);

        morpho.setAuthorization(address(looper), true);

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

        looper.grantRole(looper.WHITELIST(), address(this));

        deal(SRUSD_ADDRESS, address(this), initialAmount, true);

        IERC20(SRUSD_ADDRESS).approve(address(looper), initialAmount);

        assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
        assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);

        morpho.setAuthorization(address(looper), true);

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

    // function testFuzz_open_position(
    //     uint256 initialAmount,
    //     uint8 leverage
    // ) public {
    //     vm.assume(initialAmount >= 1e18 && initialAmount < 1_000_000_000e18);
    //     vm.assume(leverage > 1 && leverage <= 10);

    //     uint256 targetAmount = initialAmount * leverage;

    //     looper.grantRole(looper.WHITELIST(), address(this));

    //     deal(SRUSD_ADDRESS, address(this), initialAmount, true);

    //     IERC20(SRUSD_ADDRESS).approve(address(looper), initialAmount);

    //     assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(this)), initialAmount);
    //     assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
    //     assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);
    //     assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(this)), 0);

    //     Position memory position = morpho.position(
    //         marketParams.id(),
    //         address(looper)
    //     );

    //     assertEq(position.collateral, 0);

    //     morpho.setAuthorization(address(looper), true);

    //     vm.expectEmit(true, true, true, true);
    //     emit EventsLib.OpenPosition(
    //         address(this),
    //         initialAmount,
    //         targetAmount,
    //         block.timestamp
    //     );
    //     looper.openPosition(initialAmount, targetAmount);

    //     assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(this)), 0);
    //     assertEq(IERC20(SRUSD_ADDRESS).balanceOf(address(looper)), 0);
    //     assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(looper)), 0);
    //     assertEq(IERC20(RUSD_ADDRESS).balanceOf(address(this)), 0);

    //     position = morpho.position(marketParams.id(), address(looper));

    //     assertEq(position.collateral, 0);

    //     position = morpho.position(marketParams.id(), address(this));

    //     assertEq(position.collateral, targetAmount);
    // }
}
