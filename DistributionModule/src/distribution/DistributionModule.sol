// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

import {IUsualSP} from "src/interfaces/token/IUsualSP.sol";
import {IUsualX} from "src/interfaces/vaults/IUsualX.sol";
import {IUsual} from "src/interfaces/token/IUsual.sol";
import {IUsd0PP} from "src/interfaces/token/IUsd0PP.sol";
import {IDaoCollateral} from "src/interfaces/IDaoCollateral.sol";

import {IDistributionModule} from "src/interfaces/distribution/IDistributionModule.sol";
import {IDistributionAllocator} from "src/interfaces/distribution/IDistributionAllocator.sol";
import {IDistributionOperator} from "src/interfaces/distribution/IDistributionOperator.sol";
import {IOffChainDistributionChallenger} from
    "src/interfaces/distribution/IOffChainDistributionChallenger.sol";

import {IRegistryAccess} from "src/interfaces/registry/IRegistryAccess.sol";
import {IRegistryContract} from "src/interfaces/registry/IRegistryContract.sol";
import {CheckAccessControl} from "src/utils/CheckAccessControl.sol";
import {Normalize} from "src/utils/normalize.sol";

import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import {IYieldModule} from "src/interfaces/modules/IYieldModule.sol";
import {
    DEFAULT_ADMIN_ROLE,
    DISTRIBUTION_ALLOCATOR_ROLE,
    DISTRIBUTION_OPERATOR_ROLE,
    DISTRIBUTION_CHALLENGER_ROLE,
    PAUSING_CONTRACTS_ROLE,
    SCALAR_ONE,
    BPS_SCALAR,
    USUAL_DISTRIBUTION_CHALLENGE_PERIOD,
    BASIS_POINT_BASE,
    DISTRIBUTION_FREQUENCY_SCALAR,
    STARTDATE_USUAL_CLAIMING_DISTRIBUTION_MODULE,
    REDIRECTION_ADMIN_ROLE,
    REDIRECTION_DISTRIBUTION_CHALLENGE_PERIOD,
    CONTRACT_YIELD_TREASURY,
    CONTRACT_YIELD_MODULE,
    FEE_RATE_SETTER_ROLE,
    CONTRACT_ORACLE,
    VAULT_UPDATER_ROLE
} from "src/constants.sol";
import {
    AmountIsZero,
    NullMerkleRoot,
    InvalidProof,
    InvalidInput,
    NullAddress,
    SameValue,
    PercentagesSumNotEqualTo100Percent,
    CannotDistributeUsualMoreThanOnceADay,
    NoOffChainDistributionToApprove,
    NoTokensToClaim,
    NotClaimableYet,
    OffChainDistributionRedirectTimeIntervalNotPassed,
    NoInitiatedRedirectedOffChainDistribution,
    NoActiveRedirectedOffChainDistribution,
    InvalidRates,
    AlreadyInitiatedRedirectedOffChainDistribution,
    AlreadyRedirectedOffChainDistribution
} from "src/errors.sol";

import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {IOracle} from "src/interfaces/oracles/IOracle.sol";

