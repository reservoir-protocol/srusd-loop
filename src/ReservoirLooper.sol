// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// reservoir interfaces
import {ICreditEnforcer} from "./interfaces/ICreditEnforcer.sol";
import {ISavingModule} from "./interfaces/ISavingModule.sol";

// constants
import "./Constants.sol";

// open-zeppelin
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// morpho-blue
import {MarketParamsLib} from "morpho-blue/src/libraries/MarketParamsLib.sol";
import {IMorpho, Market, Position, MarketParams, Id} from "morpho-blue/src/interfaces/IMorpho.sol";

import {console} from "forge-std/console.sol";

contract ReservoirLooper is AccessControl {
    using MarketParamsLib for MarketParams;
    using SafeERC20 for IERC20;

    bytes32 public constant MORPHO_ROLE =
        keccak256(abi.encode("reservoir.looper.morpho"));
    bytes32 public constant WHITELIST =
        keccak256(abi.encode("reservoir.looper.whitelist"));

    IMorpho public morpho = IMorpho(MORPHO_ADDRESS);
    ICreditEnforcer public creditEnforcer =
        ICreditEnforcer(CREDITENFORCER_ADDRESS);
    ISavingModule public savingModule = ISavingModule(SAVINGMODULE_ADDRESS);

    IERC20 public rUSD = IERC20(RUSD_ADDRESS);
    IERC20 public srUSD = IERC20(SRUSD_ADDRESS);

    MarketParams public marketParams;
    Id public immutable MARKET_ID;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MORPHO_ROLE, address(morpho));

        marketParams.loanToken = RUSD_ADDRESS;
        marketParams.collateralToken = SRUSD_ADDRESS;
        marketParams.oracle = ORACLE_ADDRESS;
        marketParams.irm = IRM_ADDRESS;
        marketParams.lltv = LLTV;

        MARKET_ID = marketParams.id();
    }

    /******************************************
     * HIGH LEVEL FUNCTIONS
     ******************************************/

    function openPosition(
        uint256 _initialAmount,
        uint256 _targetAmount
    ) external onlyRole(WHITELIST) {
        srUSD.safeTransferFrom(msg.sender, address(this), _initialAmount);

        morpho.supplyCollateral(
            marketParams,
            _targetAmount,
            msg.sender,
            abi.encode(msg.sender, _initialAmount)
        );
    }

    function closePosition() external onlyRole(WHITELIST) {
        Position memory position = morpho.position(MARKET_ID, msg.sender);

        morpho.repay(
            marketParams,
            0,
            position.borrowShares,
            msg.sender,
            abi.encode(msg.sender, position.collateral)
        );
    }

    /******************************************
     * MORPHO FUNCTIONS
     ******************************************/

    function onMorphoSupplyCollateral(
        uint256 assets,
        bytes calldata data
    ) external onlyRole(MORPHO_ROLE) {
        (address user, uint256 initialAmount) = abi.decode(
            data,
            (address, uint256)
        );

        // Amount of srusd to mint to satisfy `supplyCollateral` after the callback
        uint256 srUSDToMint = assets - initialAmount;

        uint256 rusdToBorrow = previewToRUSD(srUSDToMint);

        morpho.borrow(marketParams, rusdToBorrow, 0, user, address(this));

        rUSD.approve(SAVINGMODULE_ADDRESS, rusdToBorrow);

        creditEnforcer.mintSavingcoin(address(this), rusdToBorrow);

        srUSD.approve(address(morpho), assets);
    }

    function onMorphoRepay(
        uint256 rusdToRepay,
        bytes calldata data
    ) external onlyRole(MORPHO_ROLE) {
        (address user, uint256 srUSDAmount) = abi.decode(
            data,
            (address, uint256)
        );

        morpho.withdrawCollateral(
            marketParams,
            srUSDAmount,
            user,
            address(this)
        );

        uint256 rusdToGet = previewToRUSD(srUSDAmount);
        srUSD.approve(SAVINGMODULE_ADDRESS, srUSDAmount);
        savingModule.redeem(rusdToGet);

        uint256 rusdToSendToUser = rusdToGet - rusdToRepay;

        rUSD.approve(SAVINGMODULE_ADDRESS, rusdToSendToUser);

        uint256 srusdAmountToSend = previewToSrUSD(rusdToSendToUser);

        creditEnforcer.mintSavingcoin(address(this), rusdToSendToUser);

        srUSD.safeTransfer(user, srusdAmountToSend);

        rUSD.approve(MORPHO_ADDRESS, rusdToRepay);
    }

    /******************************************
     * FUND RECOVERY FUNCTIONS
     ******************************************/

    function recover(
        IERC20 token,
        address to
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token.safeTransfer(to, token.balanceOf(address(this)));
    }

    function recover(
        IERC20 token,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token.safeTransfer(to, amount);
    }

    function recoverETH(
        address payable to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount <= address(this).balance, "Insufficient balance");
        to.transfer(amount);
    }

    function approve(
        IERC20 token,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token.approve(to, amount);
    }

    /******************************************
     * PREVIEW PRICE FUNCTIONS
     ******************************************/

    function previewToSrUSD(
        uint256 _rusdAmount
    ) public view returns (uint256 _srusdAmount) {
        _srusdAmount = (_rusdAmount * 1e8) / savingModule.currentPrice();
    }

    function previewToRUSD(
        uint256 _srusdAmount
    ) public view returns (uint256 _rusdAmount) {
        _rusdAmount = (_srusdAmount * savingModule.currentPrice()) / 1e8;
    }
}
