// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

interface IDistributionModule {
    /*//////////////////////////////////////////////////////////////
                                Structs
    //////////////////////////////////////////////////////////////*/

    struct QueuedOffChainDistribution {
        /// @notice Timestamp of the queued distribution
        uint256 timestamp;
        /// @notice Merkle root of the queued distribution
        bytes32 merkleRoot;
    }

    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a parameter used in the distribution calculations is updated
    /// @param parameterName Name of the parameter
    /// @param newValue New value of the parameter
    event ParameterUpdated(string parameterName, uint256 newValue);

    /// @notice Emitted when tokens are allocated to the off-chain distribution bucket
    /// @param amount Amount of tokens allocated
    event UsualAllocatedForOffChainClaim(uint256 amount);

    /// @notice Emitted when tokens are allocated to the UsualX bucket
    /// @param amount Amount of tokens allocated
    event UsualAllocatedForUsualX(uint256 amount);

    /// @notice Emitted when tokens are allocated to the UsualStar bucket
    /// @param amount Amount of tokens allocated
    event UsualAllocatedForUsualStar(uint256 amount);

    /// @notice Emitted when an off-chain distribution is queued by the distribution operator
    /// @param timestamp Timestamp of the distribution
    /// @param merkleRoot Merkle Root of the off-chain distribution
    event OffChainDistributionQueued(uint256 indexed timestamp, bytes32 merkleRoot);

    /// @notice Emitted when an unchallenged off-chain distribution older than the distribution challenge period is approved
    /// @param timestamp Timestamp of the distribution
    /// @param merkleRoot Merkle Root of the off-chain distribution approved
    event OffChainDistributionApproved(uint256 indexed timestamp, bytes32 merkleRoot);

    /// @notice Emitted when an off-chain distribution is claimed by an account
    /// @param account Account that claimed the tokens
    /// @param amount Amount of tokens claimed
    event OffChainDistributionClaimed(address indexed account, uint256 amount);

    /// @notice Emitted when the off-chain distribution queue is reset
    event OffChainDistributionQueueReset();

    /// @notice Emitted when an off-chain distribution is challenged
    /// @param timestamp Timestamp of the challenged distribution
    event OffChainDistributionChallenged(uint256 indexed timestamp);

    /// @notice Emitted when the daily distribution rates are provided
    /// @param ratet Rate at time t
    /// @param p90Rate 90th percentile rate
    event DailyDistributionRates(uint256 ratet, uint256 p90Rate);

    /// @notice Emitted when an off-chain distribution is claimed and redirected by an account
    /// @param redirectedAccount Account that claimed the tokens
    /// @param redirectRecipient Account that received the redirected tokens
    /// @param amount Amount of tokens claimed
    event OffChainDistributionClaimedAndRedirected(
        address indexed redirectedAccount, address indexed redirectRecipient, uint256 amount
    );

    /// @notice Emitted when an off-chain distribution redirection is initialized
    /// @param account Account that initiated the redirection
    /// @param newAccount Account that will receive the redirected tokens
    /// @param startingTimestamp Timestamp of the redirection starting time
    event OffChainDistributionRedirectInitialized(
        address account, address newAccount, uint256 startingTimestamp
    );

    /// @notice Emitted when an off-chain distribution redirection is accepted after the challenge period
    /// @param account Account that will be redirected
    /// @param newAccount Account that will receive the redirected tokens
    event OffChainDistributionRedirectedAccepted(address account, address newAccount);

    /// @notice Emitted when an off-chain distribution redirection is cancelled
    /// @param account Account that would have been redirected
    /// @param newAccount Account that would have received the redirected tokens
    event OffChainDistributionRedirectedCancelled(address account, address newAccount);

    /// @notice Emitted when an off-chain distribution redirection is removed
    /// @param account Account that was redirected
    event OffChainDistributionRedirectedRemoved(address account);

