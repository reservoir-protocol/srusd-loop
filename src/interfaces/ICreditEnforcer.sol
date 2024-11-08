// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface ICreditEnforcer {
    function mintSavingcoin(
        address to,
        uint256 amount
    ) external returns (uint256);

    // ------ Functions needed for setting up the test environment ------

    function setSMDebtMax(uint256 smDebtMax_) external;

    function setAssetRatioMin(uint256 assetRatioMin_) external;

    function setEquityRatioMin(uint256 equityRatioMin_) external;

    function setLiquidityRatioMin(uint256 liquidityRatioMin_) external;
}
