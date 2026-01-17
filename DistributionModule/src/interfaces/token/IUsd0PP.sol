// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Approval as PermitApproval} from "src/interfaces/IDaoCollateral.sol";

interface IUsd0PP is IERC20Metadata {
    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a bond is unwrapped.
    /// @param user The address of the user unwrapping the bond.
    /// @param amount The amount of the bond unwrapped.
    event BondUnwrapped(address indexed user, uint256 amount);

    /// @notice Emitted when a bond is unwrapped during the temporary unlock period.
    /// @param user The address of the user unwrapping the bond.
    /// @param amount The amount of the bond unwrapped.
    event BondUnwrappedDuringEarlyUnlock(address indexed user, uint256 amount);

    /// @notice Event emitted when a bond is early redeemed
    /// @param user The address of the user early redeeming the bond
    /// @param usd0ppAmount The amount of USD0++ early redeemed
    event BondUnwrappedEarlyWithUsualBurn(address indexed user, uint256 usd0ppAmount);

    /// @notice Emitted when the PAR mechanism is triggered
    /// @param user The address of the caller triggering the mechanism
    /// @param amount The amount of USD0 supplied to the Curvepool to return to PAR.
    event PARMechanismActivated(address indexed user, uint256 amount);

    /// @notice Emitted when an emergency withdrawal occurs.
    /// @param account The address of the account initiating the emergency withdrawal.
    /// @param balance The balance withdrawn.
    event EmergencyWithdraw(address indexed account, uint256 balance);

    /// @notice Emitted when an address temporary redemption is disabled.
    /// @param user The address of the user being disabled for temporary redemptions.
    event BondEarlyUnlockDisabled(address indexed user);

    /// @notice Event emitted when the floor price is updated
    /// @param newFloorPrice The new floor price value
    event FloorPriceUpdated(uint256 newFloorPrice);

    /// @notice Event emitted when USD0++ is unlocked to USD0
    /// @param user The address of the user unlocking USD0++
    /// @param usd0ppAmount The amount of USD0++ unlocked
    /// @param usd0Amount The amount of USD0 received
    event Usd0ppUnlockedFloorPrice(address indexed user, uint256 usd0ppAmount, uint256 usd0Amount);

    /// @notice Event emitted when the early unlock balances are set.
    /// @param addressesToAllocateTo The addresses to allocate the balances to.
    /// @param earlyUnlockBalances The early unlock balances to allocate.
    event EarlyUnlockBalancesSet(address[] addressesToAllocateTo, uint256[] earlyUnlockBalances);

    /// @notice Event emitted when the early unlock period is set.
    /// @param earlyUnlockStart The start of the early unlock period.
    /// @param earlyUnlockEnd The end of the early unlock period.
    event EarlyUnlockPeriodSet(uint256 earlyUnlockStart, uint256 earlyUnlockEnd);

    /// @notice Emitted when an unwrap cap is set for an address
    /// @param user The address of the user setting the unwrap cap
    /// @param cap The unwrap cap
    event UnwrapCapSet(address indexed user, uint256 cap);

    /// @notice Emitted when USD0++ is unwrapped by a USD0PP_CAPPED_UNWRAP_ROLE address
    /// @param user The address of the user unwrapping the bond
    /// @param amount The amount of USD0++ unwrapped
    /// @param remainingAllowance The remaining allowance of the user
    event CappedUnwrap(address indexed user, uint256 amount, uint256 remainingAllowance);

    /// @notice Event emitted when the daily USD0++ inflow is updated
    /// @param dayIndex Index of the day (unix timestamp / seconds per day)
    /// @param amount The amount of USD0++ inflow
    event DailyUsd0ppInflowUpdated(uint256 dayIndex, uint256 amount);

    /// @notice Event emitted when the daily USD0++ outflow is updated
    /// @param dayIndex Index of the day (unix timestamp / seconds per day)
    /// @param amount The amount of USD0++ outflow
    event DailyUsd0ppOutflowUpdated(uint256 dayIndex, uint256 amount);

