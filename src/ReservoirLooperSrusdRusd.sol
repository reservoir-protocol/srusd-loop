// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IReservoirLooperSrusdRusd} from "./interfaces/IReservoirLooperSrusdRusd.sol";

// reservoir interfaces
import {ICreditEnforcer} from "./interfaces/ICreditEnforcer.sol";
import {ISavingModule} from "./interfaces/ISavingModule.sol";
import {IPegStabilityModule} from "./interfaces/IPegStabilityModule.sol";

// libraries
import "./libraries/ConstantsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

// open-zeppelin
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// morpho-blue
import {MarketParamsLib} from "morpho-blue/src/libraries/MarketParamsLib.sol";
import {IMorpho, Market, Position, MarketParams, Id} from "morpho-blue/src/interfaces/IMorpho.sol";

contract ReservoirLooperSrusdRusd is IReservoirLooperSrusdRusd, AccessControl {
    using MarketParamsLib for MarketParams;
    using SafeERC20 for IERC20;
    // --- Roles --- //
    bytes32 public constant MORPHO_ROLE = keccak256("MORPHO_ROLE");
    bytes32 public constant WHITELIST = keccak256("WHITELSIT_ROLE");

    // --- External Contracts --- //
    IMorpho public morpho = IMorpho(MORPHO_ADDRESS);
    ICreditEnforcer public creditEnforcer =
        ICreditEnforcer(CREDITENFORCER_ADDRESS);
    IPegStabilityModule public psm = IPegStabilityModule(PSM_ADDRESS);
    ISavingModule public savingModule = ISavingModule(SAVINGMODULE_ADDRESS);
    IERC20 public rUSD = IERC20(RUSD_ADDRESS);
    IERC20 public srUSD = IERC20(SRUSD_ADDRESS);

    // --- Morpho Market Info --- //
    MarketParams public marketParams;
    Id public immutable MARKET_ID;

    // --- CONSTRUCTOR --- //

    constructor(address _admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MORPHO_ROLE, MORPHO_ADDRESS);

        marketParams.loanToken = RUSD_ADDRESS;
        marketParams.collateralToken = SRUSD_ADDRESS;
        marketParams.oracle = SRUSD_RUSD_ORACLE_ADDRESS;
        marketParams.irm = SRUSD_RUSD_IRM_ADDRESS;
        marketParams.lltv = SRUSD_RUSD_LLTV;

        MARKET_ID = marketParams.id();
    }

    /******************************************
     * HIGH LEVEL FUNCTIONS
     ******************************************/

    /// @inheritdoc IReservoirLooperSrusdRusd
    function openPosition(
        uint256 _initialAmount,
        uint256 _targetAmount
    ) external onlyRole(WHITELIST) {
        require(
            _targetAmount > _initialAmount,
            ErrorsLib.INVALID_TARGET_AMOUNT
        );

        srUSD.safeTransferFrom(msg.sender, address(this), _initialAmount);

        morpho.supplyCollateral(
            marketParams,
            _targetAmount,
            msg.sender,
            abi.encode(msg.sender, _initialAmount)
        );

        emit EventsLib.OpenPosition(
            msg.sender,
            _initialAmount,
            _targetAmount,
            block.timestamp
        );
    }

    /// @inheritdoc IReservoirLooperSrusdRusd
    function reducePosition(
        uint256 collateralToWithdraw
    ) external onlyRole(WHITELIST) returns (uint256 sharesToRepay) {
        Position memory position = morpho.position(MARKET_ID, msg.sender);

        // always repay the proportionate amount of debt in correlation to the collateral withdrawn
        sharesToRepay =
            (collateralToWithdraw * position.borrowShares) /
            position.collateral;

        morpho.repay(
            marketParams,
            0,
            sharesToRepay,
            msg.sender,
            abi.encode(msg.sender, collateralToWithdraw)
        );

        emit EventsLib.ClosePosition(msg.sender, block.timestamp);
    }

    /// @inheritdoc IReservoirLooperSrusdRusd
    function closePosition() external onlyRole(WHITELIST) {
        Position memory position = morpho.position(MARKET_ID, msg.sender);

        morpho.repay(
            marketParams,
            0,
            position.borrowShares,
            msg.sender,
            abi.encode(msg.sender, position.collateral)
        );

        emit EventsLib.ClosePosition(msg.sender, block.timestamp);
    }

    /******************************************
     * MORPHO CALLBACKS
     ******************************************/

    /// @dev Callback function for Morpho's `supplyCollateral`
    function onMorphoSupplyCollateral(
        uint256 targetAmount,
        bytes calldata data
    ) external onlyRole(MORPHO_ROLE) {
        (address user, uint256 initialAmount) = abi.decode(
            data,
            (address, uint256)
        );

        // Amount of srusd to mint to satisfy `supplyCollateral` after the callback
        uint256 srUSDToMint = targetAmount - initialAmount;

        uint256 rusdToBorrow = getRusdAmountToMintProvidedSrusdAmount(
            srUSDToMint
        );

        morpho.borrow(marketParams, rusdToBorrow, 0, user, address(this));

        _mintSrUSD(rusdToBorrow);

        srUSD.approve(address(morpho), targetAmount);
    }

    /// @dev Callback function for Morpho's `repay`
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

        uint256 rusdToGet = _mintRUSD(srUSDAmount);

        uint256 rusdToSendToUser = rusdToGet - rusdToRepay;

        uint256 srusdAmountToSend = _mintSrUSD(rusdToSendToUser);

        srUSD.safeTransfer(user, srusdAmountToSend);

        rUSD.approve(MORPHO_ADDRESS, rusdToRepay);
    }

    /******************************************
     * RECOVERY FUNCTIONS
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
        require(
            amount <= address(this).balance,
            ErrorsLib.INSUFFICIENT_ETH_BALANCE
        );
        to.transfer(amount);
    }

    function approve(
        IERC20 token,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token.approve(to, amount);
    }

    function setMorphoAuthorization(
        address to
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        morpho.setAuthorization(to, true);
    }

    function removeMorphoAuthorization(
        address to
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        morpho.setAuthorization(to, false);
    }

    /******************************************
     * PREVIEW PRICE FUNCTIONS
     ******************************************/

    function getRusdAmountToMintProvidedSrusdAmount(
        uint256 _srusdAmount
    ) public view returns (uint256 _rusdAmount) {
        _rusdAmount = (_srusdAmount * savingModule.currentPrice()) / 1e8;
    }

    function getMintedSrusdAmountWithProvidedRusdAmount(
        uint256 _rusdAmount
    ) public view returns (uint256 _srusdAmount) {
        _srusdAmount = (_rusdAmount * 1e8) / savingModule.currentPrice();
    }

    function getMintedRusdAmountWithProvidedSrusdAmount(
        uint256 _srusdAmount
    ) public view returns (uint256 _rusdAmount) {
        _rusdAmount =
            (_srusdAmount * savingModule.currentPrice() * 1e6) /
            (1e8 * (1e6 + savingModule.redeemFee()));
    }

    /******************************************
     * INTERNAL FUNCTIONS
     ******************************************/

    function _mintSrUSD(
        uint256 _rusdAmount
    ) internal returns (uint256 _srusdAmount) {
        rUSD.approve(SAVINGMODULE_ADDRESS, _rusdAmount);

        _srusdAmount = getMintedSrusdAmountWithProvidedRusdAmount(_rusdAmount);

        creditEnforcer.mintSavingcoin(address(this), _rusdAmount);
    }

    function _mintRUSD(
        uint256 _srusdAmount
    ) internal returns (uint256 _rusdAmount) {
        srUSD.approve(SAVINGMODULE_ADDRESS, _srusdAmount);

        _rusdAmount = getMintedRusdAmountWithProvidedSrusdAmount(_srusdAmount);

        savingModule.redeem(_rusdAmount);
    }
}
