// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

interface IUsualSP {
    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an insider claims their original allocation.
    /// @param account The address of the insider.
    /// @param amount The amount of tokens claimed.
    event ClaimedOriginalAllocation(address indexed account, uint256 amount);

    /// @notice Emitted when an allocation is removed
    /// @param account The address of the account whose allocation was removed
    event RemovedOriginalAllocation(address indexed account);

    /// @notice Emitted when a new allocation is set.
    /// @param recipients The addresses of the recipients.
    /// @param allocations The allocations of the recipients.
    /// @param allocationStartTimes The allocation start times of the recipients.
    /// @param cliffDurations The cliff durations of the recipients.
    event NewAllocation(
        address[] recipients,
        uint256[] allocations,
        uint256[] allocationStartTimes,
        uint256[] cliffDurations
    );

    /// @notice Emitted when the stake is made
    /// @param account The address of the user.
    /// @param amount The amount of tokens staked.
    event Stake(address account, uint256 amount);

    /// @notice Emitted when the unstake is made
    /// @param account The address of the user.
    /// @param amount The amount of tokens unstaked.
    event Unstake(address account, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice claim UsualS token from allocation
    /// @dev After the cliff period, the owner can claim UsualS token every month during the vesting period
    function claimOriginalAllocation() external;

    /// @notice stake UsualS token to the contract
    /// @param amount the amount of UsualS token to stake
    function stake(uint256 amount) external;

    /// @notice stake UsualS token to the contract with permit
    /// @param amount the amount of UsualS token to stake
    /// @param deadline the deadline of the permit
    /// @param v the v of the permit
    /// @param r the r of the permit
    /// @param s the s of the permit
    function stakeWithPermit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    /// @notice unstake UsualS token from the contract
    /// @param amount the amount of UsualS token to unstake
    function unstake(uint256 amount) external;

    /// @notice claim reward from the contract
    /// @return the amount of reward token claimed
    function claimReward() external returns (uint256);

    /// @notice Allocate UsualSP token to the recipients
    /// @dev Can only be called by the admin
    /// @param recipients the list of recipients
    /// @param originalAllocations the list of allocations
    /// @param allocationStartTimes the list of allocation start times
    /// @param cliffDurations the list of cliffDurations
    function allocate(
        address[] calldata recipients,
        uint256[] calldata originalAllocations,
        uint256[] calldata allocationStartTimes,
        uint256[] calldata cliffDurations
    ) external;

    /// @notice Remove the allocation of UsualSP token from the recipients
    /// @dev Can only be called by the admin
    /// @param recipients the list of recipients
    function removeOriginalAllocation(address[] calldata recipients) external;

    /// @notice Pause the contract, preventing claiming.
    /// @dev Can only be called by the admin.
    function pause() external;

    /// @notice Unpause the contract, allowing claiming.
    /// @dev Can only be called by the admin.
    function unpause() external;

    /// @notice claim every UsualS token from UsualS contract
    /// @dev Can only be called by the admin
    function stakeUsualS() external;

    /// @notice start reward distribution
    /// @dev Can only be called by the distribution module contract
    /// @param amount the amount of reward token to distribute
    /// @param startTime the start time of the reward distribution
    /// @param endTime the end time of the reward distribution
    function startRewardDistribution(uint256 amount, uint256 startTime, uint256 endTime) external;

    /// @notice Returns the liquid allocation of an account.
    /// @param account The address of the account.
    /// @return The liquid allocation.
    function getLiquidAllocation(address account) external view returns (uint256);

    /// @notice Returns the total allocation of an account.
    /// @param account The address of the account.
    /// @return The total allocation.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Returns the total staked amount.
    /// @return The total staked amount.
    function totalStaked() external view returns (uint256);

    /// @notice Returns the vesting duration.
    /// @return The duration.
    function getDuration() external view returns (uint256);

    /// @notice Returns the vesting cliff duration for an insider.
    /// @param insider The address of the insider.
    /// @return The cliff duration of the insider.
    function getCliffDuration(address insider) external view returns (uint256);

    /// @notice Returns the claimable amount of an insider.
    /// @param insider The address of the insider.
    /// @return The claimable amount.
    function getClaimableOriginalAllocation(address insider) external view returns (uint256);

    /// @notice Returns the claimed amount of an insider.
    /// @param insider The address of the insider.
    /// @return The claimed amount.
    function getClaimedAllocation(address insider) external view returns (uint256);

    /// @notice Returns the current reward rate (rewards distributed per second)
    /// @return The reward rate
    function getRewardRate() external view returns (uint256);

    /// @notice Returns the allocation start time of an account.
    /// @param account The address of the account.
    /// @return The allocation start time.
    function getAllocationStartTime(address account) external view returns (uint256);
}