    /// @notice Event emitted when the USUAL distribution rate is set
    /// @param newRate The new USUAL distribution rate
    event UsualDistributionPerUsd0ppSet(uint256 newRate);

    /// @notice Event emitted when the duration cost factor is set
    /// @param newFactor The new duration cost factor
    event DurationCostFactorSet(uint256 newFactor);

    /// @notice Event emitted when the target redemption rate is set
    /// @param newRate The new target redemption rate
    event TargetRedemptionRateSet(uint256 newRate);

    // @notice Event emitted when fees are swept
    // @param caller The address calling the sweep
    // @param collector The address receiving the fees
    // @param amount The amount of fees swept
    event FeeSwept(address indexed caller, address indexed collector, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Pauses all token transfers.
    /// @dev Can only be called by an account with the PAUSING_CONTRACTS_ROLE
    function pause() external;

    /// @notice Unpauses all token transfers.
    /// @dev Can only be called by an account with the DEFAULT_ADMIN_ROLE
    function unpause() external;

    /// @notice Sets the early unlock period for the bond.
    /// @param bondEarlyUnlockStart The start time of the early unlock period.
    /// @param bondEarlyUnlockEnd The end time of the early unlock period.
    function setupEarlyUnlockPeriod(uint256 bondEarlyUnlockStart, uint256 bondEarlyUnlockEnd)
        external;

    /// @notice Calculates the number of seconds from beginning to end of the bond period.
    /// @return The number of seconds.
    function totalBondTimes() external view returns (uint256);

    /// @notice get the start time
    /// @dev Used to determine if the bond can be minted.
    /// @return The block timestamp marking when the bond starts.
    function getStartTime() external view returns (uint256);

    /// @notice get the end time
    /// @dev Used to determine if the bond can be unwrapped.
    /// @return The block timestamp marking when the bond ends.
    function getEndTime() external view returns (uint256);

    /// @notice Mints Usd0PP tokens representing bonds.
    /// @dev Transfers collateral USD0 tokens and mints Usd0PP bonds.
    /// @param amountUsd0 The amount of USD0 to mint bonds for.
    function mint(uint256 amountUsd0) external;

    /// @notice Mints Usd0PP tokens representing bonds with permit.
    /// @dev    Transfers collateral Usd0 tokens and mints Usd0PP bonds.
    /// @param  amountUsd0 The amount of Usd0 to mint bonds for.
    /// @param  deadline The deadline for the permit.
    /// @param  v The v value for the permit.
    /// @param  r The r value for the permit.
    /// @param  s The s value for the permit.
    function mintWithPermit(uint256 amountUsd0, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    /// @notice Unwraps the bond after maturity, returning the collateral token.
    /// @dev Only the balance of the caller is unwrapped.
    /// @dev Burns bond tokens and transfers collateral back to the user.
    function unwrap() external;

    /// @notice Triggers the PAR mechanism to maintain the peg between USD0 and USD0++ via Curvepool exchange.
    /// @dev This function performs a series of actions: it checks for sufficient USD0 balances, exchanges USD0 for USD0++,
    ///      and unwraps USD0++ back to USD0, which is then burned and any excess sent to the treasury.
    ///      The function reverts if the PAR mechanism does not result in more USD0++ gained overall than USD0 is exchanged for.
    /// @param parUsd0Amount The amount of USD0 to be exchanged for USD0++.
    /// @param minimumPARMechanismGainedAmount The minimum additional amount of USD0++ expected to gain on top of the exchanged amount to account for slippage.
    function triggerPARMechanismCurvepool(
        uint256 parUsd0Amount,
        uint256 minimumPARMechanismGainedAmount
    ) external;

    /// @notice Allows users to early exit and unwrap a specified amount of USD0pp during the temporary exit period.
    /// @dev    Users must have been allocated an early unlock amount by the admin before calling this function.
    /// @dev    The early exit period is defined by `bondEarlyUnlockStart` and `bondEarlyUnlockEnd`.
    /// @dev    This is a one-time option; it consumes the entire allocated amount, even if only partially used.
    /// @dev    Emits `BondUnwrappedDuringEarlyUnlock` and `BondUnwrapped` events.
    /// @dev    Reverts if the current time is not within the early exit period.
    /// @dev    Reverts if `amountToUnwrap` exceeds the user's allocated early unlock amount.
    /// @dev    Reverts if the user does not have sufficient bond balance.
    /// @param amountToUnwrap The amount of bonds the user wants to unwrap.
    function temporaryOneToOneExitUnwrap(uint256 amountToUnwrap) external;

    /// @notice Allocates early unlock amounts to specified addresses, allowing them to early exit bonds during the temporary exit period.
    /// @dev    Only callable by accounts with the `EARLY_BOND_UNLOCK_ROLE`.
    /// @dev    Updates `bondEarlyUnlockAllowedAmount` for each address.
    /// @dev    The early unlock amounts determine the maximum amount each user can unwrap early.
    /// @dev    Reverts if the lengths of `addressesToAllocateTo` and `balancesToAllocate` do not match.
    /// @dev    Potential upper bound on redemption may be applied in future updates.
    /// @param addressesToAllocateTo An array of addresses to allocate early unlock amounts to.
    /// @param balancesToAllocate An array of amounts representing the early unlock amounts for each address.
    function allocateEarlyUnlockBalance(
        address[] calldata addressesToAllocateTo,
        uint256[] calldata balancesToAllocate
    ) external;

    /// @notice Retrieves the disabled status of a user's temporary redemptions.
    /// @dev Returns `true` if the user's temporary redemptions are disabled, `false` otherwise.
    /// @param user The address of the user to check.
    /// @return A boolean indicating whether the user's temporary redemptions are disabled.
    function getBondEarlyUnlockDisabled(address user) external view returns (bool);

    /// @notice Set the disabled status of a user's temporary redemptions. Only callable by the airdrop tax collector contract.
    /// @param user The address of the user to disable temporary redemptions for.
    function setBondEarlyUnlockDisabled(address user) external;

    /// @notice function for executing the emergency withdrawal of Usd0.
    /// @param  safeAccount The address of the account to withdraw the Usd0 to.
    /// @dev    Reverts if the caller does not have the DEFAULT_ADMIN_ROLE role.
    function emergencyWithdraw(address safeAccount) external;

    /// @notice Updates the floor price
    /// @param newFloorPrice The new floor price value (18 decimal places)
    function updateFloorPrice(uint256 newFloorPrice) external;

    /// @notice Unlocks USD0++ to USD0 at the current floor price
    /// @param usd0ppAmount The amount of USD0++ to unlock
    function unlockUsd0ppFloorPrice(uint256 usd0ppAmount) external;

    /// @notice Allows early redemption of USD0++ by burning USUAL
    /// @param usd0ppAmount The amount of USD0++ to redeem
    /// @param maxUsualAmount The maximum amount of USUAL to burn
    function unlockUSD0ppWithUsual(uint256 usd0ppAmount, uint256 maxUsualAmount) external;

    /// @notice Allows early redemption of USD0++ by burning USUAL using permit
    /// @param usd0ppAmount The amount of USD0++ to redeem
    /// @param maxUsualAmount The maximum amount of USUAL to burn
    /// @param usualApproval The approval for the USUAL permit
    /// @param usd0ppApproval The approval for the USD0++ permit
    function unlockUSD0ppWithUsualWithPermit(
        uint256 usd0ppAmount,
        uint256 maxUsualAmount,
        PermitApproval calldata usualApproval,
        PermitApproval calldata usd0ppApproval
    ) external;

    /// @notice Sweeps accumulated fees to the distribution module contract
    /// @return The amount of fees swept
    function sweepFees() external returns (uint256);

    /// @notice Sets the USUAL distribution per USD0++
    /// @param newRate New daily USUAL distribution per USD0++
    function setUsualDistributionPerUsd0pp(uint256 newRate) external;

    /// @notice Sets the duration cost factor
    /// @param newFactor New duration cost factor
    function setDurationCostFactor(uint256 newFactor) external;

    /// @notice Sets the target redemption rate
    /// @param newRate New target redemption rate
    function setTargetRedemptionRate(uint256 newRate) external;

    /// @notice Gets the current floor price
    /// @return The current floor price
    function getFloorPrice() external view returns (uint256);

    /// @notice Sets the unwrap capability for an address
    /// @param user The address to set the capability for
    /// @param cap The total capability amount (in USD0++ tokens)
    function setUnwrapCap(address user, uint256 cap) external;

    /// @notice Gets the unwrap amount capability for an address
    /// @param user The address to get the capability amount
    /// @return The unwrap amount capability
    function getUnwrapCap(address user) external view returns (uint256);

    /// @notice Gets the remaining unwrap allowance for an address
    /// @param user The address to get the remaining of
    /// @return The remaining allowance
    function getRemainingUnwrapAllowance(address user) external view returns (uint256);

    /// @notice Unwraps USD0++ tokens with cap enforcement
    /// @param amount The amount to unwrap
    /// @dev this doesnt count as an outflow, given that the following routing ensures a future inflow.
    function unwrapWithCap(uint256 amount) external;

    /// @notice Gets the current target redemption rate
    /// @return The current target redemption rate
    function getTargetRedemptionRate() external view returns (uint256);

    /// @notice Gets the current usual distribution per USD0++
    /// @return The current usual distribution per USD0++
    function getUsualDistributionPerUsd0pp() external view returns (uint256);

    /// @notice Gets the current duration cost factor
    /// @return The current duration cost factor
    function getDurationCostFactor() external view returns (uint256);

    /// @notice Gets the current daily USD0++ inflows
    /// @param dayIndex The index of the day (unix timestamp / seconds per day)
    /// @return The current daily USD0++ inflows
    function getDailyUsd0ppInflows(uint256 dayIndex) external view returns (uint256);

    /// @notice Gets the current daily USD0++ outflows
    /// @param dayIndex The index of the day (unix timestamp / seconds per day)
    /// @return The current daily USD0++ outflows
    function getDailyUsd0ppOutflows(uint256 dayIndex) external view returns (uint256);

    /// @notice Gets the current accumulated fees
    /// @return The current accumulated fees
    function getAccumulatedFees() external view returns (uint256);

    /// @notice Calculates the current net outflows
    /// @param usd0ppAmount The current redemption amount of USD0++ to include in the calculation
    /// @return The current net outflows
    function calculateNetOutflows(uint256 usd0ppAmount) external view returns (uint256);

    /// @notice Calculates the weekly target redemptions
    /// @param tvl The total value locked
    /// @param targetRedemptionRate The target redemption rate
    /// @return The weekly target redemptions
    function calculateWeeklyTargetRedemptions(uint256 tvl, uint256 targetRedemptionRate)
        external
        view
        returns (uint256);

    /// @notice Calculates the adjustment factor
    /// @param netOutflows The current net outflows
    /// @param weeklyTarget The weekly target redemptions
    /// @return The adjustment factor
    function calculateAdjustmentFactor(uint256 netOutflows, uint256 weeklyTarget)
        external
        view
        returns (uint256);

    /// @notice Calculates the required amount of USUAL to burn for early redemption
    /// @param usd0ppAmount The amount of USD0++ to redeem
    /// @return The required amount of USUAL to burn
    function calculateRequiredUsual(uint256 usd0ppAmount) external view returns (uint256);

    /// @notice Unwraps USD0++ tokens without cap enforcement
    /// @param amount The amount to unwrap
    function unwrapPegMaintainer(uint256 amount) external;
}
