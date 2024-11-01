// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// interfaces
import {IMorpho, MarketParams} from "./interfaces/IMorpho.sol";
import {ICreditEnforcer} from "./interfaces/ICreditEnforcer.sol";

// 3rd party libraries
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract ReservoirLooper is AccessControl {
    bytes32 public constant MORPHO_ROLE =
        keccak256(abi.encode("reservoir.looper.morpho"));

    IMorpho public morpho = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    ICreditEnforcer public creditEnforcer =
        ICreditEnforcer(0x04716DB62C085D9e08050fcF6F7D775A03d07720);

    IERC20 public rUSD = IERC20(0x09D4214C03D01F49544C0448DBE3A27f768F2b34);
    IERC20 public srUSD = IERC20(0x738d1115B90efa71AE468F1287fc864775e23a31);

    MarketParams public marketParams;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MORPHO_ROLE, address(morpho));

        marketParams.loanToken = address(rUSD);
        marketParams.collateralToken = address(srUSD);
        marketParams.oracle = address(0);
        marketParams.irm = address(0);
        marketParams.lltv = 0;
    }

    /// @notice Redeems `shares` amount of vault shares and burns them immediately.
    /// @dev Always making sure any `underlying` tokens received by the vault are burned and not held
    /// @param _initialAmount amount of srUSD that will be supplied to the market initially
    /// @param _targetAmount amount of srUSD that will be supplied to the market at the end of the loop
    /// @param _ltv percentage of rUSD borrowed against the supplied srUSD (1e18 = 100%)
    function loop(
        uint256 _initialAmount,
        uint256 _targetAmount,
        uint8 _ltv
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        srUSD.transferFrom(msg.sender, address(this), _initialAmount);

        srUSD.approve(address(morpho), type(uint256).max);

        morpho.supplyCollateral(
            marketParams,
            _initialAmount,
            address(this),
            abi.encode(0, _targetAmount, _ltv)
        );
    }

    function onMorphoSupplyCollateral(
        uint256 assets,
        bytes calldata data
    ) external onlyRole(MORPHO_ROLE) {
        (uint256 currentAmount, uint256 targetAmount, uint8 ltv) = abi.decode(
            data,
            (uint256, uint256, uint8)
        );

        if (currentAmount >= targetAmount) {
            srUSD.approve(address(morpho), 0);
            return;
        }

        uint256 rusdToBorrow = (assets * ltv) / 1e18;

        morpho.borrow(
            marketParams,
            rusdToBorrow,
            0,
            address(this),
            address(this)
        );

        uint256 srusdToSupply = creditEnforcer.mintSavingcoin(
            address(this),
            targetAmount
        );

        morpho.supplyCollateral(
            marketParams,
            srusdToSupply,
            address(this),
            abi.encode(currentAmount + assets, targetAmount, ltv)
        );
    }
}
