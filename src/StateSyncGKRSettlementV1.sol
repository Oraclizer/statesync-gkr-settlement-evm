// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

import {IReceiptRootAuthorityV1} from "./interfaces/IReceiptRootAuthorityV1.sol";
import {ReceiptRootEncodingV1} from "./libraries/ReceiptRootEncodingV1.sol";

/// @notice Native N=1 receipt consumer with immutable PFR quorum and atomic replay guards.
contract StateSyncGKRSettlementV1 {
    uint256 public constant MAX_SIGNERS = 16;
    uint256 internal constant SECP256K1_HALF_N =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    error InvalidThreshold();
    error TooManySigners();
    error TooManySignatures();
    error ZeroConfiguredSigner();
    error ConfiguredSignersNotSorted();
    error DuplicateConfiguredSigner();
    error SignerRolesOverlap();
    error UnsupportedChainId();
    error InvalidSignature();
    error HighSignatureS();
    error InvalidRecoveryId();
    error ZeroAttester();
    error AttestersNotSorted();
    error DuplicateAttester();
    error UnauthorizedAttester();
    error BelowThreshold();
    error StaleSignerSetEpoch();
    error InvalidPrimaryFinalityRecord();
    error InvalidMerklePath();
    error ReceiptRootMismatch();
    error AcceptedRootMismatch();
    error ClaimReplay();
    error SettlementReplay();
    error ArithmeticOverflow();

    event SettlementConsumed(
        bytes32 indexed claimId,
        bytes32 indexed settlementKey,
        bytes32 indexed primaryFinalityRecordId,
        bytes32 acceptedRoot
    );

    struct ReceiptAttachment {
        bytes32 sourceNetworkId;
        uint32 domainId;
        uint64 aggregationId;
        uint64 sourceBlockNumber;
        bytes32 sourceBlockHash;
        bytes32 sourceRuntimeId;
        bytes32 verificationContextHash;
        bytes32 statement;
        uint32 leafCount;
        uint32 leafIndex;
        bytes32[] merklePath;
    }

    IReceiptRootAuthorityV1 public immutable rootAuthority;
    uint64 public immutable pfrSignerSetEpoch;
    uint16 public immutable pfrThreshold;
    uint64 public immutable destinationChainId;
    bytes32 public immutable destinationConsumer;
    bytes32 public immutable imageId;
    bytes32 public immutable verifierVersionHash;
    address[] internal pfrSigners;
    mapping(address => bool) internal isPfrSigner;
    mapping(bytes32 => bool) public consumedClaims;
    mapping(bytes32 => bool) public consumedSettlements;
    bytes32 internal consumptionAccumulator;
    uint64 internal transitions;
    uint64 internal eventsEmitted;

    constructor(
        IReceiptRootAuthorityV1 rootAuthority_,
        uint64 pfrSignerSetEpoch_,
        address[] memory pfrSigners_,
        uint16 pfrThreshold_,
        bytes32 imageId_,
        bytes32 verifierVersionHash_
    ) {
        uint256 length = pfrSigners_.length;
        if (length > MAX_SIGNERS) revert TooManySigners();
        if (pfrThreshold_ == 0 || pfrThreshold_ > length) revert InvalidThreshold();
        address previous;
        for (uint256 i; i < length; ++i) {
            address signer = pfrSigners_[i];
            if (signer == address(0)) revert ZeroConfiguredSigner();
            if (i != 0) {
                if (signer == previous) revert DuplicateConfiguredSigner();
                if (signer < previous) revert ConfiguredSignersNotSorted();
            }
            if (rootAuthority_.isConfiguredSigner(signer)) revert SignerRolesOverlap();
            pfrSigners.push(signer);
            isPfrSigner[signer] = true;
            previous = signer;
        }
        rootAuthority = rootAuthority_;
        pfrSignerSetEpoch = pfrSignerSetEpoch_;
        pfrThreshold = pfrThreshold_;
        if (block.chainid > type(uint64).max) revert UnsupportedChainId();
        destinationChainId = uint64(block.chainid);
        destinationConsumer = bytes32(uint256(uint160(address(this))));
        imageId = imageId_;
        verifierVersionHash = verifierVersionHash_;
    }

    function consume(
        ReceiptRootEncodingV1.PrimaryFinalityRecord calldata record,
        bytes calldata rawStatement,
        ReceiptAttachment calldata receipt,
        bytes[] calldata pfrSignatures
    ) external returns (bytes32 claim, bytes32 settlement) {
        if (receipt.leafCount != 1 || receipt.leafIndex != 0 || receipt.merklePath.length != 0) {
            revert InvalidMerklePath();
        }
        (bytes32 rawSha, bytes32 rawAcceptedRoot, uint8 rawAction) =
            ReceiptRootEncodingV1.canonicalStatement(rawStatement);
        bytes32 expectedStatement = keccak256(
            abi.encodePacked(
                receipt.verificationContextHash,
                imageId,
                verifierVersionHash,
                keccak256(rawStatement)
            )
        );
        if (receipt.statement != expectedStatement) revert ReceiptRootMismatch();

        bytes32 coordinate = ReceiptRootEncodingV1.coordinateId(
            receipt.sourceNetworkId, receipt.domainId, receipt.aggregationId
        );
        IReceiptRootAuthorityV1.RegisteredRoot memory registered =
            rootAuthority.registeredRoot(coordinate);
        if (
            !registered.exists || registered.root != keccak256(abi.encodePacked(receipt.statement))
                || registered.leafCount != receipt.leafCount
                || registered.sourceBlockNumber != receipt.sourceBlockNumber
                || registered.sourceBlockHash != receipt.sourceBlockHash
                || registered.sourceRuntimeId != receipt.sourceRuntimeId
                || registered.verificationContextHash != receipt.verificationContextHash
        ) revert ReceiptRootMismatch();

        if (record.acceptedRoot != rawAcceptedRoot) revert AcceptedRootMismatch();
        if (
            record.rawStatementSha256 != rawSha
                || record.preclaimHash
                    != ReceiptRootEncodingV1.preclaimHash(record.routeId, rawStatement)
                || record.source != receipt.sourceNetworkId
                || record.destinationChainId != destinationChainId
                || record.destinationConsumer != destinationConsumer
                || record.actionKind != rawAction || record.checkpoint != receipt.sourceBlockNumber
                || record.sessionId != receipt.sourceBlockHash
                || record.bvcId != receipt.verificationContextHash || record.state != 1
                || record.signerSetEpoch != pfrSignerSetEpoch
        ) revert InvalidPrimaryFinalityRecord();

        bytes32 pfrId = ReceiptRootEncodingV1.pfrRecordId(record);
        _validatePfrSignatures(pfrId, pfrSignatures);
        claim = ReceiptRootEncodingV1.claimId(record.routeId, pfrId, rawStatement);
        settlement = ReceiptRootEncodingV1.settlementKey(
            record.primaryTransitionId,
            record.destinationChainId,
            record.destinationConsumer,
            record.actionKind
        );
        if (consumedClaims[claim]) revert ClaimReplay();
        if (consumedSettlements[settlement]) revert SettlementReplay();
        if (transitions == type(uint64).max || eventsEmitted == type(uint64).max) {
            revert ArithmeticOverflow();
        }

        uint64 newTransitions = transitions + 1;
        uint64 newEvents = eventsEmitted + 1;
        bytes32 newAccumulator = keccak256(
            abi.encode(consumptionAccumulator, claim, settlement, pfrId, rawAcceptedRoot)
        );
        consumedClaims[claim] = true;
        consumedSettlements[settlement] = true;
        consumptionAccumulator = newAccumulator;
        transitions = newTransitions;
        eventsEmitted = newEvents;
        emit SettlementConsumed(claim, settlement, pfrId, rawAcceptedRoot);
    }

    function _validatePfrSignatures(bytes32 digest, bytes[] calldata signatures) internal view {
        if (signatures.length > pfrSigners.length || signatures.length > MAX_SIGNERS) {
            revert TooManySignatures();
        }
        address previous;
        for (uint256 i; i < signatures.length; ++i) {
            address signer = _recover(digest, signatures[i]);
            if (i != 0) {
                if (signer == previous) revert DuplicateAttester();
                if (signer < previous) revert AttestersNotSorted();
            }
            if (!isPfrSigner[signer]) revert UnauthorizedAttester();
            previous = signer;
        }
        if (signatures.length < pfrThreshold) revert BelowThreshold();
    }

    function _recover(bytes32 digest, bytes calldata sig)
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

    function pfrSignerCount() external view returns (uint256) {
        return pfrSigners.length;
    }

    function pfrSignerAt(uint256 index) external view returns (address) {
        return pfrSigners[index];
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
                "SSGKR_DESTINATION_EVM_STATE_V1",
                address(rootAuthority),
                pfrSignerSetEpoch,
                pfrThreshold,
                pfrSigners,
                destinationChainId,
                destinationConsumer,
                imageId,
                verifierVersionHash,
                transitions,
                eventsEmitted,
                consumptionAccumulator
            )
        );
    }
}
