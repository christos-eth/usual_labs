// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.26;

import {
    ERC20PausableUpgradeable
} from "../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {
    ERC20Upgradeable
} from "../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import { IERC20Metadata } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IUsualUSDTB } from "./interfaces/IUsualUSDTB.sol";
import { IRegistryAccess } from "./interfaces/IRegistryAccess.sol";
import { IUSDTB } from "./interfaces/IUsdtb.sol";
import {
    USUAL_USDTB_UNWRAP,
    USUAL_USDTB_PAUSE,
    USUAL_USDTB_UNPAUSE,
    BLACKLIST_ROLE,
    USUAL_USDTB_MINTCAP_ALLOCATOR,
    USUAL_USDTB_DECIMALS
} from "../constants.sol";

/**
 * @title  Usual Wrapped USDTB Extension.
 * @author M^0 Labs
 * @author modified by Usual Labs
 */
contract UsualUSDTB is ERC20PausableUpgradeable, ERC20PermitUpgradeable, IUsualUSDTB {
    /* ============ Structs, Variables, Modifiers ============ */

    /// @custom:storage-location erc7201:UsualUSDTB.storage.v0
    struct UsualUSDTBStorageV0 {
        // 1st slot
        uint96 mintCap;
        address Usdtb;
        // 2nd slot
        address registryAccess;
        // next slots
        mapping(address => bool) isBlacklisted;
    }


  
    // keccak256(abi.encode(uint256(keccak256("UsualUSDTB.storage.v0")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line
    bytes32 public constant UsualUSDTBStorageV0Location =
        0x19a951195a7ec99af1caf540a6cbc8dcb3f02edec795ffcbb0a058cd03496300;

    /// @notice Returns the storage struct of the contract.
    /// @return $ .
    function _UsualUSDTBStorageV0() internal pure returns (UsualUSDTBStorageV0 storage $) {
        bytes32 position = UsualUSDTBStorageV0Location;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := position
        }
    }

    /* ============ Constructor ============ */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* ============ Initializer ============ */

    /// @notice Initializes the UsualUSDTB contract.
    /// @param usdtb_ The address of the USDTB token.
    /// @param registryAccess_ The address of the registry access.
    function initialize(address usdtb_, address registryAccess_) public initializer {
        if (usdtb_ == address(0)) revert ZeroUsdtb();
        if (registryAccess_ == address(0)) revert ZeroRegistryAccess();

        __ERC20_init("UsualUSDTB", "USUALUSDTB");
        __ERC20Pausable_init();
        __ERC20Permit_init("UsualUSDTB");

        UsualUSDTBStorageV0 storage $ = _UsualUSDTBStorageV0();
        $.Usdtb = usdtb_;
        $.registryAccess = registryAccess_;
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IUsualUSDTB
    function wrap(address recipient, uint256 amount) external returns (uint256) {
        if (amount == 0) revert InvalidAmount();

        return _wrap(msg.sender, recipient, amount);
    }

    /// @inheritdoc IUsualUSDTB
    function wrapWithPermit(
        address recipient,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256) {
        if (amount == 0) revert InvalidAmount();

        UsualUSDTBStorageV0 storage $ = _UsualUSDTBStorageV0();

        // NOTE: `permit` call failures can be safely ignored to remove the risk of transactions being reverted due to front-run.
        try IUSDTB($.Usdtb).permit(msg.sender, address(this), amount, deadline, v, r, s) {} catch {}

        return _wrap(msg.sender, recipient, amount);
    }

    /// @inheritdoc IUsualUSDTB
    function unwrap(address recipient, uint256 amount) external returns (uint256) {
        if (amount == 0) revert InvalidAmount();

        UsualUSDTBStorageV0 storage $ = _UsualUSDTBStorageV0();

        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess($.registryAccess).hasRole(USUAL_USDTB_UNWRAP, msg.sender)) revert NotAuthorized();

        return _unwrap(msg.sender, recipient, amount);
    }

    /* ============ Special Admin Functions ============ */

    /// @inheritdoc IUsualUSDTB
    function setMintCap(uint256 newMintCap) external {
        UsualUSDTBStorageV0 storage $ = _UsualUSDTBStorageV0();

        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess($.registryAccess).hasRole(USUAL_USDTB_MINTCAP_ALLOCATOR, msg.sender)) revert NotAuthorized();

        // Revert if the new mint cap is the same as the current mint cap.
        if (newMintCap == $.mintCap) revert SameValue();

        $.mintCap = _safe96(newMintCap);

        emit MintCapSet(newMintCap);
    }

    /// @inheritdoc IUsualUSDTB
    function pause() external {
        UsualUSDTBStorageV0 storage $ = _UsualUSDTBStorageV0();

        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess($.registryAccess).hasRole(USUAL_USDTB_PAUSE, msg.sender)) revert NotAuthorized();

        _pause();
    }

    /// @inheritdoc IUsualUSDTB
    function unpause() external {
        UsualUSDTBStorageV0 storage $ = _UsualUSDTBStorageV0();

        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess($.registryAccess).hasRole(USUAL_USDTB_UNPAUSE, msg.sender)) revert NotAuthorized();

        _unpause();
    }

    /// @inheritdoc IUsualUSDTB
    function blacklist(address account) external {
        if (account == address(0)) revert ZeroAddress();

        UsualUSDTBStorageV0 storage $ = _UsualUSDTBStorageV0();

        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess($.registryAccess).hasRole(BLACKLIST_ROLE, msg.sender)) revert NotAuthorized();

        // Revert in the same way as USD0 if `account` is already blacklisted.
        if ($.isBlacklisted[account]) revert SameValue();

        $.isBlacklisted[account] = true;

        emit Blacklist(account);
    }

    /// @inheritdoc IUsualUSDTB
    function unBlacklist(address account) external {
        if (account == address(0)) revert ZeroAddress();

        UsualUSDTBStorageV0 storage $ = _UsualUSDTBStorageV0();

        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess($.registryAccess).hasRole(BLACKLIST_ROLE, msg.sender)) revert NotAuthorized();

        // Revert in the same way as USD0 if `account` is not blacklisted.
        if (!$.isBlacklisted[account]) revert SameValue();

        $.isBlacklisted[account] = false;

        emit UnBlacklist(account);
    }

    /* ============ External View/Pure Functions ============ */

    /// @inheritdoc IERC20Metadata
    function decimals() public pure override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
        return USUAL_USDTB_DECIMALS;
    }

    /// @inheritdoc IUsualUSDTB
    function usdtb() public view returns (address) {
        UsualUSDTBStorageV0 storage $ = _UsualUSDTBStorageV0();
        return $.Usdtb;
    }

    /// @inheritdoc IUsualUSDTB
    function registryAccess() public view returns (address) {
        UsualUSDTBStorageV0 storage $ = _UsualUSDTBStorageV0();
        return $.registryAccess;
    }

    /// @inheritdoc IUsualUSDTB
    function mintCap() public view returns (uint256) {
        UsualUSDTBStorageV0 storage $ = _UsualUSDTBStorageV0();
        return $.mintCap;
    }

    /// @inheritdoc IUsualUSDTB
    function isBlacklisted(address account) external view returns (bool) {
        UsualUSDTBStorageV0 storage $ = _UsualUSDTBStorageV0();
        return $.isBlacklisted[account];
    }

    /// @inheritdoc IUsualUSDTB
    function getWrappableAmount(uint256 amount) external view returns (uint256) {
        uint256 totalSupply_ = totalSupply();
        uint256 mintCap_ = mintCap();

        return _min(amount, mintCap_ > totalSupply_ ? mintCap_ - totalSupply_ : 0);
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev    Wraps `amount` Usdtb from `account` into UsualUSDTB for `recipient`.
     * @param  account    The account from which Usdtb is deposited.
     * @param  recipient  The account receiving the minted UsualUSDTB.
     * @param  amount     The amount of Usdtb deposited.
     * @return wrapped    The amount of UsualUSDTB minted.
     */
    function _wrap(address account, address recipient, uint256 amount) internal returns (uint256 wrapped) {
        UsualUSDTBStorageV0 storage $ = _UsualUSDTBStorageV0();

        // NOTE: The behavior of `IUsualUSDTB.transferFrom` is known, so its return can be ignored.
        IUSDTB($.Usdtb).transferFrom(account, address(this), amount);

        _mint(recipient, wrapped = amount);
    }

    /**
     * @dev    Unwraps `amount` UsualUSDTB from `account` into Usdtb for `recipient`.
     * @param  account   The account from which UsualUSDTB is burned.
     * @param  recipient The account receiving the withdrawn Usdtb.
     * @param  amount    The amount of UsualUSDTB burned.
     * @return unwrapped The amount of Usdtb tokens withdrawn.
     */
    function _unwrap(address account, address recipient, uint256 amount) internal returns (uint256 unwrapped) {
        UsualUSDTBStorageV0 storage $ = _UsualUSDTBStorageV0();

        _burn(account, amount);

        // NOTE: The behavior of `IUsualUSDTB.transfer` is known, so its return can be ignored.
        IUSDTB($.Usdtb).transfer(recipient, unwrapped = amount);
    }

    /**
     * @dev    Hook that ensures token transfers are not made from or to blacklisted addresses.
     * @param  from   The address sending the tokens.
     * @param  to     The address receiving the tokens.
     * @param  amount The amount of tokens being transferred.
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20PausableUpgradeable, ERC20Upgradeable) {
        UsualUSDTBStorageV0 storage $ = _UsualUSDTBStorageV0();
        if ($.isBlacklisted[from] || $.isBlacklisted[to]) revert Blacklisted();

        // Check if minting would exceed the mint cap
        if (from == address(0) && totalSupply() + amount > $.mintCap) revert MintCapExceeded();

        ERC20PausableUpgradeable._update(from, to, amount);
    }

    /// @dev Compares two uint256 values and returns the lesser one.
    /// @param a The first value to compare.
    /// @param b The second value to compare.
    /// @return The lesser of the two values.
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @dev Converts a uint256 to a uint96, reverting if the conversion without loss is not possible.
    /// @param n The value to convert.
    /// @return The converted value.
    function _safe96(uint256 n) internal pure returns (uint96) {
        if (n > type(uint96).max) revert InvalidUInt96();
        return uint96(n);
    }
}
