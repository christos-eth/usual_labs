// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

bytes32 constant ADMIN = keccak256("ADMIN");
bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
bytes32 constant DAO_COLLATERAL = keccak256("DAO_COLLATERAL_CONTRACT");
bytes32 constant USD0_MINT = keccak256("USD0_MINT");
bytes32 constant USD0_BURN = keccak256("USD0_BURN");
bytes32 constant INTENT_MATCHING_ROLE = keccak256("INTENT_MATCHING_ROLE");
bytes32 constant SWAPPER_ENGINE = keccak256("SWAPPER_ENGINE");
bytes32 constant INTENT_TYPE_HASH = keccak256(
    "SwapIntent(address recipient,address rwaToken,uint256 amountInTokenDecimals,uint256 nonce,uint256 deadline)"
);
/* Contracts */

bytes32 constant CONTRACT_REGISTRY_ACCESS = keccak256("CONTRACT_REGISTRY_ACCESS");
bytes32 constant CONTRACT_DAO_COLLATERAL = keccak256("CONTRACT_DAO_COLLATERAL");
bytes32 constant CONTRACT_USD0PP = keccak256("CONTRACT_USD0PP");
bytes32 constant CONTRACT_TOKEN_MAPPING = keccak256("CONTRACT_TOKEN_MAPPING");
bytes32 constant CONTRACT_ORACLE = keccak256("CONTRACT_ORACLE");
bytes32 constant CONTRACT_ORACLE_USUAL = keccak256("CONTRACT_ORACLE_USUAL");
bytes32 constant CONTRACT_DATA_PUBLISHER = keccak256("CONTRACT_DATA_PUBLISHER");
bytes32 constant CONTRACT_TREASURY = keccak256("CONTRACT_TREASURY");
bytes32 constant CONTRACT_SWAPPER_ENGINE = keccak256("CONTRACT_SWAPPER_ENGINE");
/* Contract tokens */
bytes32 constant CONTRACT_USD0 = keccak256("CONTRACT_USD0");
bytes32 constant CONTRACT_USDC = keccak256("CONTRACT_USDC");
/* Constants */
uint256 constant SCALAR_ONE = 1e18;
uint256 constant SCALAR_TEN_KWEI = 10_000;
uint256 constant MAX_REDEEM_FEE = 2500;
uint256 constant MINIMUM_USDC_PROVIDED = 100e6; //minimum of 100 USDC deposit;
// we take 12sec as the average block time
// 1 year = 3600sec * 24 hours * 365 days * 4 years  = 126144000 + 1 day // adding a leap day
uint256 constant BOND_DURATION_FOUR_YEAR = 126_230_400; //including a leap day;
uint256 constant BOND_START_DATE = 1_719_489_600; // Thu Jun 27 2024 12:00:00 GMT+0000
uint256 constant BASIS_POINT_BASE = 10_000;
uint64 constant ONE_WEEK = 604_800;
uint256 constant ONE_USDC = 1e6;

/*
 * The maximum relative price difference between two oracle responses allowed in order for the PriceFeed
 * to return to using the Oracle oracle. 18-digit precision.
 */

uint256 constant INITIAL_MAX_DEPEG_THRESHOLD = 100;

/* Maximum number of RWA tokens that can be associated with USD0 */
uint256 constant MAX_RWA_COUNT = 10;
