// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.26;

import {
    IERC20Metadata
} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IERC20Permit} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";

/**
 * @title  Usual Usdtb Extension.
 * @author Usual Labs
 */
interface IUsualUSDTB is IERC20Metadata {
    /* ============ Events and Errors ============ */

    /// @notice Emitted when address is added to blacklist.
    event Blacklist(address indexed account);

    /// @notice Emitted when address is removed from blacklist.
    event UnBlacklist(address indexed account);

    /// @notice Emitted when mint cap is set.
    event MintCapSet(uint256 newMintCap);

    /// @notice Emitted when token transfers/wraps are attempted by blacklisted account.
    error Blacklisted();

    /// @notice Emitted when action is performed by unauthorized account.
    error NotAuthorized();

    /// @notice Emitted when blacklist/unBlacklist action is performed on the account that is already in desired state.
    error SameValue();

    /// @notice Emitted if account is 0x0.
    error ZeroAddress();

    /// @notice Emitted if Usdtb Token is 0x0.
    error ZeroUsdtb();

    /// @notice Emitted if Registry Access is 0x0.
    error ZeroRegistryAccess();

    /// @notice Emitted if Mint Cap is exceeded.
    error MintCapExceeded();

    /// @notice Emitted if Mint Cap > 2^96 - 1.
    error InvalidUInt96();

    /// @notice Emitted if `wrap` or `unwrap` amount is 0.
    error InvalidAmount();

    /* ============ Interactive Functions ============ */

    /// @notice Wraps `amount` Usdtb from the caller into UsualUSDTB for `recipient`.
    /// @param  recipient The account receiving the minted UsualUSDTB.
    /// @param  amount    The amount of Usdtb deposited.
    /// @return           The amount of UsualUSDTB minted.
    function wrap(address recipient, uint256 amount) external returns (uint256);

    /// @notice Wraps `amount` Usdtb from the caller into UsualUSDTB for `recipient`, using a permit.
    /// @param  recipient The account receiving the minted UsualUSDTB.
    /// @param  amount    The amount of Usdtb deposited.
    /// @param  deadline  The last timestamp where the signature is still valid.
    /// @param  v         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
    /// @param  r         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
    /// @param  s         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
    /// @return           The amount of UsualUSDTB minted.
    function wrapWithPermit(
        address recipient,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /// @notice Unwraps `amount` UsualUSDTB from the caller into Usdtb for `recipient`.
    /// @dev Can only be called by the `USUAL_USDTB_UNWRAP`.
    /// @param  recipient The account receiving the withdrawn Usdtb.
    /// @param  amount    The amount of UsualUSDTB burned.
    /// @return           The amount of Usdtb withdrawn.
    function unwrap(address recipient, uint256 amount) external returns (uint256);

    /// @notice Adds an address to the blacklist.
    /// @dev Can only be called by the `BLACKLIST_ROLE`.
    /// @param account The address to be blacklisted.
    function blacklist(address account) external;

    /// @notice Removes an address from the blacklist.
    /// @dev Can only be called by the `BLACKLIST_ROLE`.
    /// @param account The address to be removed from the blacklist.
    function unBlacklist(address account) external;

    /// @notice Pauses all token transfers.
    /// @dev Can only be called by the `USUAL_USDTB_PAUSE` role.
    function pause() external;

    /// @notice Unpauses all token transfers.
    /// @dev Can only be called by the `USUAL_USDTB_UNPAUSE` role.
    function unpause() external;

    /// @notice Sets the mint cap.
    /// @param newMintCap The new mint cap, should be different from the current value.
    /// @dev The new mint cap should be less than or equal to 2^96 - 1.
    /// @dev Can only be called by the `USUAL_USDTB_MINTCAP_ALLOCATOR` role.
    /// @dev number of decimals is 6 for the mint cap value.
    function setMintCap(uint256 newMintCap) external;

    /* ============ View/Pure Functions ============ */

    /// @notice Returns whether the account is blacklisted.
    /// @param account The address to check.
    /// @return Whether the account is blacklisted.
    function isBlacklisted(address account) external view returns (bool);

    /// @notice Returns the Usdtb Token address.
    /// @return The Usdtb Token address.
    function usdtb() external view returns (address);

    /// @notice Returns the Registry Access address.
    /// @return The Registry Access address.
    function registryAccess() external view returns (address);

    /// @notice Returns the Mint Cap amount.
    /// @return The Mint Cap amount.
    function mintCap() external view returns (uint256);

    /// @notice Returns the available wrappable amount for the current values of `mintCap` and `totalSupply`.
    /// @param amount The amount of UsualUSDTB to wrap.
    /// @return The available wrappable amount.
    function getWrappableAmount(uint256 amount) external view returns (uint256);
}
