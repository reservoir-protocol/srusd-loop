// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ICreditEnforcer {
    function mintSavingcoin(
        address to,
        uint256 amount
    ) external returns (uint256);
}
