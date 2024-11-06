// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ISavingModule {
    function currentPrice() external view returns (uint256 _price);

    function redeem(uint256 amount) external;

    function previewRedeem(
        uint256 rusdAmount
    ) external view returns (uint256 srusdAmount);
}
