// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ReservoirLooper} from "../src/ReservoirLooper.sol";

import {IMorpho, MarketParams} from "morpho-blue/src/interfaces/IMorpho.sol";
import "../src/libraries/ConstantsLib.sol";

contract ReservoirLooperScript is Script {
    IMorpho public morpho = IMorpho(MORPHO_ADDRESS);

    MarketParams public marketParams;

    function setUp() public {
        marketParams.loanToken = RUSD_ADDRESS;
        marketParams.collateralToken = SRUSD_ADDRESS;
        marketParams.oracle = ORACLE_ADDRESS;
        marketParams.irm = IRM_ADDRESS;
        marketParams.lltv = LLTV;
    }

    function run() public {
        vm.startBroadcast();

        // morpho.withdraw(
        //     marketParams,
        //     0,
        //     19988133884776223097768766,
        //     msg.sender,
        //     msg.sender
        // );

        vm.stopBroadcast();
    }
}
