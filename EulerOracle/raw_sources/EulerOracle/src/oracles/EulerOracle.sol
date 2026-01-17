// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {IEVault} from "evk/EVault/IEVault.sol";
import {EulerRouter} from "epo/EulerRouter.sol";

/// @author  Usual Tech Team
/// @title   Euler Oracle Proxy
contract EulerOracle {
    /// @notice Address of the vault used by the oracle.
    address public immutable VAULT;
    /// @notice Address of the router used by the oracle.
    address public immutable ROUTER;

    /// @notice Precision used for calculations.
    uint256 public immutable PRECISION;

    /// @notice Constant representing USD
    address public constant USD = address(840);

    /**
     * @dev Represents the keccak256 hash of the string "CONTRACT_YIELD_TREASURY".
     * This constant is used to identify the Yield Treasury contract within the Usual Protocol system.
     */
    bytes32 constant CONTRACT_YIELD_TREASURY = keccak256("CONTRACT_YIELD_TREASURY");

    /**
     * @notice Constructor to initialize the EulerOracle contract.
     * @param _vault The address of the vault to be used by the oracle.
     */
    constructor(address _vault) {
        VAULT = _vault;
        ROUTER = IEVault(_vault).oracle();
        PRECISION = 10 ** IEVault(_vault).decimals();
    }

    /**
     * @notice Returns the number of decimals used.
     * @return The number of decimals (18).
     */
    function decimals() external pure returns (uint8) {
        // USD is considered to have 18 decimals.
        // See https://github.com/euler-xyz/euler-price-oracle/blob/deeffa7b518618202802f37865ed654070a7175f/src/adapter/BaseAdapter.sol
        return 18;
    }

    /**
     * @notice Fetches the latest round data from the oracle.
     * @return roundId The round ID. @dev not required for this oracle
     * @return answer The price answer from the oracle. 
     * @return startedAt The timestamp when the round started. @dev not required for this oracle
     * @return updatedAt The timestamp when the round was last updated.  @dev block.timestamp
     * @return answeredInRound The round ID in which the answer was computed. @dev not required for this oracle
     */
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        uint256 quote = EulerRouter(ROUTER).getQuote(PRECISION, VAULT, USD);
        return (0, int256(quote), 0, block.timestamp, 0);
    }
}
