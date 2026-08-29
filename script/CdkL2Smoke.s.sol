// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

import {IPrimaryFinalityAuthorityV2} from "../src/interfaces/IPrimaryFinalityAuthorityV2.sol";
import {IReceiptRootAuthorityV2} from "../src/interfaces/IReceiptRootAuthorityV2.sol";
import {PrimaryFinalityAuthorityV2} from "../src/PrimaryFinalityAuthorityV2.sol";
import {ReceiptRootAuthorityV2} from "../src/ReceiptRootAuthorityV2.sol";
import {ReceiptRootEncodingV1} from "../src/libraries/ReceiptRootEncodingV1.sol";
import {RouteLifecycleRegistryV2} from "../src/RouteLifecycleRegistryV2.sol";
import {StateSyncGKRSettlementV2} from "../src/StateSyncGKRSettlementV2.sol";

interface SmokeVm {
    function addr(uint256 privateKey) external returns (address);
    function envUint(string calldata name) external returns (uint256);
    function sign(uint256 privateKey, bytes32 digest)
        external
        returns (uint8 v, bytes32 r, bytes32 s);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

contract NegativeProbe {
    error ExpectedRevert();
    error UnexpectedSelector();
    error StateChanged();
    error ProductReferenceMismatch();

    event NegativeProbeResult(
        bytes32 indexed probeId,
        bytes4 indexed observedSelector,
        bytes32 settlementBefore,
        bytes32 settlementAfter,
        bytes32 pfrBefore,
        bytes32 pfrAfter
    );

    event ProductReferenceMatched(
        bytes32 indexed rawStatementSha256,
        bytes32 indexed acceptedRoot,
        bytes32 claimId,
        bytes32 settlementKey,
        uint64 transitionCount
    );

    event SmokeExecutionComplete(
        address indexed registry,
        address indexed settlement,
        address indexed rootAuthority,
        address pfrAuthority
    );

    function executeSmoke(
        RouteLifecycleRegistryV2 registry,
        StateSyncGKRSettlementV2 settlement,
        ReceiptRootAuthorityV2 root,
        PrimaryFinalityAuthorityV2 pfr,
        bytes32 routeId,
        IReceiptRootAuthorityV2.Authorization calldata rootAuthorization,
        bytes[] calldata rootSignatures,
        ReceiptRootEncodingV1.PrimaryFinalityRecord calldata record,
        bytes calldata rawStatement,
        StateSyncGKRSettlementV2.ReceiptAttachment calldata receipt,
        IPrimaryFinalityAuthorityV2.Authorization calldata pfrAuthorization,
        bytes[] calldata pfrSignatures,
        IPrimaryFinalityAuthorityV2.Authorization calldata wrongPredecessor,
        bytes[] calldata wrongPredecessorSignatures,
        bytes32 expectedRawSha256,
        bytes32 expectedAcceptedRoot
    ) external {
        registry.initializeLineageSettlement(address(settlement));
        registry.activateRoute(routeId, address(root), address(pfr), 0);
        root.register(rootAuthorization, rootSignatures);

        StateSyncGKRSettlementV2.ReceiptAttachment memory wrongReceipt =
            StateSyncGKRSettlementV2.ReceiptAttachment({
                sourceNetworkId: receipt.sourceNetworkId,
                domainId: receipt.domainId,
                aggregationId: receipt.aggregationId,
                sourceBlockNumber: receipt.sourceBlockNumber,
                sourceBlockHash: receipt.sourceBlockHash,
                sourceRuntimeId: receipt.sourceRuntimeId,
                verificationContextHash: receipt.verificationContextHash,
                statement: bytes32(uint256(receipt.statement) ^ 1),
                leafCount: receipt.leafCount,
                leafIndex: receipt.leafIndex,
                merklePath: receipt.merklePath
            });
        _expectSettlementRevert(
            keccak256("wrong-receipt"),
            settlement,
            pfr,
            abi.encodeCall(
                settlement.consume,
                (routeId, record, rawStatement, wrongReceipt, pfrAuthorization, pfrSignatures)
            ),
            StateSyncGKRSettlementV2.ReceiptRootMismatch.selector
        );
        _expectSettlementRevert(
            keccak256("wrong-predecessor"),
            settlement,
            pfr,
            abi.encodeCall(
                settlement.consume,
                (
                    routeId,
                    record,
                    rawStatement,
                    receipt,
                    wrongPredecessor,
                    wrongPredecessorSignatures
                )
            ),
            PrimaryFinalityAuthorityV2.PreviousAuthorizationDigestMismatch.selector
        );

        (bytes32 claimId, bytes32 settlementKey) = settlement.consume(
            routeId, record, rawStatement, receipt, pfrAuthorization, pfrSignatures
        );
        _expectSettlementRevert(
            keccak256("replay"),
            settlement,
            pfr,
            abi.encodeCall(
                settlement.consume,
                (routeId, record, rawStatement, receipt, pfrAuthorization, pfrSignatures)
            ),
            StateSyncGKRSettlementV2.ClaimReplay.selector
        );
        _confirmProductReference(
            settlement,
            rawStatement,
            expectedRawSha256,
            expectedAcceptedRoot,
            claimId,
            settlementKey
        );
        emit SmokeExecutionComplete(
            address(registry), address(settlement), address(root), address(pfr)
        );
    }

    function expectSettlementRevert(
        bytes32 probeId,
        StateSyncGKRSettlementV2 settlement,
        PrimaryFinalityAuthorityV2 pfr,
        bytes calldata callData,
        bytes4 expectedSelector
    ) external {
        _expectSettlementRevert(probeId, settlement, pfr, callData, expectedSelector);
    }

    function _expectSettlementRevert(
        bytes32 probeId,
        StateSyncGKRSettlementV2 settlement,
        PrimaryFinalityAuthorityV2 pfr,
        bytes memory callData,
        bytes4 expectedSelector
    ) private {
        bytes32 settlementBefore = settlement.stateDigest();
        bytes32 pfrBefore = pfr.stateDigest();
        (bool ok, bytes memory reason) = address(settlement).call(callData);
        if (ok) revert ExpectedRevert();
        bytes4 observedSelector = _selector(reason);
        if (observedSelector != expectedSelector) revert UnexpectedSelector();
        bytes32 settlementAfter = settlement.stateDigest();
        bytes32 pfrAfter = pfr.stateDigest();
        if (settlementBefore != settlementAfter || pfrBefore != pfrAfter) {
            revert StateChanged();
        }
        emit NegativeProbeResult(
            probeId, observedSelector, settlementBefore, settlementAfter, pfrBefore, pfrAfter
        );
    }

    function confirmProductReference(
        StateSyncGKRSettlementV2 settlement,
        bytes calldata rawStatement,
        bytes32 expectedRawSha256,
        bytes32 expectedAcceptedRoot,
        bytes32 claimId,
        bytes32 settlementKey
    ) external {
        _confirmProductReference(
            settlement,
            rawStatement,
            expectedRawSha256,
            expectedAcceptedRoot,
            claimId,
            settlementKey
        );
    }

    function _confirmProductReference(
        StateSyncGKRSettlementV2 settlement,
        bytes memory rawStatement,
        bytes32 expectedRawSha256,
        bytes32 expectedAcceptedRoot,
        bytes32 claimId,
        bytes32 settlementKey
    ) private {
        if (
            sha256(rawStatement) != expectedRawSha256 || !settlement.consumedClaims(claimId)
                || !settlement.consumedSettlements(settlementKey)
                || settlement.transitionCount() != 1 || settlement.eventCount() != 1
        ) revert ProductReferenceMismatch();
        emit ProductReferenceMatched(
            expectedRawSha256,
            expectedAcceptedRoot,
            claimId,
            settlementKey,
            settlement.transitionCount()
        );
    }

    function _selector(bytes memory reason) private pure returns (bytes4 selector) {
        if (reason.length < 4) return bytes4(0);
        assembly ("memory-safe") {
            selector := mload(add(reason, 32))
        }
    }
}

contract CdkL2SmokeScript {
    SmokeVm private constant VM = SmokeVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    // The historical domain tag below is frozen: recorded drill receipts bind
    // this exact string, so renaming it would break the recorded lineage hash.
    bytes32 private constant LINEAGE = keccak256("ssgkr/w6c/local-cdk-l2/lineage/v1");
    bytes32 private constant ROUTE =
        0x27b40b99a41976f061e94124b84cc8c43ee4e5ed6bad2e94267057e1d375f2ef;
    bytes32 private constant NETWORK =
        0x63f64f53339e0cfb288c57b0091f4932fa3181361fa87ba1dc583fbc172d836e;
    bytes32 private constant GENESIS =
        0xff7fe5a610f15fe7a0c52f94f86313fb7db7d3786e7f8acf2b66c11d5be7c242;
    bytes32 private constant RUNTIME =
        0x7f98ae91ea34aff20365f8f157636ea7b2eccd216212dca424ca4bce2b2b9a8b;
    bytes32 private constant CONTEXT =
        0x676acbc40b7c7b5ba646aee26dd77984104e0674391ebd9f8e70b60d84ca6660;
    bytes32 private constant SOURCE_BLOCK_HASH =
        0xb995cd3981fb8013be45d89009aa360a338935e4ec9feb8e653e7d724af9206c;
    bytes32 private constant IMAGE =
        0x7df0d4a4cfb1268e4d7fb68bd55ab5215db22ca96aa9b3ced6f72954ce2cb8df;
    bytes32 private constant VERSION =
        0x43d8ea2c452a82a94f93ed1c79d6126900cbe0763bde896dfd07e8a676f83627;
    bytes32 private constant ACCEPTED_ROOT =
        0x88957f2aa94f0f483d11f6bbc00b37db9fedd7911eee56e15c1661e148453200;
    bytes32 private constant PRODUCT_RAW_SHA256 =
        0x959550f3847e15ae2d69ab027d8ef59621282eeb758746262205fa3f61b38721;

    uint64 private constant SOURCE_BLOCK_NUMBER = 6_726_351;
    uint64 private constant AGGREGATION_ID = 53_668;

    function run() external {
        uint256 deployerKey = VM.envUint("CDK_SMOKE_DEPLOYER_PRIVATE_KEY");
        VM.startBroadcast(deployerKey);

        NegativeProbe probe = new NegativeProbe();
        RouteLifecycleRegistryV2 registry =
            new RouteLifecycleRegistryV2(LINEAGE, address(probe), VM.addr(6), 10);
        StateSyncGKRSettlementV2 settlement = new StateSyncGKRSettlementV2(registry, IMAGE, VERSION);

        ReceiptRootAuthorityV2 root = new ReceiptRootAuthorityV2(
            ROUTE,
            registry,
            address(settlement),
            2,
            _twoSigners(2, 3),
            2,
            20,
            NETWORK,
            GENESIS,
            RUNTIME,
            CONTEXT,
            2
        );
        PrimaryFinalityAuthorityV2 pfr = new PrimaryFinalityAuthorityV2(
            ROUTE, address(registry), address(settlement), 2, _twoSigners(4, 5), 2, 20
        );

        IReceiptRootAuthorityV2.Authorization memory rootAuthorization = _rootAuthorization(root);
        bytes[] memory rootSignatures = _signTwo(2, 3, root.authorizationDigest(rootAuthorization));

        (
            ReceiptRootEncodingV1.PrimaryFinalityRecord memory record,
            IPrimaryFinalityAuthorityV2.Authorization memory pfrAuthorization
        ) = _recordAndAuthorization(settlement, pfr);
        bytes[] memory pfrSignatures = _signTwo(4, 5, pfr.authorizationDigest(pfrAuthorization));

        IPrimaryFinalityAuthorityV2.Authorization memory wrongPredecessor =
            IPrimaryFinalityAuthorityV2.Authorization({
                primaryFinalityRecordId: pfrAuthorization.primaryFinalityRecordId,
                routeId: pfrAuthorization.routeId,
                lifecycleRegistry: pfrAuthorization.lifecycleRegistry,
                destinationSettlement: pfrAuthorization.destinationSettlement,
                signerSetEpoch: pfrAuthorization.signerSetEpoch,
                lifecycleRevision: pfrAuthorization.lifecycleRevision,
                validAfterBlock: pfrAuthorization.validAfterBlock,
                validUntilBlock: pfrAuthorization.validUntilBlock,
                authorizationNonce: pfrAuthorization.authorizationNonce,
                previousAuthorizationDigest: bytes32(uint256(1))
            });
        bytes[] memory wrongPredecessorSignatures =
            _signTwo(4, 5, pfr.authorizationDigest(wrongPredecessor));
        probe.executeSmoke(
            registry,
            settlement,
            root,
            pfr,
            ROUTE,
            rootAuthorization,
            rootSignatures,
            record,
            _raw(),
            _receipt(),
            pfrAuthorization,
            pfrSignatures,
            wrongPredecessor,
            wrongPredecessorSignatures,
            PRODUCT_RAW_SHA256,
            ACCEPTED_ROOT
        );

        VM.stopBroadcast();
    }

    function _rootAuthorization(ReceiptRootAuthorityV2 root)
        private
        view
        returns (IReceiptRootAuthorityV2.Authorization memory)
    {
        return IReceiptRootAuthorityV2.Authorization({
            signerSetEpoch: 2,
            sourceNetworkId: NETWORK,
            sourceGenesisHash: GENESIS,
            sourceRuntimeId: RUNTIME,
            verificationContextHash: CONTEXT,
            domainId: 2,
            sourceBlockNumber: SOURCE_BLOCK_NUMBER,
            sourceBlockHash: SOURCE_BLOCK_HASH,
            aggregationId: AGGREGATION_ID,
            root: keccak256(abi.encodePacked(_statement())),
            leafCount: 1,
            routeId: ROUTE,
            lifecycleRegistry: root.lifecycleRegistry(),
            destinationSettlement: root.destinationSettlement(),
            lifecycleRevision: 1,
            validAfterBlock: uint64(block.number),
            validUntilBlock: uint64(block.number + 20),
            authorizationNonce: root.nextAuthorizationNonce(),
            previousAuthorizationDigest: root.lastAuthorizationDigest()
        });
    }

    function _recordAndAuthorization(
        StateSyncGKRSettlementV2 settlement,
        PrimaryFinalityAuthorityV2 pfr
    )
        private
        view
        returns (
            ReceiptRootEncodingV1.PrimaryFinalityRecord memory record,
            IPrimaryFinalityAuthorityV2.Authorization memory authorization
        )
    {
        record = ReceiptRootEncodingV1.PrimaryFinalityRecord({
            primaryTransitionId: sha256(_raw()),
            routeId: ROUTE,
            rawStatementSha256: sha256(_raw()),
            preclaimHash: ReceiptRootEncodingV1.preclaimHash(ROUTE, _raw()),
            source: NETWORK,
            destinationChainId: settlement.destinationChainId(),
            destinationConsumer: settlement.destinationConsumer(),
            actionKind: 0,
            checkpoint: SOURCE_BLOCK_NUMBER,
            sessionId: SOURCE_BLOCK_HASH,
            bvcId: CONTEXT,
            acceptedRoot: ACCEPTED_ROOT,
            state: 1,
            signerSetEpoch: 2,
            issuanceHeight: SOURCE_BLOCK_NUMBER,
            hasSupersedes: false,
            supersedesRecordId: bytes32(0)
        });
        authorization = IPrimaryFinalityAuthorityV2.Authorization({
            primaryFinalityRecordId: ReceiptRootEncodingV1.pfrRecordId(record),
            routeId: ROUTE,
            lifecycleRegistry: pfr.lifecycleRegistry(),
            destinationSettlement: pfr.destinationSettlement(),
            signerSetEpoch: 2,
            lifecycleRevision: 1,
            validAfterBlock: uint64(block.number),
            validUntilBlock: uint64(block.number + 20),
            authorizationNonce: pfr.nextAuthorizationNonce(),
            previousAuthorizationDigest: pfr.lastAuthorizationDigest()
        });
    }

    function _receipt() private pure returns (StateSyncGKRSettlementV2.ReceiptAttachment memory) {
        return StateSyncGKRSettlementV2.ReceiptAttachment({
            sourceNetworkId: NETWORK,
            domainId: 2,
            aggregationId: AGGREGATION_ID,
            sourceBlockNumber: SOURCE_BLOCK_NUMBER,
            sourceBlockHash: SOURCE_BLOCK_HASH,
            sourceRuntimeId: RUNTIME,
            verificationContextHash: CONTEXT,
            statement: _statement(),
            leafCount: 1,
            leafIndex: 0,
            merklePath: new bytes32[](0)
        });
    }

    function _statement() private pure returns (bytes32) {
        return keccak256(abi.encodePacked(CONTEXT, IMAGE, VERSION, keccak256(_raw())));
    }

    function _twoSigners(uint256 key1, uint256 key2) private returns (address[] memory signers) {
        signers = new address[](2);
        address first = VM.addr(key1);
        address second = VM.addr(key2);
        if (first < second) {
            signers[0] = first;
            signers[1] = second;
        } else {
            signers[0] = second;
            signers[1] = first;
        }
    }

    function _signTwo(uint256 key1, uint256 key2, bytes32 digest)
        private
        returns (bytes[] memory signatures)
    {
        signatures = new bytes[](2);
        if (VM.addr(key1) < VM.addr(key2)) {
            signatures[0] = _signature(key1, digest);
            signatures[1] = _signature(key2, digest);
        } else {
            signatures[0] = _signature(key2, digest);
            signatures[1] = _signature(key1, digest);
        }
    }

    function _signature(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = VM.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _raw() private pure returns (bytes memory) {
        return hex"01000100010001001f0000001800000000000000000000000000000000000000abde249a257cd4e6c3ed34f2749a7d8be66fd418f5a5d8595bffc956b45f0e0088957f2aa94f0f483d11f6bbc00b37db9fedd7911eee56e15c1661e14845320088957f2aa94f0f483d11f6bbc00b37db9fedd7911eee56e15c1661e14845320005000000000000000000000000000000000000000000000000000000000000004cc6356134cfb0dcefee384334580a10c3f82929f64a9f8833dd47ebc2cdbf00";
    }
}
