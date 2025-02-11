// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface IReservoirLooperSrusdUsdc {
    /// @notice Opens a leveraged srUSD position within the srUSD/USDC Morpho Market
    /// @dev `_targetAmount` should always be more then `_initialAmount`
    /// @dev If one wants to open 10x leverage position, `_targetAmount` should be 10 times more then `_initialAmount`
    /// @param _initialAmount Initial amount of supplied srUSD
    /// @param _targetAmount Target amount of srUSD
    function openPosition(
        uint256 _initialAmount,
        uint256 _targetAmount
    ) external;

    /// @notice Closes a leveraged srUSD position from the srUSD/USDC Morpho Market
    function closePosition() external;

    /// @notice Reduces the leveraged srUSD position within the srUSD/USDC Morpho Market with giver collateral amount
    /// @dev Based on the `collateralToWithdraw`, proportional `shares` will be repayed
    /// @param collateralToWithdraw Amount of collateral (srUSD) to withdraw
    /// @return sharesToRepay Amount of shares repayed
    function reducePosition(
        uint256 collateralToWithdraw
    ) external returns (uint256 sharesToRepay);

    /// @notice Returns the amount of srUSD minted from the given amount of rUSD
    /// @param _rusdAmount Amount of rUSD
    /// @return _srusdAmount Amount of srUSD
    function getMintedSrusdAmountWithProvidedRusdAmount(
        uint256 _rusdAmount
    ) external view returns (uint256 _srusdAmount);

    /// @notice Returns the amount of rUSD that will be required to mint the given amount of srUSD
    /// @param _srusdAmount Amount of srUSD
    /// @return _rusdAmount Amount of rUSD
    function getRusdAmountToMintProvidedSrusdAmount(
        uint256 _srusdAmount
    ) external view returns (uint256 _rusdAmount);

    /// @notice Returns the amount of rUSD that will be minted when given amount of srUSD is burned
    /// @param _srusdAmount Amount of srUSD
    /// @return _rusdAmount Amount of rUSD
    function getMintedRusdAmountWithProvidedSrusdAmount(
        uint256 _srusdAmount
    ) external view returns (uint256 _rusdAmount);
}
