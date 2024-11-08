// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ReservoirLooper} from "../src/ReservoirLooper.sol";

// morpho-blue
import {IMorpho, MarketParams, Id, Position} from "morpho-blue/src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "morpho-blue/src/libraries/MarketParamsLib.sol";

// reservoir interfaces
import {ICreditEnforcer} from "../src/interfaces/ICreditEnforcer.sol";
import {ISavingModule} from "../src/interfaces/ISavingModule.sol";

// openzeppelin
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// libraries
import "../src/libraries/ConstantsLib.sol";
import "../src/libraries/EventsLib.sol";
import "../src/libraries/ErrorsLib.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock ERC20", "MRC") {}
}

contract TestSetup is Test {
    using MarketParamsLib for MarketParams;

    ReservoirLooper public looper;

    IMorpho public morpho = IMorpho(MORPHO_ADDRESS);

    ISavingModule public savingModule;

    ERC20 public testToken;

    MarketParams public marketParams;

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() external {
        vm.createSelectFork(MAINNET_RPC_URL);

        testToken = new MockERC20();

        savingModule = ISavingModule(SAVINGMODULE_ADDRESS);

        looper = new ReservoirLooper(address(this));

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

        // set up permissions for looper
        looper.grantRole(looper.WHITELIST(), address(this));
        IERC20(SRUSD_ADDRESS).approve(address(looper), type(uint256).max);
        morpho.setAuthorization(address(looper), true);
    }
}