/// @title DistributionModule
/// @notice This contract provides calculations for treasury yield analysis & distribution
/// @dev Implements upgradeable pattern and uses fixed point arithmetic for calculations
/// @author  Usual Tech team
contract DistributionModule is
    Initializable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IOffChainDistributionChallenger,
    IDistributionAllocator,
    IDistributionOperator,
    IDistributionModule
{
    using SafeERC20 for IUsual;
    using SafeERC20 for IERC20Metadata;
    using CheckAccessControl for IRegistryAccess;
    using Normalize for uint256;

    struct DistributionModuleStorageV0 {
        /// @notice Registry access contract
        IRegistryAccess registryAccess;
        /// @notice Registry contract
        IRegistryContract registryContract;
        /// @notice usd0PP contract
        IERC20Metadata usd0PP;
        /// @notice Usual token contract
        IUsual usual;
        /// @notice UsualX contract
        IUsualX usualX;
        /// @notice UsualSP contract
        IUsualSP usualSP;
        /// @notice DAO Collateral contract
        IDaoCollateral daoCollateral;
        /// @notice LBT bucket distribution percentage
        uint256 lbtDistributionShare;
        /// @notice LYT bucket distribution percentage
        uint256 lytDistributionShare;
        /// @notice IYT bucket distribution percentage
        uint256 iytDistributionShare;
        /// @notice Bribe bucket distribution percentage
        uint256 bribeDistributionShare;
        /// @notice Ecosystem bucket distribution percentage
        uint256 ecoDistributionShare;
        /// @notice DAO bucket distribution percentage
        uint256 daoDistributionShare;
        /// @notice Market makers bucket distribution percentage
        uint256 marketMakersDistributionShare;
        /// @notice UsualX bucket distribution percentage
        uint256 usualXDistributionShare;
        /// @notice UsualStar bucket distribution percentage
        uint256 usualStarDistributionShare;
        /// @notice D parameter
        uint256 d;
        /// @notice M0 parameter
        uint256 m0;
        /// @notice p0 parameter: initial price
        uint256 p0;
        /// @notice rate0 parameter: initial rate
        uint256 rate0;
        /// @notice RateMin parameter
        uint256 rateMin;
        /// @notice baseGamma parameter
        uint256 baseGamma;
        /// @notice usd0PP total supply at the time of deployment
        uint256 initialSupplyPp0;
        /// @notice Timestamp of the last on-chain distribution
        uint256 lastOnChainDistributionTimestamp;
        /// @notice Amount of tokens that can be minted for the off-chain distribution
        uint256 offChainDistributionMintCap;
        /// @notice Queue of off-chain distributions
        QueuedOffChainDistribution[] offChainDistributionQueue;
        /// @notice Timestamp of the latest off-chain distribution update that is claimable
        uint256 offChainDistributionTimestamp;
        /// @notice Merkle root of the latest off-chain distribution update that is claimable and after challenge period
        /// @dev Merkle tree should always include the total amount of tokens that account can claim and could claim in the past.
        bytes32 offChainDistributionMerkleRoot;
        /// @notice Mapping of the claimed tokens for each account. Used to prevent double claiming after a new distribution is approved.
        mapping(address offChainClaimer => uint256 amount) claimedByOffChainClaimer;
        /// @notice Mapping of the initiated redirected off-chain distribution
        mapping(address account => address initiatedRedirectedAccount)
            initiatedRedirectedOffChainDistribution;
        /// @notice Mapping of the initiated redirected off-chain distributions starting timestamp
        mapping(address account => uint256 redirectedOffChainDistributionStartingTimestamp)
            initiatedRedirectedOffChainDistributionStartingTimestamp;
        /// @notice Mapping of the accepted & finalized redirected off-chain distributions
        mapping(address account => address acceptedRedirectedAccount)
            activeRedirectedOffChainDistribution;
        /// @notice Rate of fee to send to yield treasury
        uint256 treasuryFeeRate;
        /// @notice Rate of fee to send to UsualX
        uint256 usualXFeeRate;
        /// @notice  Yield Module contract
        IYieldModule yieldModule;
        /// @notice Address of the iUSD0++ vault
        IERC4626 iUsd0ppVault;
        /// @notice Address of the classicalOracle
        IOracle oracle;
        /// @notice iUSD0++ bucket distribution percentage
        uint256 iUSD0ppDistributionShareOfLbt;
    }

    // keccak256(abi.encode(uint256(keccak256("DistributionModule.storage.v0")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line
    bytes32 public constant DistributionModuleStorageV0Location =
        0xfe38e877893749f31d716df8c21b1fcb408307d7596d0d90c0ec8782cacd9b00;

    // solhint-disable
    /// @dev Returns the storage struct of the contract
    function _distributionModuleStorageV0()
        internal
        pure
        returns (DistributionModuleStorageV0 storage $)
    {
        bytes32 position = DistributionModuleStorageV0Location;
        assembly {
            $.slot := position
        }
    }
    // solhint-enable

    /*//////////////////////////////////////////////////////////////
                             Constructor
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                             Initializer
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the contract with the initial fee rates
    /// @param initialTreasuryFeeRate Rate of fee to send to yield treasury
    /// @param initialUsualXFeeRate Rate of fee to send to UsualX
    /// @param _iUsd0ppVault Address of the iUSD0++ vault
    function initializeV1(
        uint256 initialTreasuryFeeRate,
        uint256 initialUsualXFeeRate,
        address _iUsd0ppVault
    ) external reinitializer(2) {
        if (initialTreasuryFeeRate + initialUsualXFeeRate > BASIS_POINT_BASE) {
            revert InvalidInput();
        }

        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();

        // Initialize vault components
        // NOTE: if this vault is not set, it will nullify the vault integration dynamically
        $.iUsd0ppVault = IERC4626(_iUsd0ppVault);
        $.oracle = IOracle($.registryContract.getContract(CONTRACT_ORACLE));
        $.yieldModule = IYieldModule($.registryContract.getContract(CONTRACT_YIELD_MODULE));
        $.treasuryFeeRate = initialTreasuryFeeRate;
        $.usualXFeeRate = initialUsualXFeeRate;
        uint256 burnFeeRate = BASIS_POINT_BASE - initialTreasuryFeeRate - initialUsualXFeeRate;
        emit FeeRatesSet(initialTreasuryFeeRate, initialUsualXFeeRate, burnFeeRate);
    }

    /// @notice Checks if the caller has DISTRIBUTION_ALLOCATOR_ROLE role
    /// @param $ Storage struct of the contract
    function _requireOnlyDistributionAllocator(DistributionModuleStorageV0 storage $)
        internal
        view
    {
        $.registryAccess.onlyMatchingRole(DISTRIBUTION_ALLOCATOR_ROLE);
    }

    /// @notice Ensures that the caller is the pausing contracts role (PAUSING_CONTRACTS_ROLE).
    function _requireOnlyPausingContractsRole() internal view {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        $.registryAccess.onlyMatchingRole(PAUSING_CONTRACTS_ROLE);
    }

    /// @notice Ensures that the caller is the operator role (DISTRIBUTION_OPERATOR_ROLE).
    /// @param $ Storage struct of the contract
    function _requireOnlyOperator(DistributionModuleStorageV0 storage $) internal view {
        $.registryAccess.onlyMatchingRole(DISTRIBUTION_OPERATOR_ROLE);
    }

    /// @notice Ensures that the caller is the redirection-admin-role (REDIRECTION_ADMIN_ROLE).
    /// @param $ Storage struct of the contract
    function _requireOnlyRedirectionAdmin(DistributionModuleStorageV0 storage $) internal view {
        $.registryAccess.onlyMatchingRole(REDIRECTION_ADMIN_ROLE);
    }

    /// @notice Ensures that the caller is the challenger role (DISTRIBUTION_CHALLENGER_ROLE).
    /// @param $ Storage struct of the contract
    function _requireOnlyChallenger(DistributionModuleStorageV0 storage $) internal view {
        $.registryAccess.onlyMatchingRole(DISTRIBUTION_CHALLENGER_ROLE);
    }

    /// @notice Ensures that the caller is the fee rate setter role (FEE_RATE_SETTER_ROLE).
    /// @param $ Storage struct of the contract
    function _requireOnlyFeeRateSetter(DistributionModuleStorageV0 storage $) internal view {
        $.registryAccess.onlyMatchingRole(FEE_RATE_SETTER_ROLE);
    }

    /// @notice Ensures that the caller has the VAULT_UPDATER_ROLE
    /// @param $ Storage struct of the contract
    function _requireOnlyVaultUpdater(DistributionModuleStorageV0 storage $) internal view {
        $.registryAccess.onlyMatchingRole(VAULT_UPDATER_ROLE);
    }

    /// @notice Pauses the contract
    /// @dev Can only be called by the PAUSING_CONTRACTS_ROLE
    function pause() external {
        _requireOnlyPausingContractsRole();
        _pause();
    }

    /// @inheritdoc IDistributionModule
    function unpause() external {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        $.registryAccess.onlyMatchingRole(DEFAULT_ADMIN_ROLE);
        _unpause();
    }

    /// @inheritdoc IDistributionModule
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
            uint256 usualX,
            uint256 usualStar
        )
    {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();

        lbt = $.lbtDistributionShare;
        lyt = $.lytDistributionShare;
        iyt = $.iytDistributionShare;
        bribe = $.bribeDistributionShare;
        eco = $.ecoDistributionShare;
        dao = $.daoDistributionShare;
        marketMakers = $.marketMakersDistributionShare;
        usualX = $.usualXDistributionShare;
        usualStar = $.usualStarDistributionShare;
    }

    /// @inheritdoc IDistributionModule
    function calculateSt(uint256 supplyPpt, uint256 pt) external view returns (uint256) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        return _calculateSt($, supplyPpt, pt);
    }

    /// @inheritdoc IDistributionModule
    function calculateRt() external view returns (uint256) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        (uint256 ratet, uint256 p90Rate) = _getRateAndP90Rate($);
        return _calculateRt($, ratet, p90Rate);
    }

    /// @inheritdoc IDistributionModule
    function calculateKappa() external view returns (uint256) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        (uint256 ratet,) = _getRateAndP90Rate($);
        return _calculateKappa($, ratet);
    }

    function calculateGamma() external view returns (uint256) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        return _calculateGamma($);
    }

    /// @inheritdoc IDistributionModule
    function calculateMt(uint256 st, uint256 rt, uint256 kappa) external view returns (uint256) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();

        return _calculateMt($, st, rt, kappa);
    }

    /// @inheritdoc IDistributionModule
    function calculateUsualDist()
        public
        view
        returns (uint256 st, uint256 rt, uint256 kappa, uint256 mt, uint256 usualDist)
    {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        (uint256 ratet, uint256 p90Rate) = _getRateAndP90Rate($);
        return _calculateUsualDistribution($, ratet, p90Rate);
    }

    /// @inheritdoc IDistributionModule
    //solhint-disable-next-line
    function claimOffChainDistribution(address account, uint256 amount, bytes32[] calldata proof)
        external
        nonReentrant
        whenNotPaused
    {
        if (account == address(0)) {
            revert NullAddress();
        }
        if (amount == 0) {
            revert AmountIsZero();
        }
        if (block.timestamp < STARTDATE_USUAL_CLAIMING_DISTRIBUTION_MODULE) {
            revert NotClaimableYet();
        }

        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        if ($.offChainDistributionTimestamp == 0) {
            revert NoTokensToClaim();
        }

        if (!_verifyOffChainDistributionMerkleProof($, account, amount, proof)) {
            revert InvalidProof();
        }

        uint256 claimedUpToNow = $.claimedByOffChainClaimer[account];

        if (claimedUpToNow >= amount) {
            revert NoTokensToClaim();
        }

        uint256 amountToSend = amount - claimedUpToNow;

        if (amountToSend > $.offChainDistributionMintCap) {
            revert NoTokensToClaim();
        }

        $.offChainDistributionMintCap -= amountToSend;
        $.claimedByOffChainClaimer[account] = amount;

        emit OffChainDistributionClaimed(account, amountToSend);

        if ($.activeRedirectedOffChainDistribution[account] != address(0)) {
            $.usual.mint($.activeRedirectedOffChainDistribution[account], amountToSend);
            emit OffChainDistributionClaimedAndRedirected(
                account, $.activeRedirectedOffChainDistribution[account], amountToSend
            );
        } else {
            $.usual.mint(account, amountToSend);
        }
    }

    /// @inheritdoc IDistributionModule
    function approveUnchallengedOffChainDistribution() external whenNotPaused {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();

        uint256 queueLength = $.offChainDistributionQueue.length;
        if (queueLength == 0) {
            revert NoOffChainDistributionToApprove();
        }

        uint256 candidateTimestamp = $.offChainDistributionTimestamp;
        bytes32 candidateMerkleRoot = bytes32(0);

        uint256 amountOfDistributionsToRemove = 0;
        uint256[] memory indicesToRemove = new uint256[](queueLength);

        for (uint256 i; i < queueLength;) {
            QueuedOffChainDistribution storage distribution = $.offChainDistributionQueue[i];

            bool isAfterChallengePeriod =
                block.timestamp >= distribution.timestamp + USUAL_DISTRIBUTION_CHALLENGE_PERIOD;
            bool isNewerThanCandidate = distribution.timestamp > candidateTimestamp;

            if (isAfterChallengePeriod && isNewerThanCandidate) {
                candidateMerkleRoot = distribution.merkleRoot;
                candidateTimestamp = distribution.timestamp;
            }

            if (isAfterChallengePeriod) {
                // NOTE: We store the index to remove to avoid modifying the array while iterating.
                // NOTE: After successful approval queue should have only elements older than challenge period.
                indicesToRemove[amountOfDistributionsToRemove] = i;
                amountOfDistributionsToRemove++;
            }

            unchecked {
                ++i;
            }
        }

        if (candidateTimestamp <= $.offChainDistributionTimestamp) {
            revert NoOffChainDistributionToApprove();
        }

        for (uint256 i = amountOfDistributionsToRemove; i > 0;) {
            uint256 indexToRemove = indicesToRemove[i - 1];

            // NOTE: $.offChainDistributionQueue.length cannot be cached since it can decrease with each loop iteration
            $.offChainDistributionQueue[indexToRemove] =
                $.offChainDistributionQueue[$.offChainDistributionQueue.length - 1];
            $.offChainDistributionQueue.pop();

            unchecked {
                --i;
            }
        }

        $.offChainDistributionMerkleRoot = candidateMerkleRoot;
        $.offChainDistributionTimestamp = candidateTimestamp;

        emit OffChainDistributionApproved(
            $.offChainDistributionTimestamp, $.offChainDistributionMerkleRoot
        );
    }

    /// @inheritdoc IDistributionModule
    function getLastOnChainDistributionTimestamp() external view returns (uint256) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        return $.lastOnChainDistributionTimestamp;
    }

    /// @inheritdoc IDistributionModule
    function getOffChainDistributionData()
        external
        view
        returns (uint256 timestamp, bytes32 merkleRoot)
    {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        return ($.offChainDistributionTimestamp, $.offChainDistributionMerkleRoot);
    }

    /// @inheritdoc IDistributionModule
    function getOffChainTokensClaimed(address account) external view returns (uint256) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        return $.claimedByOffChainClaimer[account];
    }

    /// @inheritdoc IDistributionModule
    function getOffChainDistributionMintCap() external view returns (uint256) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        return $.offChainDistributionMintCap;
    }

    /// @inheritdoc IDistributionModule
    function getOffChainDistributionQueue()
        external
        view
        returns (QueuedOffChainDistribution[] memory)
    {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        return $.offChainDistributionQueue;
    }

    /// @inheritdoc IDistributionAllocator
    function setD(uint256 _d) external {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        _requireOnlyDistributionAllocator($);

        if (_d == 0) {
            revert InvalidInput();
        }
        if ($.d == _d) revert SameValue();

        $.d = _d;
        emit ParameterUpdated("d", _d);
    }

    /// @inheritdoc IDistributionAllocator
    function getD() external view returns (uint256) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        return $.d;
    }

    /// @inheritdoc IDistributionAllocator
    function setM0(uint256 _m0) external {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        _requireOnlyDistributionAllocator($);

        if (_m0 == 0) {
            revert InvalidInput();
        }

        if ($.m0 == _m0) revert SameValue();
        $.m0 = _m0;
        emit ParameterUpdated("m0", _m0);
    }

    /// @inheritdoc IDistributionAllocator
    function getM0() external view returns (uint256) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        return $.m0;
    }

    /// @inheritdoc IDistributionAllocator
    function setRateMin(uint256 _rateMin) external {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        _requireOnlyDistributionAllocator($);

        if (_rateMin == 0) {
            revert InvalidInput();
        }

        if ($.rateMin == _rateMin) revert SameValue();
        $.rateMin = _rateMin;
        emit ParameterUpdated("rateMin", _rateMin);
    }

    /// @inheritdoc IDistributionAllocator
    function getRateMin() external view returns (uint256) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        return $.rateMin;
    }

    /// @inheritdoc IDistributionAllocator
    function setBaseGamma(uint256 _baseGamma) external {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        _requireOnlyDistributionAllocator($);

        if (_baseGamma == 0) {
            revert InvalidInput();
        }

        if ($.baseGamma == _baseGamma) revert SameValue();
        $.baseGamma = _baseGamma;
        emit ParameterUpdated("baseGamma", _baseGamma);
    }

    /// @inheritdoc IDistributionAllocator
    function getBaseGamma() external view returns (uint256) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        return $.baseGamma;
    }

    /// @inheritdoc IDistributionAllocator
    function setFeeRates(uint256 _treasuryFeeRate, uint256 _usualXFeeRate) external {
        if (_treasuryFeeRate + _usualXFeeRate > BASIS_POINT_BASE) {
            revert InvalidRates();
        }

        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        _requireOnlyFeeRateSetter($);

        if (_treasuryFeeRate == $.treasuryFeeRate && _usualXFeeRate == $.usualXFeeRate) {
            revert SameValue();
        }

        $.treasuryFeeRate = _treasuryFeeRate;
        $.usualXFeeRate = _usualXFeeRate;
        uint256 burnFeeRate = BASIS_POINT_BASE - _treasuryFeeRate - _usualXFeeRate;

        emit FeeRatesSet(_treasuryFeeRate, _usualXFeeRate, burnFeeRate);
    }

    /// @inheritdoc IDistributionAllocator
    function getFeeRates() external view returns (uint256, uint256, uint256) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        uint256 burnFeeRate = BASIS_POINT_BASE - $.treasuryFeeRate - $.usualXFeeRate;
        return ($.treasuryFeeRate, $.usualXFeeRate, burnFeeRate);
    }

    /// @inheritdoc IDistributionAllocator
    function setBucketsDistribution(
        uint256 _lbt,
        uint256 _lyt,
        uint256 _iyt,
        uint256 _bribe,
        uint256 _eco,
        uint256 _dao,
        uint256 _marketMakers,
        uint256 _usualP,
        uint256 _usualStar
    ) external {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();

        _requireOnlyDistributionAllocator($);

        uint256 total = 0;
        total += _lbt;
        total += _lyt;
        total += _iyt;
        total += _bribe;
        total += _eco;
        total += _dao;
        total += _marketMakers;
        total += _usualP;
        total += _usualStar;

        if (total != BASIS_POINT_BASE) revert PercentagesSumNotEqualTo100Percent();

        _setLbt($, _lbt);
        _setLyt($, _lyt);
        _setIyt($, _iyt);
        _setBribe($, _bribe);
        _setEco($, _eco);
        _setDao($, _dao);
        _setMarketMakers($, _marketMakers);
        _setUsualP($, _usualP);
        _setUsualStar($, _usualStar);
    }

    /// @inheritdoc IDistributionOperator
    function distributeUsualToBuckets() external nonReentrant whenNotPaused {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();

        (uint256 ratet, uint256 p90Rate) = _getRateAndP90Rate($);
        if (ratet == 0 || ratet > BPS_SCALAR) {
            revert InvalidInput();
        }

        if (p90Rate == 0 || p90Rate >= BPS_SCALAR) {
            revert InvalidInput();
        }

        if (block.timestamp < $.lastOnChainDistributionTimestamp + DISTRIBUTION_FREQUENCY_SCALAR) {
            revert CannotDistributeUsualMoreThanOnceADay();
        }

        (,,,, uint256 usualDistribution) = _calculateUsualDistribution($, ratet, p90Rate);
        uint256 feeSwept = $.usualX.sweepFees() + IUsd0PP(address($.usd0PP)).sweepFees();

        // Update iUSD0++ distribution share before distribution
        _updateiUsd0ppDistributionShare($);

        $.lastOnChainDistributionTimestamp = block.timestamp;

        _distributeToOffChainBucket($, usualDistribution);
        uint256 feeAmountUsualX = _distributeToUsualXBucket($, usualDistribution, feeSwept);
        _distributeToUsualStarBucket($, usualDistribution);
        uint256 feeAmountYieldTreasury = _distributeFeesToYieldTreasury($, feeSwept);
        // Calculate the amount of fees to burn to avoid dust
        uint256 feesToBurn = feeSwept - feeAmountUsualX - feeAmountYieldTreasury;
        _burnFees($, feesToBurn);

        emit DailyDistributionRates(ratet, p90Rate);
    }

    /// @inheritdoc IDistributionOperator
    function queueOffChainUsualDistribution(bytes32 _merkleRoot) external whenNotPaused {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        _requireOnlyOperator($);

        if (_merkleRoot == bytes32(0)) {
            revert NullMerkleRoot();
        }

        $.offChainDistributionQueue.push(
            QueuedOffChainDistribution({timestamp: block.timestamp, merkleRoot: _merkleRoot})
        );
        emit OffChainDistributionQueued(block.timestamp, _merkleRoot);
    }

    /// @inheritdoc IDistributionOperator
    function resetOffChainDistributionQueue() external whenNotPaused {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        _requireOnlyOperator($);

        delete $.offChainDistributionQueue;
        emit OffChainDistributionQueueReset();
    }

    /// @inheritdoc IOffChainDistributionChallenger
    function challengeOffChainDistribution(uint256 _timestamp) external whenNotPaused {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        _requireOnlyChallenger($);

        _markQueuedOffChainDistributionsAsChallenged($, _timestamp);
        emit OffChainDistributionChallenged(_timestamp);
    }

    /// @inheritdoc IDistributionModule
    function getInitiatedRedirectedOffChainDistribution(address account)
        external
        view
        returns (address)
    {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        return $.initiatedRedirectedOffChainDistribution[account];
    }

    /// @inheritdoc IDistributionModule
    function getOngoingRedirectionChallenge(address account) external view returns (uint256) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        return $.initiatedRedirectedOffChainDistributionStartingTimestamp[account];
    }

    /// @inheritdoc IDistributionModule
    function getRedirectedAccount(address account) external view returns (address) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        return $.activeRedirectedOffChainDistribution[account];
    }

    /// @inheritdoc IDistributionModule
    function redirectOffChainDistribution(address account, address newAccount)
        external
        whenNotPaused
    {
        if (account == newAccount) {
            revert SameValue();
        }
        if (newAccount == address(0)) {
            revert InvalidInput();
        }

        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        _requireOnlyRedirectionAdmin($);

        if (
            $.initiatedRedirectedOffChainDistribution[account] != address(0)
                || $.initiatedRedirectedOffChainDistributionStartingTimestamp[account] != 0
        ) {
            revert AlreadyInitiatedRedirectedOffChainDistribution();
        }

        if ($.activeRedirectedOffChainDistribution[account] != address(0)) {
            revert AlreadyRedirectedOffChainDistribution();
        }

        $.initiatedRedirectedOffChainDistribution[account] = newAccount;
        $.initiatedRedirectedOffChainDistributionStartingTimestamp[account] = block.timestamp;
        emit OffChainDistributionRedirectInitialized(account, newAccount, block.timestamp);
    }

    /// @inheritdoc IDistributionModule
    function cancelInitiatedRedirectedOffChainDistribution(address account)
        external
        whenNotPaused
    {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();

        // Only the account that has been redirected to or the redirection-admin-role can cancel the initialized redirection
        if (msg.sender != account) {
            _requireOnlyRedirectionAdmin($);
        }
        if ($.initiatedRedirectedOffChainDistribution[account] == address(0)) {
            revert NoInitiatedRedirectedOffChainDistribution();
        }

        emit OffChainDistributionRedirectedCancelled(
            account, $.initiatedRedirectedOffChainDistribution[account]
        );

        delete $.initiatedRedirectedOffChainDistribution[account];
        delete $.initiatedRedirectedOffChainDistributionStartingTimestamp[account];
    }

    /// @inheritdoc IDistributionModule
    function removeRedirectedOffChainDistribution(address account) external whenNotPaused {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        if (msg.sender != account) {
            _requireOnlyRedirectionAdmin($);
        }

        if ($.activeRedirectedOffChainDistribution[account] == address(0)) {
            revert NoActiveRedirectedOffChainDistribution();
        }

        delete $.activeRedirectedOffChainDistribution[account];
        emit OffChainDistributionRedirectedRemoved(account);
    }

    /// @inheritdoc IDistributionModule
    function acceptRedirectedOffChainDistribution(address account) external whenNotPaused {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();

        // Only the account that has been redirected to or the redirection-admin-role can accept the redirection
        if (msg.sender != $.initiatedRedirectedOffChainDistribution[account]) {
            _requireOnlyRedirectionAdmin($);
        }

        if ($.initiatedRedirectedOffChainDistributionStartingTimestamp[account] == 0) {
            revert NoInitiatedRedirectedOffChainDistribution();
        }

        // Check if the challenge time interval has passed
        if (
            $.initiatedRedirectedOffChainDistributionStartingTimestamp[account]
                + REDIRECTION_DISTRIBUTION_CHALLENGE_PERIOD > block.timestamp
        ) {
            revert OffChainDistributionRedirectTimeIntervalNotPassed();
        }

        $.activeRedirectedOffChainDistribution[account] =
            $.initiatedRedirectedOffChainDistribution[account];

        delete $.initiatedRedirectedOffChainDistribution[account];
        delete $.initiatedRedirectedOffChainDistributionStartingTimestamp[account];

        emit OffChainDistributionRedirectedAccepted(
            account, $.activeRedirectedOffChainDistribution[account]
        );
    }

    /// @inheritdoc IDistributionModule
    function updateIUsd0ppVault(address newVault) external {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        _requireOnlyVaultUpdater($);

        if (newVault == address($.iUsd0ppVault)) {
            revert SameValue();
        }

        // Update the iUsd0ppVault
        $.iUsd0ppVault = IERC4626(newVault);
    }

    /// @notice Retrieve the blended weekly interest rate and the 90th percentile weekly interest rate from the Yield Module
    /// @param $ Storage struct of the contract
    /// @return Blended weekly interest rate
    /// @return p90 rate
    function _getRateAndP90Rate(DistributionModuleStorageV0 storage $)
        internal
        view
        returns (uint256, uint256)
    {
        return ($.yieldModule.getBlendedWeeklyInterest(), $.yieldModule.getP90InterestRate());
    }

    /// @notice Marks off-chain distributions older than the specified timestamp as challenged
    /// @param $ Storage struct of the contract
    /// @param _timestamp Timestamp before which the off-chain distribution will be challenged
    function _markQueuedOffChainDistributionsAsChallenged(
        DistributionModuleStorageV0 storage $,
        uint256 _timestamp
    ) internal {
        uint256 i = 0;
        while (i < $.offChainDistributionQueue.length) {
            QueuedOffChainDistribution storage distribution = $.offChainDistributionQueue[i];
            bool isAfterChallengePeriod =
                block.timestamp >= distribution.timestamp + USUAL_DISTRIBUTION_CHALLENGE_PERIOD;

            if (distribution.timestamp < _timestamp && !isAfterChallengePeriod) {
                // Swap with the last element and pop
                $.offChainDistributionQueue[i] =
                    $.offChainDistributionQueue[$.offChainDistributionQueue.length - 1];
                $.offChainDistributionQueue.pop();
                // Don't increment i, as we need to check the swapped element
            } else {
                // Only increment if we didn't remove an element
                i++;
            }
        }
    }

    /// @notice Increases the mint cap for the off-chain distribution by the calculated share of the distribution
    /// @param $ Storage struct of the contract
    /// @param usualDistribution Amount of Usual to distribute to all buckets
    /// @dev If the off-chain buckets share is 0, the function will return without increasing the mint cap
    function _distributeToOffChainBucket(
        DistributionModuleStorageV0 storage $,
        uint256 usualDistribution
    ) internal {
        uint256 offChainBucketsShare =
            BASIS_POINT_BASE - $.usualXDistributionShare - $.usualStarDistributionShare;
        if (offChainBucketsShare == 0) {
            return;
        }

        uint256 amount =
            Math.mulDiv(usualDistribution, offChainBucketsShare, BPS_SCALAR, Math.Rounding.Floor);

        $.offChainDistributionMintCap += amount;

        emit UsualAllocatedForOffChainClaim(amount);
    }

    /// @notice Mints Usual to UsualX and starts the yield distribution by the calculated share of the distribution
    /// @param $ Storage struct of the contract
    /// @param usualDistribution Amount of Usual to distribute to all buckets
    /// @param feeSwept Amount of fees swept from UsualX
    /// @dev If the UsualX share is 0, the function will return without minting Usual to UsualX
    function _distributeToUsualXBucket(
        DistributionModuleStorageV0 storage $,
        uint256 usualDistribution,
        uint256 feeSwept
    ) internal returns (uint256 feeAmount) {
        if ($.usualXDistributionShare == 0) {
            return 0;
        }

        uint256 amount = Math.mulDiv(
            usualDistribution, $.usualXDistributionShare, BPS_SCALAR, Math.Rounding.Floor
        );

        feeAmount = _distributeFeesToUsualX($, feeSwept);

        emit UsualAllocatedForUsualX(amount);

        $.usual.mint(address($.usualX), amount);
        $.usualX.startYieldDistribution(
            amount + feeAmount, block.timestamp, block.timestamp + DISTRIBUTION_FREQUENCY_SCALAR
        );
    }

    /// @notice Mints Usual to this contract, increases the allowance for UsualSP and starts the yield distribution by the calculated share of the distribution
    /// @param $ Storage struct of the contract
    /// @param usualDistribution Amount of Usual to distribute to all buckets
    /// @dev If the UsualStar share is 0, the function will return without minting Usual to this contract
    function _distributeToUsualStarBucket(
        DistributionModuleStorageV0 storage $,
        uint256 usualDistribution
    ) internal {
        if ($.usualStarDistributionShare == 0) {
            return;
        }

        uint256 amount = Math.mulDiv(
            usualDistribution, $.usualStarDistributionShare, BPS_SCALAR, Math.Rounding.Floor
        );

        emit UsualAllocatedForUsualStar(amount);

        $.usual.mint(address(this), amount);
        $.usual.safeIncreaseAllowance(address($.usualSP), amount);

        $.usualSP.startRewardDistribution(
            amount, block.timestamp, block.timestamp + DISTRIBUTION_FREQUENCY_SCALAR
        );
    }

    /// @notice Distributes some of the fee swept from UsualX and Usd0PP to UsualX
    /// @param $ Storage struct of the contract
    /// @param feeSwept Amount of fees swept from UsualX and Usd0PP
    /// @return feeAmount Amount of fees allocated to UsualX
    function _distributeFeesToUsualX(DistributionModuleStorageV0 storage $, uint256 feeSwept)
        internal
        returns (uint256 feeAmount)
    {
        feeAmount = Math.mulDiv(feeSwept, $.usualXFeeRate, BASIS_POINT_BASE, Math.Rounding.Floor);
        if (feeAmount > 0) {
            $.usual.safeTransfer(address($.usualX), feeAmount);
            emit UsualFeeAllocatedToUsualX(feeAmount);
        }
    }

    /// @notice Distributes some of the fee swept from UsualX and Usd0PP to the yield treasury
    /// @param $ Storage struct of the contract
    /// @param feeSwept Amount of fees swept from UsualX and Usd0PP
    function _distributeFeesToYieldTreasury(DistributionModuleStorageV0 storage $, uint256 feeSwept)
        internal
        returns (uint256 feeAmount)
    {
        address yieldTreasury = $.registryContract.getContract(CONTRACT_YIELD_TREASURY);

        feeAmount = Math.mulDiv(feeSwept, $.treasuryFeeRate, BASIS_POINT_BASE, Math.Rounding.Floor);
        if (feeAmount > 0) {
            $.usual.safeTransfer(yieldTreasury, feeAmount);
            emit UsualFeeAllocatedToYieldTreasury(feeAmount);
        }
    }

    /// @notice Burns some of the fee swept from UsualX and Usd0PP
    /// @param $ Storage struct of the contract
    /// @param feesToBurn Amount of fees to burn
    function _burnFees(DistributionModuleStorageV0 storage $, uint256 feesToBurn) internal {
        if (feesToBurn > 0) {
            $.usual.burn(feesToBurn);
            emit UsualFeeBurned(feesToBurn);
        }
    }

    /// @notice Sets the LBT distribution percentage
    /// @param $ Storage struct of the contract
    /// @param _lbt LBT distribution percentage
    function _setLbt(DistributionModuleStorageV0 storage $, uint256 _lbt) internal {
        $.lbtDistributionShare = _lbt;
        emit ParameterUpdated("lbt", _lbt);
    }

    /// @notice Sets the LYT distribution percentage
    /// @param $ Storage struct of the contract
    /// @param _lyt LYT distribution percentage
    function _setLyt(DistributionModuleStorageV0 storage $, uint256 _lyt) internal {
        $.lytDistributionShare = _lyt;
        emit ParameterUpdated("lyt", _lyt);
    }

    /// @notice Sets the IYT distribution percentage
    /// @param $ Storage struct of the contract
    /// @param _iyt IYT distribution percentage
    function _setIyt(DistributionModuleStorageV0 storage $, uint256 _iyt) internal {
        $.iytDistributionShare = _iyt;
        emit ParameterUpdated("iyt", _iyt);
    }

    /// @notice Sets the Bribe distribution percentage
    /// @param $ Storage struct of the contract
    /// @param _bribe Bribe distribution percentage
    function _setBribe(DistributionModuleStorageV0 storage $, uint256 _bribe) internal {
        $.bribeDistributionShare = _bribe;
        emit ParameterUpdated("bribe", _bribe);
    }

    /// @notice Sets the Eco distribution percentage
    /// @param $ Storage struct of the contract
    /// @param _eco Eco distribution percentage
    function _setEco(DistributionModuleStorageV0 storage $, uint256 _eco) internal {
        $.ecoDistributionShare = _eco;
        emit ParameterUpdated("eco", _eco);
    }

    /// @notice Sets the DAO distribution percentage
    /// @param $ Storage struct of the contract
    /// @param _dao DAO distribution percentage
    function _setDao(DistributionModuleStorageV0 storage $, uint256 _dao) internal {
        $.daoDistributionShare = _dao;
        emit ParameterUpdated("dao", _dao);
    }

    /// @notice Sets the MarketMakers distribution percentage
    /// @param $ Storage struct of the contract
    /// @param _marketMakers MarketMakers distribution percentage
    function _setMarketMakers(DistributionModuleStorageV0 storage $, uint256 _marketMakers)
        internal
    {
        $.marketMakersDistributionShare = _marketMakers;
        emit ParameterUpdated("marketMakers", _marketMakers);
    }

    /// @notice Sets the UsualP distribution percentage
    /// @param $ Storage struct of the contract
    /// @param _usualX UsualX distribution percentage
    function _setUsualP(DistributionModuleStorageV0 storage $, uint256 _usualX) internal {
        $.usualXDistributionShare = _usualX;
        emit ParameterUpdated("usualX", _usualX);
    }

    /// @notice Sets the UsualStar distribution percentage
    /// @param $ Storage struct of the contract
    /// @param _usualStar UsualStar distribution percentage
    function _setUsualStar(DistributionModuleStorageV0 storage $, uint256 _usualStar) internal {
        $.usualStarDistributionShare = _usualStar;
        emit ParameterUpdated("usualStar", _usualStar);
    }

    /// @notice Calculates gamma scaled since lastOnChainDistributionTimestamp
    /// @param $ Storage struct of the contract
    /// @return Gamma scale factor
    function _calculateGamma(DistributionModuleStorageV0 storage $)
        internal
        view
        returns (uint256)
    {
        uint256 timePassed = block.timestamp - $.lastOnChainDistributionTimestamp;
        if (timePassed <= DISTRIBUTION_FREQUENCY_SCALAR || $.lastOnChainDistributionTimestamp == 0)
        {
            return Math.mulDiv($.baseGamma, SCALAR_ONE, BPS_SCALAR, Math.Rounding.Floor);
        }
        uint256 denominator =
            Math.mulDiv(SCALAR_ONE, timePassed, DISTRIBUTION_FREQUENCY_SCALAR, Math.Rounding.Floor);
        uint256 numerator = Math.mulDiv($.baseGamma, SCALAR_ONE, BPS_SCALAR, Math.Rounding.Floor);
        return Math.mulDiv(numerator, SCALAR_ONE, denominator, Math.Rounding.Floor);
    }

    /// @notice Calculates the UsualDist value
    /// @dev Raw equation: UsualDist = (d * Mt * supplyPpt * pt) / (365 days)
    /// @param mt Mt value (scaled by SCALAR_ONE)
    /// @param supplyPpt Current supply (scaled by SCALAR_ONE)
    /// @param pt Current price (scaled by SCALAR_ONE)
    /// @return UsualDist value (raw, not scaled)
    function _calculateDistribution(uint256 mt, uint256 supplyPpt, uint256 pt)
        internal
        view
        returns (uint256)
    {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        uint256 totalSupply = _calculateTotalSupply(supplyPpt);
        // NOTE: d has BPS precision
        uint256 result = Math.mulDiv($.d, mt, BPS_SCALAR, Math.Rounding.Floor); // scales mt by BPS_SCALAR then divides by BPS_SCALAR to keep the same scale
        result = Math.mulDiv(result, totalSupply, SCALAR_ONE, Math.Rounding.Floor); // 10**18 * 10**18 / 10**18 = 10**18
        result = Math.mulDiv(result, pt, SCALAR_ONE, Math.Rounding.Floor); // 10**18 * 10**18 / 10**18 = 10**18

        return Math.mulDiv(result, 1, 365, Math.Rounding.Floor);
    }

    /// @notice Returns the price of usd0 token
    /// @dev $1 unless CBR is on
    /// @param $ Storage struct of the contract
    function _getUSD0Price(DistributionModuleStorageV0 storage $) internal view returns (uint256) {
        if ($.daoCollateral.isCBROn()) {
            uint256 cbr = $.daoCollateral.cbrCoef();
            return Math.mulDiv(SCALAR_ONE, cbr, SCALAR_ONE, Math.Rounding.Floor);
        }
        return SCALAR_ONE;
    }

    /// @notice Calculates the Rt value
    /// @param $ Storage struct of the contract
    /// @param ratet Current rate in BPS
    /// @param p90Rate 90th percentile rate (scaled by BPS_SCALAR)
    /// @return Rt value (scaled by SCALAR_ONE)
    function _calculateRt(DistributionModuleStorageV0 storage $, uint256 ratet, uint256 p90Rate)
        internal
        view
        returns (uint256)
    {
        uint256 maxRate = ratet > $.rateMin ? ratet : $.rateMin; // scaled by 10_000
        uint256 minMaxRate = p90Rate < maxRate ? p90Rate : maxRate; // scaled by 10_000
        uint256 result = Math.mulDiv(SCALAR_ONE, minMaxRate, $.rate0, Math.Rounding.Floor); // scales minMaxRate by BPS_SCALAR then divides by $.rate0 to keep the same scale
        return result;
    }

    /// @notice Calculates the St value
    /// @param $ Storage struct of the contract
    /// @param supplyUSD0PP Current supply (scaled by SCALAR_ONE)
    /// @param pt Current price (scaled by SCALAR_ONE)
    /// @return St value (scaled by SCALAR_ONE)
    function _calculateSt(DistributionModuleStorageV0 storage $, uint256 supplyUSD0PP, uint256 pt)
        internal
        view
        returns (uint256)
    {
        uint256 totalSupply = _calculateTotalSupply(supplyUSD0PP);
        // NOTE: everything has 10^18 precision
        uint256 numerator = Math.mulDiv($.initialSupplyPp0, $.p0, SCALAR_ONE); // scaled by 10**18 * 10**18 / 10**18 = 10**18
        uint256 denominator = Math.mulDiv(totalSupply, pt, SCALAR_ONE); // scaled by 10**18 * 10**18 / 10**18 = 10**18
        // NOTE: Good up to 10_000_000_000_000 supply, 10_000_000_000 price, with 10**18 precision
        // NOTE: (2^256-1) > (10000000000000*10**18)*(10000000000*10**18)*10**18
        uint256 result = Math.mulDiv(SCALAR_ONE, numerator, denominator, Math.Rounding.Floor); // scales numerator by 10**18 then divides by 10**18 to keep the same scale

        return result < SCALAR_ONE ? result : SCALAR_ONE;
    }

    /// @notice Calculates the Kappa value
    /// @param $ Storage struct of the contract
    /// @param ratet Current rate in BPS
    /// @return Kappa value (scaled by SCALAR_ONE)
    function _calculateKappa(DistributionModuleStorageV0 storage $, uint256 ratet)
        internal
        view
        returns (uint256)
    {
        uint256 maxRate = ratet > $.rateMin ? ratet : $.rateMin; // scaled by 10_000
        uint256 numerator = Math.mulDiv($.m0, maxRate, BPS_SCALAR); // scaled by 10**18 * 10_000 /10_000 = 10**18
        uint256 denominator = Math.mulDiv(_calculateGamma($), $.rate0, BPS_SCALAR); // scaled by 10**18 * 10**5 / 10**5 = 10**18
        return Math.mulDiv(numerator, SCALAR_ONE, denominator, Math.Rounding.Floor); // scales numerator 10*18 then divides to keep 10**18 scale
    }

    /// @notice Calculates the Mt value
    /// @param $ Storage struct of the contract
    /// @param st St value (scaled by SCALAR_ONE)
    /// @param rt Rt value (scaled by SCALAR_ONE)
    /// @param kappa Kappa value (scaled by SCALAR_ONE)
    /// @return Mt value (scaled by SCALAR_ONE)
    function _calculateMt(
        DistributionModuleStorageV0 storage $,
        uint256 st,
        uint256 rt,
        uint256 kappa
    ) internal view returns (uint256) {
        // (10*10**18*) * 10**18 = 10**37
        uint256 numerator = Math.mulDiv($.m0, st, SCALAR_ONE, Math.Rounding.Floor); // scaled by 10**18 * 10**18 / 10**18 = 10**18
        numerator = Math.mulDiv(numerator, rt, SCALAR_ONE, Math.Rounding.Floor); // scaled by 10**18 * 10**18 / 10**18 = 10**18
        uint256 result = Math.mulDiv(numerator, SCALAR_ONE, _calculateGamma($)); // scales numerator by 10**18  then divides by 10**18  to keep the same scale
        return result < kappa ? result : kappa;
    }

    /// @notice Calculates total supply including both USD0++ and vault value
    /// @param usd0ppSupply Current USD0++ supply
    /// @return Total supply equivalent in USD with 18 decimals precision
    function _calculateTotalSupply(uint256 usd0ppSupply) internal view returns (uint256) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();

        return usd0ppSupply + _calculateVaultValueInUSD($);
    }

    /// @notice Calculates the USD value of assets in the vault
    /// @param $ Storage struct of the contract
    /// @return vaultValueUSD The USD value of assets in the vault with 18 decimals precision
    function _calculateVaultValueInUSD(DistributionModuleStorageV0 storage $)
        internal
        view
        returns (uint256 vaultValueUSD)
    {
        // If vault not set, return 0
        if (address($.iUsd0ppVault) == address(0)) {
            return 0;
        }
        uint256 iUsd0ppPrice;
        try $.oracle.getPrice(address($.iUsd0ppVault)) returns (uint256 price) {
            iUsd0ppPrice = price;
        } catch {
            // If the oracle call reverts, set iUsd0ppPrice to 0
            iUsd0ppPrice = 0;
        }

        uint256 totalAssets = $.iUsd0ppVault.totalAssets();

        // Check if the price is valid before calculating vaultValueUSD
        if (iUsd0ppPrice > 0) {
            // Correctly scale the result to 18 decimals
            vaultValueUSD = (totalAssets * iUsd0ppPrice)
                / 10 ** IERC20Metadata($.iUsd0ppVault.asset()).decimals();
        } else {
            // If the oracle call reverts, we treat the vault as empty
            vaultValueUSD = 0;
        }
    }

    /// @notice Calculates all values: St, Rt, Mt, and UsualDist
    /// @param ratet The current interest rate with BPS precision
    /// @param p90Rate The 90th percentile interest rate over the last 60 days with BPS precision
    /// @return st St value (scaled by SCALAR_ONE)
    /// @return rt Rt value (scaled by SCALAR_ONE)
    /// @return kappa Kappa value (scaled by SCALAR_ONE)
    /// @return mt Mt value (scaled by SCALAR_ONE)
    /// @return usualDist UsualDist value (raw, not scaled)
    function _calculateUsualDistribution(
        DistributionModuleStorageV0 storage $,
        uint256 ratet,
        uint256 p90Rate
    )
        internal
        view
        returns (uint256 st, uint256 rt, uint256 kappa, uint256 mt, uint256 usualDist)
    {
        uint256 currentSupplyUsd0PP = $.usd0PP.totalSupply();
        uint256 pt = _getUSD0Price($);

        st = _calculateSt($, currentSupplyUsd0PP, pt);
        rt = _calculateRt($, ratet, p90Rate);
        kappa = _calculateKappa($, ratet);
        mt = _calculateMt($, st, rt, kappa);
        usualDist = _calculateDistribution(mt, currentSupplyUsd0PP, pt);
    }

    /// @notice Verifies the off-chain distribution Merkle proof
    /// @param $ Storage struct of the contract
    /// @param account Account to claim for
    /// @param amount Amount of Usual token to claim
    /// @param proof Merkle proof
    function _verifyOffChainDistributionMerkleProof(
        DistributionModuleStorageV0 storage $,
        address account,
        uint256 amount,
        bytes32[] calldata proof
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        return MerkleProof.verify(proof, $.offChainDistributionMerkleRoot, leaf);
    }

    /// @notice Updates the iUSD0++ distribution share based on current supply ratios
    /// @dev This should be called before distribution calculations to ensure up-to-date share
    /// @param $ Storage struct of the contract
    function _updateiUsd0ppDistributionShare(DistributionModuleStorageV0 storage $) internal {
        uint256 currentSupplyUsd0PP = $.usd0PP.totalSupply();
        uint256 adjustedIUsd0ppSupply = _calculateVaultValueInUSD($);
        // Calculate iUSD0++ Share share using the iUSD0++ share factor and LBT portion
        uint256 iUSD0ppShare = _calculateiUSD0ppShare(adjustedIUsd0ppSupply, currentSupplyUsd0PP);

        // Update the iUSD0++ distribution share
        if ($.iUSD0ppDistributionShareOfLbt != iUSD0ppShare) {
            $.iUSD0ppDistributionShareOfLbt = iUSD0ppShare;
            emit ParameterUpdated("iUSD0ppDistributionShareOfLbt", iUSD0ppShare);
        }
    }

    /// @notice Calculates the iUSD0++ share of the distribution
    /// @param adjustediUSD0ppSupply The adjusted supply from iUSD0++ vault
    /// @param supplyPpt The total USD0++ supply
    /// @return iUSD0ppShare The calculated share for iUSD0++ with 18 decimal place precision
    /// @dev Share calculation: adjusted_iUSD0++_supply/(supplyPp_t+adjusted_iUSD0++_supply)
    function _calculateiUSD0ppShare(uint256 adjustediUSD0ppSupply, uint256 supplyPpt)
        internal
        pure
        returns (uint256 iUSD0ppShare)
    {
        // If no iUSD0++ supply, return 0
        if (adjustediUSD0ppSupply == 0) {
            return 0;
        }

        // Calculate iUSD0++ share of LBT: adjusted_iUSD0++_supply[i]/(supplyPp_t[i]+adjusted_iUSD0++_supply[i])
        iUSD0ppShare = Math.mulDiv(
            adjustediUSD0ppSupply,
            SCALAR_ONE,
            supplyPpt + adjustediUSD0ppSupply,
            Math.Rounding.Floor
        );
    }

    /// @notice Gets the current iUSD0++ distribution share of LBT
    /// @return The current iUSD0++ distribution share with 18 decimals precision
    /// @dev This value represents what portion of the LBT distribution should go to iUSD0++ holders
    function getiUSD0ppDistributionShareOfLbt() external view returns (uint256) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        return $.iUSD0ppDistributionShareOfLbt;
    }

    /// @inheritdoc IDistributionModule
    function getIUsd0ppVault() external view returns (address) {
        DistributionModuleStorageV0 storage $ = _distributionModuleStorageV0();
        return address($.iUsd0ppVault);
    }
}
