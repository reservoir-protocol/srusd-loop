// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// interfaces
import {IMorpho, MarketParams} from "./interfaces/IMorpho.sol";
import {ICreditEnforcer} from "./interfaces/ICreditEnforcer.sol";
import {ISavingModule} from "./interfaces/ISavingModule.sol";

// constants
import "./Constants.sol";

// 3rd party libraries
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {console} from "forge-std/console.sol";

contract ReservoirLooper is AccessControl {
    bytes32 public constant MORPHO_ROLE =
        keccak256(abi.encode("reservoir.looper.morpho"));

    IMorpho public morpho = IMorpho(MORPHO_ADDRESS);
    ICreditEnforcer public creditEnforcer =
        ICreditEnforcer(CREDITENFORCER_ADDRESS);
    ISavingModule public savingModule = ISavingModule(SAVINGMODULE_ADDRESS);

    IERC20 public rUSD = IERC20(RUSD_ADDRESS);
    IERC20 public srUSD = IERC20(SRUSD_ADDRESS);

    MarketParams public marketParams;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MORPHO_ROLE, address(morpho));

        marketParams.loanToken = RUSD_ADDRESS;
        marketParams.collateralToken = SRUSD_ADDRESS;
        marketParams.oracle = ORACLE_ADDRESS;
        marketParams.irm = IRM_ADDRESS;
        marketParams.lltv = LLTV;
    }

    /// @notice Redeems `shares` amount of vault shares and burns them immediately.
    /// @dev Always making sure any `underlying` tokens received by the vault are burned and not held
    /// @param _initialAmount amount of srUSD that will be supplied to the market initially
    /// @param _targetAmount amount of srUSD that will be supplied to the market at the end of the loop
    /// @param _ltv percentage of rUSD borrowed against the supplied srUSD (1e18 = 100%)
    function loop(
        uint256 _initialAmount,
        uint256 _targetAmount,
        uint256 _ltv
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        console.log("SRUSD BALANCE: ", srUSD.balanceOf(address(this)));

        srUSD.transferFrom(msg.sender, address(this), _initialAmount);

        srUSD.approve(address(morpho), type(uint256).max);

        console.log("SRUSD BALANCE: ", srUSD.balanceOf(address(this)));

        morpho.supplyCollateral(
            marketParams,
            _initialAmount,
            address(this),
            abi.encode(
                _initialAmount, // amount of srUSD that has been supplied to the market in this loop
                _targetAmount, // target srUSD amount that should be supplied at the end of the loop
                _ltv // loan to value ratio
            )
        );
    }

    function onMorphoSupplyCollateral(
        uint256 assets, // amount of srUSD that has been supplied to the market in the last `supplyCollateral` call
        bytes calldata data
    ) external onlyRole(MORPHO_ROLE) {
        (
            uint256 currentAmount, // amount of srUSD that has been supplied to the market in this loop so far
            uint256 targetAmount, // target srUSD amount that should be supplied at the end of the loop
            uint256 ltv // loan to value ratio
        ) = abi.decode(data, (uint256, uint256, uint256));

        console.log("--------");
        console.log("assets: ", assets);
        console.log("currentAmount: ", currentAmount);
        console.log("targetAmount: ", targetAmount);
        console.log("ltv: ", ltv);
        console.log("--------");

        // target amount has been reached
        if (currentAmount >= targetAmount) return;

        // calculate rusd to borrow based on the ltv and borrow
        uint256 rusdToBorrow = (assets * ltv * savingModule.currentPrice()) /
            1e26;

        // if with this rusdToBorrow amount, we will exceed the target amount, we adjust it and use lower ltv
        if (currentAmount + rusdToBorrow > targetAmount) {
            rusdToBorrow = targetAmount - currentAmount;
            if (rusdToBorrow < 1e18) rusdToBorrow = 1e18;
        }

        morpho.borrow(
            marketParams,
            rusdToBorrow,
            0,
            address(this),
            address(this)
        );

        // swap borrowed rUSD to srUSD
        rUSD.approve(SAVINGMODULE_ADDRESS, rusdToBorrow);
        creditEnforcer.mintSavingcoin(address(this), rusdToBorrow);
        uint256 srusdToSupply = (rusdToBorrow * 1e8) /
            savingModule.currentPrice();

        console.log("SRUSD BALANCE: ", srUSD.balanceOf(address(this)));

        morpho.supplyCollateral(
            marketParams,
            srusdToSupply,
            address(this),
            abi.encode(
                currentAmount + srusdToSupply, // amount of srUSD that has been supplied to the market in this loop so far
                targetAmount, // target srUSD amount that should be supplied at the end of the loop
                ltv // loan to value ratio
            )
        );
    }
}
