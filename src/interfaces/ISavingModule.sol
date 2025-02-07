// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface ISavingModule {
    function currentPrice() external view returns (uint256 _price);

    function redeem(uint256 amount) external;

    function redeem(address to, uint256 amount) external;

    function redeemFee() external view returns (uint256);

    function previewRedeem(
        uint256 rusdAmount
    ) external view returns (uint256 srusdAmount);
}
