// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface IReservoirLooper {
    /// @notice Opens a leveraged srUSD position within a Morpho Market
    /// @dev `_targetAmount` should always be more then `_initialAmount`
    /// @dev If one wants to open 10x leverage position, `_targetAmount` should be 10 times more then `_initialAmount`
    /// @param _initialAmount Initial amount of supplied srUSD
    /// @param _targetAmount Target amount of srUSD
    function openPosition(
        uint256 _initialAmount,
        uint256 _targetAmount
    ) external;

    /// @notice Closes a leveraged srUSD position from a Morpho Market
    function closePosition() external;

    /// @notice Returns the amount of srUSD minted from the given amount of rUSD
    /// @param _rusdAmount Amount of rUSD
    /// @return _srusdAmount Amount of srUSD
    function previewToSrUSD(
        uint256 _rusdAmount
    ) external view returns (uint256 _srusdAmount);

    /// @notice Returns the amount of rUSD minted from the given amount of srUSD
    /// @param _srusdAmount Amount of srUSD
    /// @return _rusdAmount Amount of rUSD
    function previewToRUSD(
        uint256 _srusdAmount
    ) external view returns (uint256 _rusdAmount);
}
