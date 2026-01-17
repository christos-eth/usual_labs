// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

error AlreadyClaimed();
error AlreadyWhitelisted();
error AmountTooBig();
error AmountTooLow();
error AmountIsZero();
error Blacklisted();

error Empty();
error ExpiredSignature(uint256 deadline);
error SameValue();

error Invalid();
error InvalidToken();
error InvalidName();
error InvalidSigner(address owner);
error InvalidDeadline(uint256 approvalDeadline, uint256 intentDeadline);
error NoOrdersIdsProvided();
error InvalidSymbol();

error LockedOffer();

error NotAuthorized();
error NotClaimableYet();
error NullAddress();
error NullContract();

error OracleNotWorkingNotCurrent();
error OracleNotInitialized();
error OutOfBounds();
error InvalidTimeout();

error RedeemMustNotBePaused();
error RedeemMustBePaused();
error SwapMustNotBePaused();
error SwapMustBePaused();

error StablecoinDepeg();
error DepegThresholdTooHigh();

error TokenNotWhitelist();

error BondNotStarted();
error BondFinished();
error BondNotFinished();

error BeginInPast();

error CBRIsTooHigh();
error CBRIsNull();

error RedeemFeeTooBig();
error CancelFeeTooBig();
error MinterRewardTooBig();
error CollateralProviderRewardTooBig();
error DistributionRatioInvalid();
error TooManyRWA();
error FailingTransfer();

error InsufficientUSD0Balance();
error USDCAmountNotFullyMatched();
error OrderNotActive();
error NotRequester();
error InsufficientUSD0Allowance();
error ApprovalFailed();
