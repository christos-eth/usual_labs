// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

interface IUsualX {
    /*//////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/

    /// @notice Event emitted when an address is blacklisted
    /// @param account The address that was blacklisted
    event Blacklist(address account);
    /// @notice Event emitted when an address is removed from the blacklist
    /// @param account The address that was removed from the blacklist
    event UnBlacklist(address account);
    /// @notice Event emitted when the withdrawal fee is updated
    /// @param newWithdrawFeeBps The new withdrawal fee in basis points
    event WithdrawFeeUpdated(uint256 newWithdrawFeeBps);
    /// @notice Event emitted when fees are swept
    /// @param caller The address calling the sweep
    /// @param collector The address receiving the fees
    /// @param amount The amount of fees swept
    event FeeSwept(address indexed caller, address indexed collector, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Pauses the contract.
    /// @dev Can be called by the pauser to pause some contract operations.
    function pause() external;

    /// @notice Unpauses the contract.
    /// @dev Can be called by the admin to unpause some contract operations.
    function unpause() external;

    /// @notice  Adds an address to the blacklist.
    /// @dev     Can only be called by the admin.
    /// @param   account  The address to be blacklisted.
    function blacklist(address account) external;

    /// @notice  Removes an address from the blacklist.
    /// @dev     Can only be called by the admin.
    /// @param   account  The address to be removed from the blacklist.
    function unBlacklist(address account) external;

    /// @notice Checks if an address is blacklisted.
    /// @param account The address to check.
    /// @return bool True if the address is blacklisted.
    function isBlacklisted(address account) external view returns (bool);

    /// @notice Starts a new yield distribution period
    /// @dev Can only be called by the distribution contract
    /// @param yieldAmount The amount of yield to distribute
    /// @param startTime The start time of the new yield period
    /// @param endTime The end time of the new yield period
    function startYieldDistribution(uint256 yieldAmount, uint256 startTime, uint256 endTime)
        external;

    /// @notice Updates the withdrawal fee
    /// @dev Can only be called by addresses with WITHDRAW_FEE_UPDATER_ROLE
    /// @param newWithdrawFeeBps The new withdrawal fee in basis points
    function updateWithdrawFee(uint256 newWithdrawFeeBps) external;

    /// @notice Returns the withdrawal fee in basis points
    /// @return The withdrawal fee in basis points
    function withdrawFeeBps() external view returns (uint256);

    /// @notice Deposits assets with permit from msg.sender and mints shares to receiver.
    /// @param assets The amount of assets to deposit.
    /// @param receiver The address receiving the shares.
    /// @param deadline The deadline for the permit.
    /// @param v The recovery id for the permit.
    /// @param r The r value for the permit.
    /// @param s The s value for the permit.
    /// @return shares The amount of shares minted.
    function depositWithPermit(
        uint256 assets,
        address receiver,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /// @notice Deposits assets and mints shares to receiver.
    /// @param assets The amount of assets to deposit.
    /// @param receiver The address receiving the shares.
    /// @return shares The amount of shares minted.
    function deposit(uint256 assets, address receiver) external returns (uint256);

    /// @notice Mints shares to receiver.
    /// @param shares The amount of shares to mint.
    /// @param receiver The address receiving the shares.
    /// @return shares The amount of shares minted.
    function mint(uint256 shares, address receiver) external returns (uint256);

    /// @notice Withdraws assets from owner and sends exactly assets of underlying tokens to receiver,
    /// with the withdrawal fee taken in addition.
    /// @param assets The amount of assets to withdraw.
    /// @param receiver The address receiving the assets.
    /// @param owner The address owning the shares.
    /// @return shares The amount of shares burned.
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);

    /// @notice Redeems shares from owner and sends exactly shares of underlying tokens to receiver,
    /// with the redemption fee taken in addition.
    /// @param shares The amount of shares to redeem.
    /// @param receiver The address receiving the assets.
    /// @param owner The address owning the shares.
    /// @return assets The amount of assets received.
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);

    /// @notice Returns the amount of assets that would be received for a given amount of shares.
    /// @param assets The amount of shares to convert to assets.
    /// @return shares The amount of shares that would be received.
    function previewWithdraw(uint256 assets) external view returns (uint256);

    /// @notice Returns the maximum amount of assets that can be withdrawn by an address.
    /// @param owner The address to check.
    /// @return assets The maximum amount of assets that can be withdrawn.
    function maxWithdraw(address owner) external view returns (uint256);

    /// @notice Returns the amount of assets that would be received for a given amount of shares.
    /// @param shares The amount of shares to convert to assets.
    /// @return assets The amount of assets that would be received.
    function previewRedeem(uint256 shares) external view returns (uint256);

    /// @notice Sweeps fees to the collector.
    /// @return amount The amount of fees swept.
    function sweepFees() external returns (uint256);

    /// @notice Returns the yield rate.
    /// @return yieldRate The yield rate.
    function getYieldRate() external view returns (uint256);

    /// @notice Returns the accumulated fees.
    /// @return accumulatedFees The accumulated fees.
    function getAccumulatedFees() external view returns (uint256);
}
