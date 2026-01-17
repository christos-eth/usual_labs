// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

interface IDistributionOperator {
    /// @notice Distribute Usual token emissions to on-chain and off-chainbuckets based on interest rates and treasury values.
    /// @dev Can be only called by the DISTRIBUTION_OPERATOR role, once per 24 hours.
    function distributeUsualToBuckets() external;

    /// @notice Queue a merkle root that allows off-chain distribution of Usual token to be claimed.
    /// @param _merkleRoot Merkle root of the distribution point
    /// @dev Can be only called by the DISTRIBUTION_OPERATOR role
    function queueOffChainUsualDistribution(bytes32 _merkleRoot) external;

    /// @notice Resets off-chain distribution queue.
    /// @dev Can be only called by the DISTRIBUTION_OPERATOR role
    /// @dev Every queued merkle root will be removed.
    function resetOffChainDistributionQueue() external;
}
