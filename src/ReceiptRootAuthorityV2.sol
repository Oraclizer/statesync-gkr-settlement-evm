// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

import {IRouteLifecycleRegistryV2} from "./interfaces/IRouteLifecycleRegistryV2.sol";
import {IReceiptRootAuthorityV2} from "./interfaces/IReceiptRootAuthorityV2.sol";
import {ReceiptRootEncodingV2} from "./libraries/ReceiptRootEncodingV2.sol";

/// @notice Epoch-2 route-bound receipt-root authority with EIP-712 and a nonce hash chain.
contract ReceiptRootAuthorityV2 is IReceiptRootAuthorityV2 {
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
    error InvalidSignature();
    error HighSignatureS();
    error InvalidRecoveryId();
    error ZeroAttester();
    error AttestersNotSorted();
    error DuplicateAttester();
    error UnauthorizedAttester();
    error BelowThreshold();
    error AuthorizationContextMismatch();
    error AuthorityContextMismatch();
    error InvalidLeafCount();
    error RouteNotActive();
    error UnexpectedAuthorizationNonce();
    error PreviousAuthorizationDigestMismatch();
    error AuthorizationReplay();
    error RootConflict();
    error ArithmeticOverflow();

    event ReceiptRootRegisteredV2(
        bytes32 indexed routeId,
        bytes32 indexed coordinateId,
        bytes32 indexed authorizationDigest,
        bytes32 root,
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
    uint64 public nextAuthorizationNonce = 1;
    bytes32 public lastAuthorizationDigest;
    uint64 internal transitions;
    uint64 internal eventsEmitted;

    constructor(
        bytes32 routeId_,
        IRouteLifecycleRegistryV2 lifecycleRegistry_,
        address destinationSettlement_,
        uint64 signerSetEpoch_,
        address[] memory configuredSigners_,
        uint16 threshold_,
        uint64 maxValidityWindowBlocks_,
        bytes32 sourceNetworkId_,
        bytes32 sourceGenesisHash_,
        bytes32 sourceRuntimeId_,
        bytes32 verificationContextHash_,
        uint32 domainId_
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
        lifecycleRegistry = address(lifecycleRegistry_);
        destinationSettlement = destinationSettlement_;
        signerSetEpoch = signerSetEpoch_;
        threshold = threshold_;
        maxValidityWindowBlocks = maxValidityWindowBlocks_;
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
        if (block.number > type(uint64).max) revert ArithmeticOverflow();
        _validateContext(authorization);
        if (!IRouteLifecycleRegistryV2(lifecycleRegistry)
                .rootRegistrationAllowed(routeId, address(this), authorization.lifecycleRevision)) revert RouteNotActive();
        _validateWindow(authorization.validAfterBlock, authorization.validUntilBlock);
        if (authorization.authorizationNonce != nextAuthorizationNonce) {
            revert UnexpectedAuthorizationNonce();
        }
        if (authorization.previousAuthorizationDigest != lastAuthorizationDigest) {
            revert PreviousAuthorizationDigestMismatch();
        }

        bytes32 digest = ReceiptRootEncodingV2.rootAuthorizationDigest(
            authorization, block.chainid, address(this)
        );
        coordinate = ReceiptRootEncodingV2.coordinateId(
            routeId,
            authorization.sourceNetworkId,
            authorization.domainId,
            authorization.aggregationId
        );
        RegisteredRoot storage existing = roots[coordinate];
        if (existing.exists) {
            if (existing.authorizationDigest == digest) revert AuthorizationReplay();
            revert RootConflict();
        }
        address[] memory attesters = _recoverAndValidate(digest, signatures);
        if (
            nextAuthorizationNonce == type(uint64).max || transitions == type(uint64).max
                || eventsEmitted == type(uint64).max
        ) revert ArithmeticOverflow();

        RegisteredRoot memory record = RegisteredRoot({
            authorizationDigest: digest,
            attestersHash: keccak256(abi.encode(attesters)),
            root: authorization.root,
            leafCount: authorization.leafCount,
            sourceBlockNumber: authorization.sourceBlockNumber,
            sourceBlockHash: authorization.sourceBlockHash,
            sourceRuntimeId: authorization.sourceRuntimeId,
            verificationContextHash: authorization.verificationContextHash,
            routeId: routeId,
            lifecycleRevision: authorization.lifecycleRevision,
            registeredAtBlock: uint64(block.number),
            validAfterBlock: authorization.validAfterBlock,
            validUntilBlock: authorization.validUntilBlock,
            authorizationNonce: authorization.authorizationNonce,
            exists: true
        });
        roots[coordinate] = record;
        rootAttesters[coordinate] = attesters;
        recordsAccumulator = keccak256(
            abi.encode(recordsAccumulator, coordinate, record, keccak256(abi.encode(attesters)))
        );
        lastAuthorizationDigest = digest;
        unchecked {
            ++nextAuthorizationNonce;
            ++transitions;
            ++eventsEmitted;
        }
        emit ReceiptRootRegisteredV2(
            routeId,
            coordinate,
            digest,
            authorization.root,
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
        return ReceiptRootEncodingV2.rootAuthorizationDigest(
            authorization, block.chainid, address(this)
        );
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

    function transitionCount() external view returns (uint64) {
        return transitions;
    }

    function eventCount() external view returns (uint64) {
        return eventsEmitted;
    }

    function stateDigest() external view returns (bytes32) {
        return keccak256(
            abi.encode(
                "SSGKR_RECEIPT_ROOT_AUTHORITY_STATE_V2",
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
                recordsAccumulator
            )
        );
    }

    function _validateContext(Authorization calldata authorization) private view {
        if (
            authorization.signerSetEpoch != 2 || authorization.signerSetEpoch != signerSetEpoch
                || authorization.routeId != routeId
                || authorization.lifecycleRegistry != lifecycleRegistry
                || authorization.destinationSettlement != destinationSettlement
        ) revert AuthorizationContextMismatch();
        if (
            authorization.sourceNetworkId != sourceNetworkId
                || authorization.sourceGenesisHash != sourceGenesisHash
                || authorization.sourceRuntimeId != sourceRuntimeId
                || authorization.verificationContextHash != verificationContextHash
                || authorization.domainId != domainId
        ) revert AuthorityContextMismatch();
        if (authorization.leafCount != 1) revert InvalidLeafCount();
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
