// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

import {IRouteLifecycleRegistryV2} from "./interfaces/IRouteLifecycleRegistryV2.sol";
import {IReceiptRootAuthorityV2} from "./interfaces/IReceiptRootAuthorityV2.sol";
import {IPrimaryFinalityAuthorityV2} from "./interfaces/IPrimaryFinalityAuthorityV2.sol";
import {ReceiptRootEncodingV2} from "./libraries/ReceiptRootEncodingV2.sol";
import {ReceiptRootEncodingV1} from "./libraries/ReceiptRootEncodingV1.sol";

/// @notice Stable lineage settlement with route-independent economic nullifiers.
/// @dev There is deliberately no nullifier migration, settlement replacement, or recovery API.
contract StateSyncGKRSettlementV2 {
    error UnsupportedChainId();
    error LineageSettlementMismatch();
    error LineageAbandoned();
    error RouteNotConsumable();
    error RouteEndpointMismatch();
    error RootLifecycleMismatch();
    error RootExpired();
    error InvalidPrimaryFinalityAuthorization();
    error InvalidPrimaryFinalityRecord();
    error InvalidMerklePath();
    error ReceiptRootMismatch();
    error AcceptedRootMismatch();
    error ClaimReplay();
    error SettlementReplay();
    error ArithmeticOverflow();

    event SettlementConsumedV2(
        bytes32 indexed routeId,
        bytes32 indexed claimId,
        bytes32 indexed settlementKey,
        bytes32 primaryFinalityRecordId,
        bytes32 primaryFinalityAuthorizationDigest,
        bytes32 acceptedRoot,
        uint64 lifecycleRevision
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

    IRouteLifecycleRegistryV2 public immutable lifecycleRegistry;
    uint64 public immutable destinationChainId;
    bytes32 public immutable destinationConsumer;
    bytes32 public immutable imageId;
    bytes32 public immutable verifierVersionHash;

    mapping(bytes32 => bool) public consumedClaims;
    mapping(bytes32 => bool) public consumedSettlements;
    bytes32 internal consumptionAccumulator;
    uint64 internal transitions;
    uint64 internal eventsEmitted;

    constructor(
        IRouteLifecycleRegistryV2 lifecycleRegistry_,
        bytes32 imageId_,
        bytes32 verifierVersionHash_
    ) {
        if (block.chainid > type(uint64).max) revert UnsupportedChainId();
        lifecycleRegistry = lifecycleRegistry_;
        destinationChainId = uint64(block.chainid);
        destinationConsumer = bytes32(uint256(uint160(address(this))));
        imageId = imageId_;
        verifierVersionHash = verifierVersionHash_;
    }

    function consume(
        bytes32 routeId,
        ReceiptRootEncodingV1.PrimaryFinalityRecord calldata record,
        bytes calldata rawStatement,
        ReceiptAttachment calldata receipt,
        IPrimaryFinalityAuthorityV2.Authorization calldata pfrAuthorization,
        bytes[] calldata pfrSignatures
    ) external returns (bytes32 claim, bytes32 settlement) {
        if (lifecycleRegistry.lineageSettlement() != address(this)) {
            revert LineageSettlementMismatch();
        }
        if (lifecycleRegistry.lineageAbandoned()) revert LineageAbandoned();
        IRouteLifecycleRegistryV2.Route memory route = lifecycleRegistry.getRoute(routeId);
        if (
            route.rootAuthority == address(0) || route.pfrAuthority == address(0)
                || IReceiptRootAuthorityV2(route.rootAuthority).routeId() != routeId
                || IPrimaryFinalityAuthorityV2(route.pfrAuthority).routeId() != routeId
        ) revert RouteEndpointMismatch();

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

        bytes32 coordinate = ReceiptRootEncodingV2.coordinateId(
            routeId, receipt.sourceNetworkId, receipt.domainId, receipt.aggregationId
        );
        IReceiptRootAuthorityV2.RegisteredRoot memory registered =
            IReceiptRootAuthorityV2(route.rootAuthority).registeredRoot(coordinate);
        if (
            !registered.exists || registered.routeId != routeId
                || registered.root != keccak256(abi.encodePacked(receipt.statement))
                || registered.leafCount != receipt.leafCount
                || registered.sourceBlockNumber != receipt.sourceBlockNumber
                || registered.sourceBlockHash != receipt.sourceBlockHash
                || registered.sourceRuntimeId != receipt.sourceRuntimeId
                || registered.verificationContextHash != receipt.verificationContextHash
        ) revert ReceiptRootMismatch();
        _validateLifecycle(route, registered);

        if (record.acceptedRoot != rawAcceptedRoot) revert AcceptedRootMismatch();
        if (
            record.rawStatementSha256 != rawSha
                || record.preclaimHash != ReceiptRootEncodingV1.preclaimHash(routeId, rawStatement)
                || record.routeId != routeId || record.source != receipt.sourceNetworkId
                || record.destinationChainId != destinationChainId
                || record.destinationConsumer != destinationConsumer
                || record.actionKind != rawAction || record.checkpoint != receipt.sourceBlockNumber
                || record.sessionId != receipt.sourceBlockHash
                || record.bvcId != receipt.verificationContextHash || record.state != 1
                || record.signerSetEpoch != 2
        ) revert InvalidPrimaryFinalityRecord();

        bytes32 pfrId = ReceiptRootEncodingV1.pfrRecordId(record);
        if (
            pfrAuthorization.primaryFinalityRecordId != pfrId || pfrAuthorization.routeId != routeId
                || pfrAuthorization.lifecycleRegistry != address(lifecycleRegistry)
                || pfrAuthorization.destinationSettlement != address(this)
                || pfrAuthorization.signerSetEpoch != 2
                || pfrAuthorization.lifecycleRevision != registered.lifecycleRevision
        ) revert InvalidPrimaryFinalityAuthorization();

        claim = ReceiptRootEncodingV1.claimId(routeId, pfrId, rawStatement);
        settlement = ReceiptRootEncodingV1.settlementKey(
            record.primaryTransitionId,
            record.destinationChainId,
            record.destinationConsumer,
            record.actionKind
        );
        if (consumedClaims[claim]) revert ClaimReplay();
        if (consumedSettlements[settlement]) revert SettlementReplay();
        bytes32 pfrAuthorizationDigest = IPrimaryFinalityAuthorityV2(route.pfrAuthority)
            .consumeAuthorization(pfrAuthorization, pfrSignatures);
        if (transitions == type(uint64).max || eventsEmitted == type(uint64).max) {
            revert ArithmeticOverflow();
        }

        consumedClaims[claim] = true;
        consumedSettlements[settlement] = true;
        consumptionAccumulator = keccak256(
            abi.encode(
                consumptionAccumulator,
                routeId,
                claim,
                settlement,
                pfrId,
                pfrAuthorizationDigest,
                rawAcceptedRoot,
                registered.lifecycleRevision
            )
        );
        unchecked {
            ++transitions;
            ++eventsEmitted;
        }
        emit SettlementConsumedV2(
            routeId,
            claim,
            settlement,
            pfrId,
            pfrAuthorizationDigest,
            rawAcceptedRoot,
            registered.lifecycleRevision
        );
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
                "SSGKR_SETTLEMENT_STATE_V2",
                address(lifecycleRegistry),
                lifecycleRegistry.lineageId(),
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

    function _validateLifecycle(
        IRouteLifecycleRegistryV2.Route memory route,
        IReceiptRootAuthorityV2.RegisteredRoot memory registered
    ) private view {
        if (block.number >= registered.validUntilBlock) revert RootExpired();
        if (route.status == IRouteLifecycleRegistryV2.RouteStatus.Active) {
            if (registered.lifecycleRevision != route.revision) revert RootLifecycleMismatch();
            return;
        }
        if (route.status == IRouteLifecycleRegistryV2.RouteStatus.Draining) {
            if (
                registered.lifecycleRevision != route.drainingFromRevision
                    || registered.registeredAtBlock > route.drainStartedAtBlock
                    || block.number >= route.consumeUntilBlock
            ) revert RouteNotConsumable();
            return;
        }
        revert RouteNotConsumable();
    }
}
