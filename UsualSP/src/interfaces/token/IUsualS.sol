// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IUsualS is IERC20Metadata {
    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an account is blacklisted.
    /// @param account The address that was blacklisted.
    event Blacklist(address account);

    /// @notice Emitted when an account is removed from the blacklist.
    /// @param account The address that was unblacklisted.
    event UnBlacklist(address account);

    /// @notice Emitted when the stake is made.
    /// @param account The address of the insider.
    /// @param amount The amount of tokens staked.
    event Stake(address account, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Pauses all token transfers.
    /// @dev Can only be called by the pauser.
    function pause() external;

    /// @notice Unpauses all token transfers.
    /// @dev Can only be called by the admin.
    function unpause() external;

    /// @notice burnFrom UsualS token
    /// @dev Can only be called by USUALS_BURN role
    /// @param account address of the account who want to burn
    /// @param amount the amount of tokens to burn
    function burnFrom(address account, uint256 amount) external;

    /// @notice burn UsualS token
    /// @dev Can only be called by USUALS_BURN role
    /// @param amount the amount of tokens to burn
    function burn(uint256 amount) external;

    /// @notice blacklist an account
    /// @dev Can only be called by the BLACKLIST_ROLE
    /// @param account address of the account to blacklist
    function blacklist(address account) external;

    /// @notice unblacklist an account
    /// @dev Can only be called by the BLACKLIST_ROLE
    /// @param account address of the account to unblacklist
    function unBlacklist(address account) external;

    /// @notice send total supply of UsualS tokens to staking contract
    /// @dev Can only be called by the staking contract (UsualSP contract)
    function stakeAll() external;

    /// @notice check if the account is blacklisted
    /// @param account address of the account to check
    /// @return bool True if the account is blacklisted
    function isBlacklisted(address account) external view returns (bool);
}
