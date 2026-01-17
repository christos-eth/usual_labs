// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ReentrancyGuardUpgradeable
} from "openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {
    PausableUpgradeable
} from "openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";

import {CheckAccessControl} from "src/utils/CheckAccessControl.sol";

import {IUsualS} from "src/interfaces/token/IUsualS.sol";
import {IUsualSP} from "src/interfaces/token/IUsualSP.sol";
import {IRegistryAccess} from "src/interfaces/registry/IRegistryAccess.sol";
import {IRegistryContract} from "src/interfaces/registry/IRegistryContract.sol";

import {
    CONTRACT_DISTRIBUTION_MODULE,
    DEFAULT_ADMIN_ROLE,
    USUALSP_OPERATOR_ROLE,
    PAUSING_CONTRACTS_ROLE,
    ONE_MONTH,
    NUMBER_OF_MONTHS_IN_THREE_YEARS
} from "src/constants.sol";
import {
    CliffBiggerThanDuration,
    InvalidInputArraysLength,
    StartTimeInPast,
    NotAuthorized,
    NotClaimableYet,
    AmountIsZero,
    InvalidInput,
    CannotReduceAllocation,
    EndTimeBeforeStartTime
} from "src/errors.sol";

/// @title   UsualSP contract
/// @notice  Stacked vesting contract for USUALS tokens.
/// @dev     The contract allows insiders to claim their USUALSP tokens over a vesting period. It also allows users to stake their USUALS tokens to receive yield.
/// @author  Usual Tech team
contract UsualSP is PausableUpgradeable, ReentrancyGuardUpgradeable, IUsualSP {
    using CheckAccessControl for IRegistryAccess;
    using SafeERC20 for IERC20;
    using Math for uint256;

    /// @custom:storage-location erc7201:UsualSP.storage.v0
    struct UsualSPStorageV0 {
        /// The RegistryContract instance for contract interactions.
        IRegistryContract registryContract;
        /// The RegistryAccess contract instance for role checks.
        IRegistryAccess registryAccess;
        /// The USUALS token.
        IERC20 usualS;
        /// The USUAL token.
        IERC20 usual;
        /// The duration of the vesting period.
        uint256 duration;
        /// Mapping of insiders and their cliff duration.
        mapping(address => uint256) cliffDuration;
        /// Mapping of insiders and their original allocation.
        mapping(address => uint256) originalAllocation;
        /// Mapping of users and their liquid allocation.
        mapping(address => uint256) liquidAllocation;
        /// Mapping of insiders and their already claimed original allocation.
        mapping(address => uint256) originalClaimed;
        /// Mapping of insiders and their allocation start time
        mapping(address => uint256) allocationStartTime;
        /// The address of the UsualX contract.
        IERC4626 usualX;
    }

    // keccak256(abi.encode(uint256(keccak256("UsualSP.storage.v0")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line
    bytes32 public constant UsualSPStorageV0Location =
        0xc4eb842bdb0bb6ace39c07132f299ffcb0c8b757dc80b8ab97ab5f4422bed900;

    /// @notice Returns the storage struct of the contract.
    /// @return $ .
    function _usualSPStorageV0() internal pure returns (UsualSPStorageV0 storage $) {
        bytes32 position = UsualSPStorageV0Location;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := position
        }
    }

    /*//////////////////////////////////////////////////////////////
                             Constructor
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                             INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// No initializer needed

    /*//////////////////////////////////////////////////////////////
                              Internal
    //////////////////////////////////////////////////////////////*/

    /// @notice Check how much an insider can claim.
    /// @param $ The storage struct of the contract.
    /// @param insider The address of the insider.
    /// @return The total amount available to claim.
    function _released(UsualSPStorageV0 storage $, address insider)
        internal
        view
        returns (uint256)
    {
        uint256 insiderCliffDuration = $.cliffDuration[insider];
        uint256 allocationStart = $.allocationStartTime[insider];
        uint256 totalMonthsInCliffDuration = insiderCliffDuration / ONE_MONTH;
        uint256 totalAllocation = $.originalAllocation[insider];

        if (block.timestamp < allocationStart + insiderCliffDuration) {
            // No tokens can be claimed before the cliff duration
            revert NotClaimableYet();
        } else if (block.timestamp >= allocationStart + $.duration) {
            // All tokens can be claimed after the duration
            return totalAllocation;
        } else {
            // Calculate the number of months passed since the cliff duration
            uint256 monthsPassed =
                (block.timestamp - allocationStart - insiderCliffDuration) / ONE_MONTH;

            // Calculate the vested amount based on the number of months passed
            uint256 vestedAmount = totalAllocation.mulDiv(
                totalMonthsInCliffDuration + monthsPassed,
                NUMBER_OF_MONTHS_IN_THREE_YEARS,
                Math.Rounding.Floor
            );

            // Ensure we don't release more than the total allocation due to rounding
            return Math.min(vestedAmount, totalAllocation);
        }
    }

    /// @notice Check how much an insider can claim.
    /// @param $ The storage struct of the contract.
    /// @param insider The address of the insider.
    /// @return The total amount available to claim minus the already claimed amount.
    function _available(UsualSPStorageV0 storage $, address insider)
        internal
        view
        returns (uint256)
    {
        return _released($, insider) - $.originalClaimed[insider];
    }

    /// @notice Validates the input arrays.
    /// @param recipients The addresses of the recipients.
    /// @param originalAllocations The allocations of the recipients.
    /// @param allocationStartTimes The allocation start times of the recipients.
    /// @param cliffDurations The cliff durations of the recipients.
    function _validateInputArrays(
        address[] calldata recipients,
        uint256[] calldata originalAllocations,
        uint256[] calldata allocationStartTimes,
        uint256[] calldata cliffDurations
    ) private pure {
        if (recipients.length == 0) {
            revert InvalidInputArraysLength();
        }
        if (recipients.length != originalAllocations.length) {
            revert InvalidInputArraysLength();
        }
        if (recipients.length != cliffDurations.length) {
            revert InvalidInputArraysLength();
        }
        if (recipients.length != allocationStartTimes.length) {
            revert InvalidInputArraysLength();
        }
    }

    /*//////////////////////////////////////////////////////////////
                         Restricted functions
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IUsualSP
    function allocate(
        address[] calldata recipients,
        uint256[] calldata originalAllocations,
        uint256[] calldata allocationStartTimes,
        uint256[] calldata cliffDurations
    ) external {
        UsualSPStorageV0 storage $ = _usualSPStorageV0();
        $.registryAccess.onlyMatchingRole(USUALSP_OPERATOR_ROLE);

        _validateInputArrays(recipients, originalAllocations, allocationStartTimes, cliffDurations);

        for (uint256 i; i < recipients.length;) {
            if (cliffDurations[i] > $.duration) {
                revert CliffBiggerThanDuration();
            }
            if (recipients[i] == address(0)) {
                revert InvalidInput();
            }

            if (originalAllocations[i] < $.originalAllocation[recipients[i]]) {
                revert CannotReduceAllocation();
            }

            // Only set allocationStartTime if this is their first allocation
            if ($.allocationStartTime[recipients[i]] == 0) {
                // Check that the allocation start time is not in the past
                if (allocationStartTimes[i] < block.timestamp) {
                    revert StartTimeInPast();
                }
                $.allocationStartTime[recipients[i]] = allocationStartTimes[i];
            }

            $.originalAllocation[recipients[i]] = originalAllocations[i];
            $.cliffDuration[recipients[i]] = cliffDurations[i];

            unchecked {
                ++i;
            }
        }
        emit NewAllocation(recipients, originalAllocations, allocationStartTimes, cliffDurations);
    }

    /// @inheritdoc IUsualSP
    function removeOriginalAllocation(address[] calldata recipients) external {
        if (recipients.length == 0) {
            revert InvalidInputArraysLength();
        }

        UsualSPStorageV0 storage $ = _usualSPStorageV0();
        $.registryAccess.onlyMatchingRole(USUALSP_OPERATOR_ROLE);

        for (uint256 i; i < recipients.length;) {
            $.originalAllocation[recipients[i]] = 0;
            $.originalClaimed[recipients[i]] = 0;

            emit RemovedOriginalAllocation(recipients[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IUsualSP
    function pause() external {
        UsualSPStorageV0 storage $ = _usualSPStorageV0();
        $.registryAccess.onlyMatchingRole(PAUSING_CONTRACTS_ROLE);
        _pause();
    }

    /// @inheritdoc IUsualSP
    function unpause() external {
        UsualSPStorageV0 storage $ = _usualSPStorageV0();
        $.registryAccess.onlyMatchingRole(DEFAULT_ADMIN_ROLE);
        _unpause();
    }

    /// @inheritdoc IUsualSP
    function stakeUsualS() external {
        UsualSPStorageV0 storage $ = _usualSPStorageV0();
        $.registryAccess.onlyMatchingRole(USUALSP_OPERATOR_ROLE);
        IUsualS(address($.usualS)).stakeAll();
    }

    /// @inheritdoc IUsualSP
    function sweepUsualX(address recipient) external {
        UsualSPStorageV0 storage $ = _usualSPStorageV0();
        $.registryAccess.onlyMatchingRole(USUALSP_OPERATOR_ROLE);

        uint256 totalUsualXBalance = $.usualX.balanceOf(address(this));

        //slither-disable-next-line unchecked-transfer
        $.usualX.transfer(recipient, totalUsualXBalance);
        emit UsualXSwept(recipient, totalUsualXBalance);
    }

    /// @inheritdoc IUsualSP
    function sweepUsualStar(address recipient) external {
        UsualSPStorageV0 storage $ = _usualSPStorageV0();
        $.registryAccess.onlyMatchingRole(USUALSP_OPERATOR_ROLE);

        uint256 totalUsualSBalance = $.usualS.balanceOf(address(this));
        //slither-disable-next-line unchecked-transfer
        $.usualS.transfer(recipient, totalUsualSBalance);
        emit UsualStarSwept(recipient, totalUsualSBalance);
    }

    /// @inheritdoc IUsualSP
    function sweepUsual(address recipient) external {
        UsualSPStorageV0 storage $ = _usualSPStorageV0();
        $.registryAccess.onlyMatchingRole(USUALSP_OPERATOR_ROLE);

        uint256 totalUsualBalance = $.usual.balanceOf(address(this));
        //slither-disable-next-line unchecked-transfer
        $.usual.transfer(recipient, totalUsualBalance);
        emit UsualSwept(recipient, totalUsualBalance);
    }

    /// @inheritdoc IUsualSP
    function startRewardDistribution(uint256 amount, uint256 startTime, uint256 endTime) external {
        if (endTime <= startTime) {
            revert EndTimeBeforeStartTime();
        }
        if (startTime < block.timestamp) {
            revert StartTimeInPast();
        }
        if (amount == 0) {
            revert AmountIsZero();
        }

        UsualSPStorageV0 storage $ = _usualSPStorageV0();

        address distributionModule = $.registryContract.getContract(CONTRACT_DISTRIBUTION_MODULE);
        if (msg.sender != distributionModule) {
            revert NotAuthorized();
        }

        // Transfer the Usual tokens from the sender to the contract
        $.usual.safeTransferFrom(msg.sender, address(this), amount);

        emit RewardPeriodStarted(amount, 0, startTime, endTime);
    }

    /*//////////////////////////////////////////////////////////////
                               Getters
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUsualSP
    function getLiquidAllocation(address account) external view returns (uint256) {
        UsualSPStorageV0 storage $ = _usualSPStorageV0();
        return $.liquidAllocation[account];
    }

    /// @inheritdoc IUsualSP
    function balanceOf(address account) public view override(IUsualSP) returns (uint256) {
        UsualSPStorageV0 storage $ = _usualSPStorageV0();
        return
            $.liquidAllocation[account] + $.originalAllocation[account] - $.originalClaimed[account];
    }

    /// @inheritdoc IUsualSP
    function totalStaked() public view override(IUsualSP) returns (uint256) {
        UsualSPStorageV0 storage $ = _usualSPStorageV0();
        return $.usualS.balanceOf(address(this));
    }

    /// @inheritdoc IUsualSP
    function getDuration() external view returns (uint256) {
        UsualSPStorageV0 storage $ = _usualSPStorageV0();
        return $.duration;
    }

    /// @inheritdoc IUsualSP
    function getCliffDuration(address insider) external view returns (uint256) {
        UsualSPStorageV0 storage $ = _usualSPStorageV0();
        return $.cliffDuration[insider];
    }

    /// @inheritdoc IUsualSP
    function getClaimableOriginalAllocation(address insider) external view returns (uint256) {
        UsualSPStorageV0 storage $ = _usualSPStorageV0();
        return _available($, insider);
    }

    /// @inheritdoc IUsualSP
    function getClaimedAllocation(address insider) external view returns (uint256) {
        UsualSPStorageV0 storage $ = _usualSPStorageV0();
        return $.originalClaimed[insider];
    }

    /// @inheritdoc IUsualSP
    function getAllocationStartTime(address account) external view returns (uint256) {
        UsualSPStorageV0 storage $ = _usualSPStorageV0();
        return $.allocationStartTime[account];
    }
}
