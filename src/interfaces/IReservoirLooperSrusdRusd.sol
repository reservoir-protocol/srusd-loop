// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface IReservoirLooperSrusdRusd {
    /// @notice Opens a leveraged srUSD position within the srUSD/rUSD Morpho Market
    /// @dev `_targetAmount` should always be more then `_initialAmount`
    /// @dev If one wants to open 10x leverage position, `_targetAmount` should be 10 times more then `_initialAmount`
    /// @param _initialAmount Initial amount of supplied srUSD
    /// @param _targetAmount Target amount of srUSD
    function openPosition(
        uint256 _initialAmount,
        uint256 _targetAmount
    ) external;

    /// @notice Closes a leveraged srUSD position from the srUSD/rUSD Morpho Market
    function closePosition() external;

    /// @notice Reduces the leveraged srUSD position within the srUSD/rUSD Morpho Market with giver collateral amount
    /// @dev Based on the `collateralToWithdraw`, proportional `shares` will be repayed
    /// @param collateralToWithdraw Amount of collateral (srUSD) to withdraw
    /// @return sharesToRepay Amount of shares repayed
    function reducePosition(
        uint256 collateralToWithdraw
    ) external returns (uint256 sharesToRepay);
}
