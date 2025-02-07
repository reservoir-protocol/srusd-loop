// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface IPegStabilityModule {
    function redeem(address to, uint256 amount) external;
}