    /// @notice Emitted when the fee rates are set
    /// @param treasuryFeeRate Rate of fee to send to yield treasury
    /// @param usualXFeeRate Rate of fee to send to UsualX
    /// @param burnFeeRate Rate of fee to burn
    event FeeRatesSet(uint256 treasuryFeeRate, uint256 usualXFeeRate, uint256 burnFeeRate);

    /// @notice Emitted when the fee is allocated to be sent to UsualX
    /// @param feeAmount Amount of fee allocated
    event UsualFeeAllocatedToUsualX(uint256 feeAmount);

    /// @notice Emitted when the fee is allocated to be sent to yield treasury
    /// @param feeAmount Amount of fee allocated
    event UsualFeeAllocatedToYieldTreasury(uint256 feeAmount);

    /// @notice Emitted when the fee is allocated to be burned
    /// @param feeAmount Amount of fee allocated
    event UsualFeeBurned(uint256 feeAmount);

    /*//////////////////////////////////////////////////////////////
                                Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Pauses the contract
    /// @dev Can only be called by the PAUSING_CONTRACTS_ROLE
    function pause() external;

    /// @notice Unpauses the contract
    /// @dev Can only be called by the DEFAULT_ADMIN_ROLE
    function unpause() external;

    /// @notice Returns the current buckets distribution percentage for the Usual token emissions (in basis points)
    /// @return lbt LBT bucket percentage
    /// @return lyt LYT bucket percentage
    /// @return iyt IYT bucket percentage
    /// @return bribe Bribe bucket percentage
    /// @return eco Eco bucket percentage
    /// @return dao DAO bucket percentage
    /// @return marketMakers MarketMakers bucket percentage
    /// @return usualP UsualP bucket percentage
    /// @return usualStar UsualStar bucket percentage
    function getBucketsDistribution()
        external
        view
        returns (
            uint256 lbt,
            uint256 lyt,
            uint256 iyt,
            uint256 bribe,
            uint256 eco,
            uint256 dao,
            uint256 marketMakers,
            uint256 usualP,
            uint256 usualStar
        );

    /// @notice Calculates the St value
    /// @dev Raw equation: St = min((supplyPp0 * p0) / (supplyPpt * pt), 1)
    /// @param supplyPpt Current supply (scaled by SCALAR_ONE)
    /// @param pt Current price (scaled by SCALAR_ONE)
    /// @return St value (scaled by SCALAR_ONE)
    function calculateSt(uint256 supplyPpt, uint256 pt) external view returns (uint256);

    /// @notice Calculates the Rt value
    /// @dev Raw equation: Rt = min( max(ratet, rateMin), p90Rate ) / rate0
    /// @return Rt value (scaled by SCALAR_ONE)
    function calculateRt() external view returns (uint256);

    /// @notice Calculates the Kappa value
    /// @dev Raw equation: Kappa = m_0*max(rate_t[i],rate_min)/rate_0
    /// @return Kappa value (scaled by SCALAR_ONE)
    function calculateKappa() external view returns (uint256);

    /// @notice Calculates the Gamma value
    /// @return Gamma value (scaled by SCALAR_ONE)
    function calculateGamma() external view returns (uint256);

    /// @notice Calculates the Mt value
    /// @dev Raw equation: Mt = min((m0 * St * Rt)/gamma, kappa)
    /// @param st St value (scaled by SCALAR_ONE)
    /// @param rt Rt value (scaled by SCALAR_ONE)
    /// @param kappa Kappa value (in basis points)
    /// @return Mt value (scaled by SCALAR_ONE)
    function calculateMt(uint256 st, uint256 rt, uint256 kappa) external view returns (uint256);

    /// @notice Calculates all values: St, Rt, Mt, and UsualDist
    /// @return st St value (scaled by SCALAR_ONE)
    /// @return rt Rt value (scaled by SCALAR_ONE)
    /// @return kappa Kappa value (scaled by SCALAR_ONE)
    /// @return mt Mt value (scaled by SCALAR_ONE)
    /// @return usualDist UsualDist value (raw, not scaled)
    function calculateUsualDist()
        external
        view
        returns (uint256 st, uint256 rt, uint256 kappa, uint256 mt, uint256 usualDist);

    /// @notice Claims the Usual token distribution for the given account
    /// @dev If a given account has been redirected, the respective redirected account will receive the distribution instead
    /// @param account The account to claim for
    /// @param amount Total amount of Usual token rewards earned by the account up to this point
    /// @param proof Merkle proof
    function claimOffChainDistribution(address account, uint256 amount, bytes32[] calldata proof)
        external;

    /// @notice Redirects the off-chain distribution for the given account to a new account
    /// @dev This function can only be called by the redirection-admin-role
    /// @dev If the account is already redirected, the function will revert
    /// @dev Redirects cannot be daisy-chained.
    /// @param account The account to redirect
    /// @param newAccount The new account to redirect to
    function redirectOffChainDistribution(address account, address newAccount) external;

    /// @notice Challenges the redirected off-chain distribution for the given account
    /// @dev This function can only be called by the account that has been redirected OR the redirection-admin-role
    /// @param account The account to challenge
    function cancelInitiatedRedirectedOffChainDistribution(address account) external;

    /// @notice Accepts the redirected off-chain distribution for the given account
    /// @param account The redirected account to accept
    function acceptRedirectedOffChainDistribution(address account) external;

    /// @notice Removes the redirected off-chain distribution for the given account
    /// @param account The redirected account to remove
    function removeRedirectedOffChainDistribution(address account) external;

    /// @notice Returns the current off-chain distribution data
    /// @return timestamp Timestamp of the latest unchallanged distribution
    /// @return merkleRoot Merkle root of the latest unchallanged distribution
    function getOffChainDistributionData()
        external
        view
        returns (uint256 timestamp, bytes32 merkleRoot);

    /// @notice Returns the amount of Usual token claimed off-chain by the account up to this point
    /// @param account The account to check
    /// @return amount Amount of Usual token claimed off-chain
    function getOffChainTokensClaimed(address account) external view returns (uint256 amount);

    /// @notice Returns the off-chain distribution queue
    /// @return QueuedOffChainDistribution[] Array of queued off-chain distributions
    function getOffChainDistributionQueue()
        external
        view
        returns (QueuedOffChainDistribution[] memory);

    /// @notice Returns maximum amount of Usual token that can be distributed off-chain
    /// @return amount Maximum amount of Usual token that can be distributed off-chain
    function getOffChainDistributionMintCap() external view returns (uint256 amount);

    /// @notice Returns the timestamp of the last on-chain distribution
    /// @return timestamp Timestamp of the last on-chain distribution
    function getLastOnChainDistributionTimestamp() external view returns (uint256 timestamp);

    /// @notice Approve the latest queue merkle root that is unchallenged and older than challenge period.
    /// @dev Every queued merkle root older than challenge period will be removed.
    function approveUnchallengedOffChainDistribution() external;

    /// @notice Returns the account that has initiated a redirection challenge for a given account
    /// @param account The account to check
    /// @return redirectedAccount The account that initiated the redirection challenge
    function getInitiatedRedirectedOffChainDistribution(address account)
        external
        view
        returns (address redirectedAccount);

    /// @notice Returns the timestamp of the ongoing redirection challenge for a given account
    /// @param account The account to check
    /// @return timestamp The timestamp when the redirection challenge started
    function getOngoingRedirectionChallenge(address account)
        external
        view
        returns (uint256 timestamp);

    /// @notice Returns the account that has been redirected to for a given account
    /// @param account The account to check
    /// @return redirectedAccount The account that the distribution is redirected to
    function getRedirectedAccount(address account)
        external
        view
        returns (address redirectedAccount);

    /// @notice Updates the iUsd0ppVault address
    /// @dev This function can only be called by an address with the VAULT_UPDATER_ROLE.
    /// @param newVault The address of the new iUsd0ppVault. Must not be the same value.
    function updateIUsd0ppVault(address newVault) external;

    /// @notice Returns the current iUsd0ppVault address
    /// @return The address of the current iUsd0ppVault
    function getIUsd0ppVault() external view returns (address);
}
