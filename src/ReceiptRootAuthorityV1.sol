// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

import {IReceiptRootAuthorityV1} from "./interfaces/IReceiptRootAuthorityV1.sol";
import {ReceiptRootEncodingV1} from "./libraries/ReceiptRootEncodingV1.sol";

/// @notice Immutable, append-only receipt-root quorum and coordinate registry.
/// @dev Signatures are direct over the canonical digest: no personal-sign or EIP-712 prefix.
contract ReceiptRootAuthorityV1 is IReceiptRootAuthorityV1 {
    uint256 public constant MAX_SIGNERS = 16;
    uint256 internal constant SECP256K1_HALF_N =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    error InvalidThreshold();
    error TooManySigners();
    error TooManySignatures();
    error ZeroConfiguredSigner();
    error ConfiguredSignersNotSorted();
    error DuplicateConfiguredSigner();
    error InvalidSignature();
    error HighSignatureS();
    error InvalidRecoveryId();
    error ZeroAttester();
    error AttestersNotSorted();
    error DuplicateAttester();
    error UnauthorizedAttester();
    error BelowThreshold();
    error StaleSignerSetEpoch();
    error AuthorityContextMismatch();
    error InvalidLeafCount();
    error UnexpectedAuthorizationNonce();
    error AuthorizationReplay();
    error RootConflict();
    error ArithmeticOverflow();

    event ReceiptRootRegistered(
        bytes32 indexed coordinateId,
        bytes32 indexed authorizationDigest,
        bytes32 root,
        uint64 authorizationNonce,
        address[] attesters
    );

    uint64 public immutable signerSetEpoch;
    uint16 public immutable threshold;
    bytes32 public immutable sourceNetworkId;
    bytes32 public immutable sourceGenesisHash;
    bytes32 public immutable sourceRuntimeId;
    bytes32 public immutable verificationContextHash;
    uint32 public immutable domainId;

    address[] internal configuredSigners;
    mapping(address => bool) internal configuredSigner;
    mapping(bytes32 => RegisteredRoot) internal roots;
    mapping(bytes32 => address[]) internal rootAttesters;
    bytes32 internal recordsAccumulator;
    uint64 internal nextNonce = 1;
    uint64 internal transitions;
    uint64 internal eventsEmitted;

    constructor(
        uint64 signerSetEpoch_,
        address[] memory configuredSigners_,
        uint16 threshold_,
        bytes32 sourceNetworkId_,
        bytes32 sourceGenesisHash_,
        bytes32 sourceRuntimeId_,
        bytes32 verificationContextHash_,
        uint32 domainId_
    ) {
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
        signerSetEpoch = signerSetEpoch_;
        threshold = threshold_;
        sourceNetworkId = sourceNetworkId_;
        sourceGenesisHash = sourceGenesisHash_;
        sourceRuntimeId = sourceRuntimeId_;
        verificationContextHash = verificationContextHash_;
        domainId = domainId_;
    }

    function register(Authorization calldata authorization, bytes[] calldata signatures)
        external
        returns (bytes32 coordinate)
    {
        if (signatures.length > configuredSigners.length || signatures.length > MAX_SIGNERS) {
            revert TooManySignatures();
        }
        bytes32 digest = ReceiptRootEncodingV1.authorizationDigest(authorization);
        address[] memory attesters = _recoverAttesters(digest, signatures);
        _validateAttesters(attesters);

        coordinate = ReceiptRootEncodingV1.coordinateId(
            authorization.sourceNetworkId, authorization.domainId, authorization.aggregationId
        );
        RegisteredRoot storage existing = roots[coordinate];
        if (existing.exists) {
            if (existing.authorizationDigest == digest) revert AuthorizationReplay();
            revert RootConflict();
        }
        if (authorization.signerSetEpoch != signerSetEpoch) revert StaleSignerSetEpoch();
        if (
            authorization.sourceNetworkId != sourceNetworkId
                || authorization.sourceGenesisHash != sourceGenesisHash
                || authorization.sourceRuntimeId != sourceRuntimeId
                || authorization.verificationContextHash != verificationContextHash
                || authorization.domainId != domainId
        ) revert AuthorityContextMismatch();
        if (authorization.leafCount != 1) revert InvalidLeafCount();
        if (authorization.authorizationNonce != nextNonce) revert UnexpectedAuthorizationNonce();
        if (
            nextNonce == type(uint64).max || transitions == type(uint64).max
                || eventsEmitted == type(uint64).max
        ) {
            revert ArithmeticOverflow();
        }

        uint64 newNonce = nextNonce + 1;
        uint64 newTransitions = transitions + 1;
        uint64 newEvents = eventsEmitted + 1;
        RegisteredRoot memory record = RegisteredRoot({
            authorizationDigest: digest,
            attestersHash: keccak256(abi.encode(attesters)),
            root: authorization.root,
            leafCount: authorization.leafCount,
            sourceBlockNumber: authorization.sourceBlockNumber,
            sourceBlockHash: authorization.sourceBlockHash,
            sourceRuntimeId: authorization.sourceRuntimeId,
            verificationContextHash: authorization.verificationContextHash,
            authorizationNonce: authorization.authorizationNonce,
            exists: true
        });
        bytes32 newAccumulator = keccak256(
            abi.encode(recordsAccumulator, coordinate, record, keccak256(abi.encode(attesters)))
        );

        roots[coordinate] = record;
        rootAttesters[coordinate] = attesters;
        recordsAccumulator = newAccumulator;
        nextNonce = newNonce;
        transitions = newTransitions;
        eventsEmitted = newEvents;
        emit ReceiptRootRegistered(
            coordinate, digest, authorization.root, authorization.authorizationNonce, attesters
        );
    }

    function _recoverAttesters(bytes32 digest, bytes[] calldata signatures)
        internal
        pure
        returns (address[] memory attesters)
    {
        attesters = new address[](signatures.length);
        for (uint256 i; i < signatures.length; ++i) {
            attesters[i] = _recoverOrZero(digest, signatures[i]);
        }
    }

    /// @notice Strict single-signature recovery used by the frozen recovery oracle.
    function recoverSigner(bytes32 digest, bytes calldata signature)
        external
        pure
        returns (address)
    {
        return _recoverStrict(digest, signature);
    }

    function _recoverOrZero(bytes32 digest, bytes calldata sig) internal pure returns (address) {
        if (sig.length != 65) return address(0);
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
        if (r == bytes32(0) || s == bytes32(0) || uint256(s) > SECP256K1_HALF_N) return address(0);
        if (v != 27 && v != 28) return address(0);
        return ecrecover(digest, v, r, s);
    }

    function _recoverStrict(bytes32 digest, bytes calldata sig)
        internal
        pure
        returns (address recovered)
    {
        if (sig.length != 65) revert InvalidSignature();
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
        if (r == bytes32(0) || s == bytes32(0)) revert InvalidSignature();
        if (uint256(s) > SECP256K1_HALF_N) revert HighSignatureS();
        if (v != 27 && v != 28) revert InvalidRecoveryId();
        recovered = ecrecover(digest, v, r, s);
        if (recovered == address(0)) revert ZeroAttester();
    }

    function _validateAttesters(address[] memory attesters) internal view {
        address previous;
        for (uint256 i; i < attesters.length; ++i) {
            address signer = attesters[i];
            if (signer == address(0)) revert ZeroAttester();
            if (i != 0) {
                if (signer == previous) revert DuplicateAttester();
                if (signer < previous) revert AttestersNotSorted();
            }
            if (!configuredSigner[signer]) revert UnauthorizedAttester();
            previous = signer;
        }
        if (attesters.length < threshold) revert BelowThreshold();
    }

    function registeredRoot(bytes32 coordinate) external view returns (RegisteredRoot memory) {
        return roots[coordinate];
    }

    function registeredAttesters(bytes32 coordinate) external view returns (address[] memory) {
        return rootAttesters[coordinate];
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

    function nextAuthorizationNonce() external view returns (uint64) {
        return nextNonce;
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
                "SSGKR_RECEIPT_ROOT_EVM_STATE_V1",
                signerSetEpoch,
                threshold,
                configuredSigners,
                sourceNetworkId,
                sourceGenesisHash,
                sourceRuntimeId,
                verificationContextHash,
                domainId,
                nextNonce,
                transitions,
                eventsEmitted,
                recordsAccumulator
            )
        );
    }
}
