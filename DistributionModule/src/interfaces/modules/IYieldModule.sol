// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {IAggregator} from "src/interfaces/oracles/IAggregator.sol";

interface IYieldModule {
    struct YieldSourceData {
        uint256 lastUpdated; // Last time we updated the rate (block.timestamp)
        uint256 weeklyInterestBps; // Weekly interest rate in basis points
        IAggregator feed; // If using Chainlink aggregator, store it
    }

    /// @notice Adds a new yield source with a Chainlink data feed
    /// @param asset Address of the asset for this yield source
    /// @param feedAddress Chainlink data feed address
    function addYieldSourceWithFeed(address asset, address feedAddress) external;

    /// @notice Adds a new yield source with a weekly interest rate (manual)
    /// @param asset Address of the asset for this yield source
    /// @param weeklyInterestBps Interest rate in basis points (weekly)
    function addYieldSourceWithWeeklyInterest(address asset, uint256 weeklyInterestBps) external;

    /// @notice Removes a yield source
    /// @param asset Address of the asset for this yield source
    function removeYieldSource(address asset) external;

    /// @notice Updates the interest rate for a yield source
    /// @param asset Address of the asset for this yield source
    /// @param weeklyInterestBps Interest rate in basis points (weekly)
    function updateInterestRate(address asset, uint256 weeklyInterestBps) external;

    /// @notice Remove a treasury address
    /// @param treasury address of the treasury
    function removeTreasury(address treasury) external;

    /// @notice Adds a new treasury address
    /// @param treasury address of the treasury
    function addTreasury(address treasury) external;

    /// @notice Updates the Chainlink data feed for a yield source
    /// @param asset Address of the asset for this yield source
    /// @param feedAddress Chainlink data feed address
    function updateFeed(address asset, address feedAddress) external;

    /// @notice Sets the maximum data age for the RWA data
    /// @param maxDataAge The maximum data age in seconds
    function setMaxDataAge(uint256 maxDataAge) external;

    /// @notice Sets the P90 interest rate
    /// @param p90Rate The P90 interest rate in basis points
    function setP90InterestRate(uint256 p90Rate) external;

    /// @notice Returns the maximum data age
    /// @return maxDataAge The maximum data age
    function getMaxDataAge() external view returns (uint256);

    /// @notice Returns the blended weekly interest rate
    /// @dev Rate values are in basis points (1 = 0.01%)
    /// @return blendedWeeklyRateBps The blended weekly interest rate
    function getBlendedWeeklyInterest() external view returns (uint256 blendedWeeklyRateBps);

    /// @notice Returns the interest rates 90th percentile of the last 60 days.
    /// @dev Rate values are in basis points (1 = 0.01%)
    /// @return P90 rate in basis points
    function getP90InterestRate() external view returns (uint256);

    /// @notice Returns the RWA data for a given RWA ID
    /// @param asset The address of the asset
    /// @return yieldSourceData The yield source data
    function getYieldSource(address asset) external view returns (YieldSourceData memory);

    /// @notice Returns the number of yield source data entries
    /// @return length The number of yield source data entries
    function getYieldSourceCount() external view returns (uint256);

    /// @notice Returns all yield source data entries
    /// @return yieldSourceData The yield source data entries
    function getAllYieldSourceData() external view returns (YieldSourceData[] memory);

    /// @notice Returns the number of treasury addresses
    /// @return length The number of treasury addresses
    function getTreasuryCount() external view returns (uint256);

    /// @notice Returns all treasury addresses
    /// @return treasury The treasury addresses
    function getAllTreasury() external view returns (address[] memory);
}
