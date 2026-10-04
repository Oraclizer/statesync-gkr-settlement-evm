// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

import {IPrimaryFinalityAuthorityV2} from "./interfaces/IPrimaryFinalityAuthorityV2.sol";
import {ReceiptRootEncodingV2} from "./libraries/ReceiptRootEncodingV2.sol";

/// @notice Epoch-2 route-bound PFR quorum consumed only by its stable lineage settlement.
contract PrimaryFinalityAuthorityV2 is IPrimaryFinalityAuthorityV2 {
    uint256 public constant MAX_SIGNERS = 16;
    uint256 internal constant SECP256K1_HALF_N =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    error EpochTwoRequired();
    error InvalidThreshold();
    error TooManySigners();
    error TooManySignatures();
    error ZeroConfiguredSigner();
    error ConfiguredSignersNotSorted();
    error DuplicateConfiguredSigner();
    error InvalidValidityWindow();
    error SettlementOnly();
    error AuthorizationContextMismatch();
    error UnexpectedAuthorizationNonce();
    error PreviousAuthorizationDigestMismatch();
    error InvalidSignature();
    error HighSignatureS();
    error InvalidRecoveryId();
    error ZeroAttester();
    error AttestersNotSorted();
    error DuplicateAttester();
    error UnauthorizedAttester();
    error BelowThreshold();
    error ArithmeticOverflow();

    event PrimaryFinalityAuthorizedV2(
        bytes32 indexed routeId,
        bytes32 indexed primaryFinalityRecordId,
        bytes32 indexed authorizationDigest,
        uint64 lifecycleRevision,
        uint64 authorizationNonce,
        uint64 validUntilBlock,
        address[] attesters
    );

    bytes32 public immutable routeId;
    address public immutable lifecycleRegistry;
    address public immutable destinationSettlement;
    uint64 public immutable signerSetEpoch;
    uint16 public immutable threshold;
    uint64 public immutable maxValidityWindowBlocks;

    address[] internal configuredSigners;
    mapping(address => bool) internal configuredSigner;
    uint64 public nextAuthorizationNonce = 1;
    bytes32 public lastAuthorizationDigest;
    bytes32 internal authorizationsAccumulator;
    uint64 internal transitions;
    uint64 internal eventsEmitted;

    constructor(
        bytes32 routeId_,
        address lifecycleRegistry_,
        address destinationSettlement_,
        uint64 signerSetEpoch_,
        address[] memory configuredSigners_,
        uint16 threshold_,
        uint64 maxValidityWindowBlocks_
    ) {
        if (signerSetEpoch_ != 2) revert EpochTwoRequired();
        if (maxValidityWindowBlocks_ == 0) revert InvalidValidityWindow();
        uint256 length = configuredSigners_.length;
        if (length > MAX_SIGNERS) revert TooManySigners();
        if (threshold_ == 0 || threshold_ > length) revert InvalidThreshold();
        address previous;
        for (uint256 i; i < length; ++i) {
            address signer = configuredSigners_[i];
            if (signer == address(0)) revert ZeroConfiguredSigner();
            if (i != 0) {
                if (signer == previous) revert DuplicateConfiguredSigner();
                if (signer < previous) revert ConfiguredSignersNotSorted();
            }
            configuredSigner[signer] = true;
            configuredSigners.push(signer);
            previous = signer;
        }
        routeId = routeId_;
        lifecycleRegistry = lifecycleRegistry_;
        destinationSettlement = destinationSettlement_;
        signerSetEpoch = signerSetEpoch_;
        threshold = threshold_;
        maxValidityWindowBlocks = maxValidityWindowBlocks_;
    }

    function consumeAuthorization(Authorization calldata authorization, bytes[] calldata signatures)
        external
        returns (bytes32 digest)
    {
        if (msg.sender != destinationSettlement) revert SettlementOnly();
        if (
            authorization.routeId != routeId || authorization.lifecycleRegistry != lifecycleRegistry
                || authorization.destinationSettlement != destinationSettlement
                || authorization.signerSetEpoch != 2
                || authorization.signerSetEpoch != signerSetEpoch
        ) revert AuthorizationContextMismatch();
        _validateWindow(authorization.validAfterBlock, authorization.validUntilBlock);
        if (authorization.authorizationNonce != nextAuthorizationNonce) {
            revert UnexpectedAuthorizationNonce();
        }
        if (authorization.previousAuthorizationDigest != lastAuthorizationDigest) {
            revert PreviousAuthorizationDigestMismatch();
        }
        digest = ReceiptRootEncodingV2.pfrAuthorizationDigest(
            authorization, block.chainid, address(this)
        );
        address[] memory attesters = _recoverAndValidate(digest, signatures);
        if (
            nextAuthorizationNonce == type(uint64).max || transitions == type(uint64).max
                || eventsEmitted == type(uint64).max
        ) revert ArithmeticOverflow();
        authorizationsAccumulator = keccak256(
            abi.encode(
                authorizationsAccumulator,
                authorization.primaryFinalityRecordId,
                digest,
                keccak256(abi.encode(attesters))
            )
        );
        lastAuthorizationDigest = digest;
        unchecked {
            ++nextAuthorizationNonce;
            ++transitions;
            ++eventsEmitted;
        }
        emit PrimaryFinalityAuthorizedV2(
            routeId,
            authorization.primaryFinalityRecordId,
            digest,
            authorization.lifecycleRevision,
            authorization.authorizationNonce,
            authorization.validUntilBlock,
            attesters
        );
    }

    function authorizationDigest(Authorization calldata authorization)
        external
        view
        returns (bytes32)
    {
        return ReceiptRootEncodingV2.pfrAuthorizationDigest(
            authorization, block.chainid, address(this)
        );
    }

    function isConfiguredSigner(address signer) external view returns (bool) {
        return configuredSigner[signer];
    }

    function configuredSignerCount() external view returns (uint256) {
        return configuredSigners.length;
    }

    function configuredSignerAt(uint256 index) external view returns (address) {
        return configuredSigners[index];
    }

    function transitionCount() external view returns (uint64) {
        return transitions;
    }

    function eventCount() external view returns (uint64) {
        return eventsEmitted;
    }

    function stateDigest() external view returns (bytes32) {
        return keccak256(
            abi.encode(
                "SSGKR_PRIMARY_FINALITY_AUTHORITY_STATE_V2",
                routeId,
                lifecycleRegistry,
                destinationSettlement,
                signerSetEpoch,
                threshold,
                maxValidityWindowBlocks,
                configuredSigners,
                nextAuthorizationNonce,
                lastAuthorizationDigest,
                transitions,
                eventsEmitted,
                authorizationsAccumulator
            )
        );
    }

    function _validateWindow(uint64 validAfterBlock, uint64 validUntilBlock) private view {
        if (
            validUntilBlock <= validAfterBlock || block.number < validAfterBlock
                || block.number >= validUntilBlock
                || uint256(validUntilBlock) - validAfterBlock > maxValidityWindowBlocks
        ) revert InvalidValidityWindow();
    }

    function _recoverAndValidate(bytes32 digest, bytes[] calldata signatures)
        private
        view
        returns (address[] memory attesters)
    {
        if (signatures.length > configuredSigners.length || signatures.length > MAX_SIGNERS) {
            revert TooManySignatures();
        }
        attesters = new address[](signatures.length);
        address previous;
        for (uint256 i; i < signatures.length; ++i) {
            address signer = _recover(digest, signatures[i]);
            if (i != 0) {
                if (signer == previous) revert DuplicateAttester();
                if (signer < previous) revert AttestersNotSorted();
            }
            if (!configuredSigner[signer]) revert UnauthorizedAttester();
            attesters[i] = signer;
            previous = signer;
        }
        if (attesters.length < threshold) revert BelowThreshold();
    }

    function _recover(bytes32 digest, bytes calldata signature)
        private
        pure
        returns (address recovered)
    {
        if (signature.length != 65) revert InvalidSignature();
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        if (r == bytes32(0) || s == bytes32(0)) revert InvalidSignature();
        if (uint256(s) > SECP256K1_HALF_N) revert HighSignatureS();
        if (v != 27 && v != 28) revert InvalidRecoveryId();
        recovered = ecrecover(digest, v, r, s);
        if (recovered == address(0)) revert ZeroAttester();
    }
}
