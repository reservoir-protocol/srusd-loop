// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library EventsLib {
    event OpenPosition(
        address indexed account,
        uint256 indexed initialAmount,
        uint256 indexed targetAmount,
        uint256 timestamp
    );

    event ClosePosition(address indexed account, uint256 timestamp);
}
