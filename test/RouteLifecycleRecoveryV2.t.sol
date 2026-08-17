// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

import {TestBase, Vm} from "./utils/TestBase.sol";
import {IRouteLifecycleRegistryV2} from "../src/interfaces/IRouteLifecycleRegistryV2.sol";
import {IReceiptRootAuthorityV2} from "../src/interfaces/IReceiptRootAuthorityV2.sol";
import {IPrimaryFinalityAuthorityV2} from "../src/interfaces/IPrimaryFinalityAuthorityV2.sol";
import {ReceiptRootEncodingV1} from "../src/libraries/ReceiptRootEncodingV1.sol";
import {ReceiptRootEncodingV2} from "../src/libraries/ReceiptRootEncodingV2.sol";
import {RouteLifecycleRegistryV2} from "../src/RouteLifecycleRegistryV2.sol";
import {ReceiptRootAuthorityV2} from "../src/ReceiptRootAuthorityV2.sol";
import {PrimaryFinalityAuthorityV2} from "../src/PrimaryFinalityAuthorityV2.sol";
import {StateSyncGKRSettlementV2} from "../src/StateSyncGKRSettlementV2.sol";

contract IncidentActorV2 {
    function execute(address target, bytes calldata data) external returns (bytes memory result) {
        (bool ok, bytes memory returned) = target.call(data);
        if (!ok) {
            assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        }
        return returned;
    }
}

contract RouteLifecycleRecoveryV2Test is TestBase {
    bytes32 internal constant LINEAGE = keccak256("lineage/a");
    bytes32 internal constant ROUTE_A = keccak256("route/a/epoch2");
    bytes32 internal constant ROUTE_B = keccak256("route/b/epoch2");
    bytes32 internal constant NETWORK =
        0x63f64f53339e0cfb288c57b0091f4932fa3181361fa87ba1dc583fbc172d836e;
    bytes32 internal constant GENESIS =
        0xff7fe5a610f15fe7a0c52f94f86313fb7db7d3786e7f8acf2b66c11d5be7c242;
    bytes32 internal constant RUNTIME =
        0x7f98ae91ea34aff20365f8f157636ea7b2eccd216212dca424ca4bce2b2b9a8b;
    bytes32 internal constant CONTEXT =
        0x676acbc40b7c7b5ba646aee26dd77984104e0674391ebd9f8e70b60d84ca6660;
    bytes32 internal constant BLOCK_HASH =
        0xb995cd3981fb8013be45d89009aa360a338935e4ec9feb8e653e7d724af9206c;
    bytes32 internal constant IMAGE =
        0x7df0d4a4cfb1268e4d7fb68bd55ab5215db22ca96aa9b3ced6f72954ce2cb8df;
    bytes32 internal constant VERSION =
        0x43d8ea2c452a82a94f93ed1c79d6126900cbe0763bde896dfd07e8a676f83627;
    bytes32 internal constant ACCEPTED =
        0x88957f2aa94f0f483d11f6bbc00b37db9fedd7911eee56e15c1661e148453200;

    RouteLifecycleRegistryV2 internal registry;
    StateSyncGKRSettlementV2 internal settlement;
    ReceiptRootAuthorityV2 internal rootA;
    PrimaryFinalityAuthorityV2 internal pfrA;
    IncidentActorV2 internal incident;

    function setUp() public {
        vm.chainId(84_532);
        vm.roll(100);
        incident = new IncidentActorV2();
        registry = new RouteLifecycleRegistryV2(LINEAGE, address(this), address(incident), 10);
        settlement = new StateSyncGKRSettlementV2(registry, IMAGE, VERSION);
        registry.initializeLineageSettlement(address(settlement));
        (rootA, pfrA) = _deployAuthorities(ROUTE_A, 2, 3, 4, 5);
        registry.activateRoute(ROUTE_A, address(rootA), address(pfrA), 0);
    }

    function testActiveRouteConsumesAndPreservesV1Identities() public {
        _registerRoot(rootA, ROUTE_A, 2, 3, 53_668, 1);
        (
            ReceiptRootEncodingV1.PrimaryFinalityRecord memory record,
            IPrimaryFinalityAuthorityV2.Authorization memory pfrAuthorization
        ) = _recordAndAuthorization(pfrA, ROUTE_A, 1);
        bytes32 pfrId = ReceiptRootEncodingV1.pfrRecordId(record);
        bytes32 expectedClaim = ReceiptRootEncodingV1.claimId(ROUTE_A, pfrId, _raw());
        bytes32 expectedSettlement = ReceiptRootEncodingV1.settlementKey(
            record.primaryTransitionId,
            record.destinationChainId,
            record.destinationConsumer,
            record.actionKind
        );
        (bytes32 claim, bytes32 economic) = settlement.consume(
            ROUTE_A,
            record,
            _raw(),
            _receipt(53_668),
            pfrAuthorization,
            _signPfr(pfrA, pfrAuthorization, 4, 5)
        );
        assertEq(claim, expectedClaim);
        assertEq(economic, expectedSettlement);
        assertTrue(settlement.consumedClaims(claim));
        assertTrue(settlement.consumedSettlements(economic));
        assertEq(settlement.transitionCount(), 1);
        assertEq(pfrA.nextAuthorizationNonce(), 2);
    }

    function testEip712RejectsWrongChainAndClonedVerifyingContracts() public {
        IReceiptRootAuthorityV2.Authorization memory authorization =
            _rootAuthorization(rootA, ROUTE_A, 53_668, 1);
        bytes32 correctDigest = rootA.authorizationDigest(authorization);
        bytes[] memory correctSignatures = _signRoot(rootA, authorization, 2, 3);
        vm.chainId(1);
        _assertRootFailure(
            rootA,
            abi.encodeCall(rootA.register, (authorization, correctSignatures)),
            ReceiptRootAuthorityV2.UnauthorizedAttester.selector
        );
        vm.chainId(84_532);

        (ReceiptRootAuthorityV2 cloneRoot, PrimaryFinalityAuthorityV2 clonePfr) =
            _deployAuthorities(ROUTE_A, 2, 3, 4, 5);
        assertTrue(cloneRoot.authorizationDigest(authorization) != correctDigest);
        bytes[] memory cloneRootSignatures = _signRoot(cloneRoot, authorization, 2, 3);
        _assertRootFailure(
            rootA,
            abi.encodeCall(rootA.register, (authorization, cloneRootSignatures)),
            ReceiptRootAuthorityV2.UnauthorizedAttester.selector
        );

        IPrimaryFinalityAuthorityV2.Authorization memory pfrAuthorization =
            _pfrAuthorization(pfrA, ROUTE_A, bytes32(uint256(7)), 1);
        assertTrue(
            pfrA.authorizationDigest(pfrAuthorization)
                != clonePfr.authorizationDigest(pfrAuthorization)
        );
        _registerRoot(rootA, ROUTE_A, 2, 3, 53_668, 1);
        (
            ReceiptRootEncodingV1.PrimaryFinalityRecord memory record,
            IPrimaryFinalityAuthorityV2.Authorization memory runtimePfrAuthorization
        ) = _recordAndAuthorization(pfrA, ROUTE_A, 1);
        _assertSettlementFailure(
            settlement,
            pfrA,
            abi.encodeCall(
                settlement.consume,
                (
                    ROUTE_A,
                    record,
                    _raw(),
                    _receipt(53_668),
                    runtimePfrAuthorization,
                    _signPfr(clonePfr, runtimePfrAuthorization, 4, 5)
                )
            ),
            PrimaryFinalityAuthorityV2.UnauthorizedAttester.selector
        );
    }

    function testRootContextNonceHashChainAndValidityAreFailClosed() public {
        IReceiptRootAuthorityV2.Authorization memory authorization =
            _rootAuthorization(rootA, ROUTE_A, 53_668, 1);
        authorization.signerSetEpoch = 1;
        _assertSignedRootFailure(
            authorization, ReceiptRootAuthorityV2.AuthorizationContextMismatch.selector
        );
        authorization = _rootAuthorization(rootA, ROUTE_A, 53_668, 1);
        authorization.destinationSettlement = address(0xBEEF);
        _assertSignedRootFailure(
            authorization, ReceiptRootAuthorityV2.AuthorizationContextMismatch.selector
        );
        authorization = _rootAuthorization(rootA, ROUTE_A, 53_668, 1);
        authorization.authorizationNonce = 2;
        _assertSignedRootFailure(
            authorization, ReceiptRootAuthorityV2.UnexpectedAuthorizationNonce.selector
        );
        authorization = _rootAuthorization(rootA, ROUTE_A, 53_668, 1);
        authorization.previousAuthorizationDigest = bytes32(uint256(1));
        _assertSignedRootFailure(
            authorization, ReceiptRootAuthorityV2.PreviousAuthorizationDigestMismatch.selector
        );
        authorization = _rootAuthorization(rootA, ROUTE_A, 53_668, 1);
        authorization.validAfterBlock = 101;
        _assertSignedRootFailure(
            authorization, ReceiptRootAuthorityV2.InvalidValidityWindow.selector
        );
        authorization = _rootAuthorization(rootA, ROUTE_A, 53_668, 1);
        authorization.validUntilBlock = 100;
        _assertSignedRootFailure(
            authorization, ReceiptRootAuthorityV2.InvalidValidityWindow.selector
        );

        _registerRoot(rootA, ROUTE_A, 2, 3, 53_668, 1);
        IReceiptRootAuthorityV2.Authorization memory future =
            _rootAuthorization(rootA, ROUTE_A, 53_669, 1);
        future.authorizationNonce = 3;
        future.previousAuthorizationDigest = bytes32(0);
        _assertSignedRootFailure(
            future, ReceiptRootAuthorityV2.UnexpectedAuthorizationNonce.selector
        );
        IReceiptRootAuthorityV2.RegisteredRoot memory historical =
            rootA.registeredRoot(ReceiptRootEncodingV2.coordinateId(ROUTE_A, NETWORK, 2, 53_668));
        assertTrue(historical.exists);
        assertEq(historical.authorizationNonce, 1);
        assertEq(rootA.nextAuthorizationNonce(), 2);
    }

    function testLifecycleCasAuthorityAndTransitionGraph() public {
        _assertRegistryFailure(
            abi.encodeCall(registry.startDrain, (ROUTE_A, 0, uint64(105))),
            RouteLifecycleRegistryV2.RevisionMismatch.selector
        );
        _assertRegistryFailure(
            abi.encodeCall(registry.replaceRoute, (ROUTE_A, 1, ROUTE_B)),
            RouteLifecycleRegistryV2.InvalidTransition.selector
        );
        _assertRegistryFailure(
            abi.encodeCall(registry.startDrain, (ROUTE_A, 1, uint64(100))),
            RouteLifecycleRegistryV2.InvalidDrainCutoff.selector
        );
        _assertRegistryFailure(
            abi.encodeCall(registry.startDrain, (ROUTE_A, 1, uint64(111))),
            RouteLifecycleRegistryV2.InvalidDrainCutoff.selector
        );
        registry.startDrain(ROUTE_A, 1, 105);
        IRouteLifecycleRegistryV2.Route memory draining = registry.getRoute(ROUTE_A);
        assertEq(uint256(draining.status), uint256(IRouteLifecycleRegistryV2.RouteStatus.Draining));
        assertEq(draining.revision, 2);
        assertEq(draining.drainingFromRevision, 1);
        assertEq(draining.drainStartedAtBlock, 100);
        assertEq(draining.consumeUntilBlock, 105);

        _assertRegistryFailure(
            abi.encodeCall(registry.startDrain, (ROUTE_A, 2, uint64(105))),
            RouteLifecycleRegistryV2.InvalidTransition.selector
        );
        registry.revokeRoute(ROUTE_A, 2);
        IRouteLifecycleRegistryV2.Route memory revoked = registry.getRoute(ROUTE_A);
        assertEq(uint256(revoked.status), uint256(IRouteLifecycleRegistryV2.RouteStatus.Revoked));
        assertEq(revoked.revision, 3);
        _assertRegistryFailure(
            abi.encodeCall(registry.revokeRoute, (ROUTE_A, 3)),
            RouteLifecycleRegistryV2.InvalidTransition.selector
        );
    }

    function testLifecycleAuthoritiesAreExact() public {
        _assertRegistryFailure(
            abi.encodeCall(registry.abandonLineage, ()),
            RouteLifecycleRegistryV2.IncidentOnly.selector
        );
        _assertActorRegistryFailure(
            incident,
            abi.encodeCall(registry.startDrain, (ROUTE_A, uint64(1), uint64(105))),
            RouteLifecycleRegistryV2.GovernanceOnly.selector
        );
        _assertActorRegistryFailure(
            incident,
            abi.encodeCall(
                registry.activateRoute, (ROUTE_B, address(rootA), address(pfrA), uint64(0))
            ),
            RouteLifecycleRegistryV2.GovernanceOnly.selector
        );
    }

    function testLineageSettlementCannotBeReplacedByClone() public {
        StateSyncGKRSettlementV2 clone = new StateSyncGKRSettlementV2(registry, IMAGE, VERSION);
        assertTrue(address(clone) != address(settlement));
        _assertRegistryFailure(
            abi.encodeCall(registry.initializeLineageSettlement, (address(clone))),
            RouteLifecycleRegistryV2.LineageAlreadyInitialized.selector
        );
        assertEq(registry.lineageSettlement(), address(settlement));
        assertEq(address(clone.lifecycleRegistry()), address(registry));

        IReceiptRootAuthorityV2.Authorization memory cloneBound =
            _rootAuthorization(rootA, ROUTE_A, 53_668, 1);
        cloneBound.destinationSettlement = address(clone);
        _assertSignedRootFailure(
            cloneBound, ReceiptRootAuthorityV2.AuthorizationContextMismatch.selector
        );
    }

    function testDrainAllowsOnlyPredrainRootAndUsesHalfOpenCutoff() public {
        _registerRoot(rootA, ROUTE_A, 2, 3, 53_668, 1);
        vm.roll(101);
        registry.startDrain(ROUTE_A, 1, 105);
        IReceiptRootAuthorityV2.Authorization memory afterDrain =
            _rootAuthorization(rootA, ROUTE_A, 53_669, 2);
        afterDrain.lifecycleRevision = 2;
        _assertSignedRootFailure(afterDrain, ReceiptRootAuthorityV2.RouteNotActive.selector);

        vm.roll(104);
        (
            ReceiptRootEncodingV1.PrimaryFinalityRecord memory record,
            IPrimaryFinalityAuthorityV2.Authorization memory pfrAuthorization
        ) = _recordAndAuthorization(pfrA, ROUTE_A, 1);
        settlement.consume(
            ROUTE_A,
            record,
            _raw(),
            _receipt(53_668),
            pfrAuthorization,
            _signPfr(pfrA, pfrAuthorization, 4, 5)
        );

        (RouteLifecycleRegistryV2 registry2, StateSyncGKRSettlementV2 settlement2) =
            _bareLineage(bytes32(uint256(LINEAGE) ^ 1));
        (ReceiptRootAuthorityV2 root2, PrimaryFinalityAuthorityV2 pfr2) =
            _deployAuthoritiesFor(registry2, settlement2, ROUTE_A, 2, 3, 4, 5);
        registry2.activateRoute(ROUTE_A, address(root2), address(pfr2), 0);
        _registerRootFor(root2, ROUTE_A, 2, 3, 53_668, 1);
        registry2.startDrain(ROUTE_A, 1, 105);
        vm.roll(105);
        (record, pfrAuthorization) = _recordAndAuthorizationFor(settlement2, pfr2, ROUTE_A, 1);
        _assertSettlementFailure(
            settlement2,
            pfr2,
            abi.encodeCall(
                settlement2.consume,
                (
                    ROUTE_A,
                    record,
                    _raw(),
                    _receipt(53_668),
                    pfrAuthorization,
                    _signPfr(pfr2, pfrAuthorization, 4, 5)
                )
            ),
            StateSyncGKRSettlementV2.RouteNotConsumable.selector
        );
    }

    function testReplacementUsesStableSettlementAndRouteIndependentNullifier() public {
        _registerRoot(rootA, ROUTE_A, 2, 3, 53_668, 1);
        (
            ReceiptRootEncodingV1.PrimaryFinalityRecord memory recordA,
            IPrimaryFinalityAuthorityV2.Authorization memory pfrAuthorizationA
        ) = _recordAndAuthorization(pfrA, ROUTE_A, 1);
        settlement.consume(
            ROUTE_A,
            recordA,
            _raw(),
            _receipt(53_668),
            pfrAuthorizationA,
            _signPfr(pfrA, pfrAuthorizationA, 4, 5)
        );

        (ReceiptRootAuthorityV2 rootB, PrimaryFinalityAuthorityV2 pfrB) =
            _deployAuthorities(ROUTE_B, 6, 7, 8, 9);
        registry.activateRoute(ROUTE_B, address(rootB), address(pfrB), 0);
        _registerRoot(rootB, ROUTE_B, 6, 7, 53_668, 1);
        registry.startDrain(ROUTE_A, 1, 105);
        registry.replaceRoute(ROUTE_A, 2, ROUTE_B);
        IRouteLifecycleRegistryV2.Route memory replaced = registry.getRoute(ROUTE_A);
        assertEq(uint256(replaced.status), uint256(IRouteLifecycleRegistryV2.RouteStatus.Replaced));
        assertEq(replaced.replacementRouteId, ROUTE_B);
        assertEq(replaced.rootAuthority, address(rootA));
        assertEq(replaced.pfrAuthority, address(pfrA));
        _assertRegistryFailure(
            abi.encodeCall(registry.startDrain, (ROUTE_A, uint64(3), uint64(105))),
            RouteLifecycleRegistryV2.InvalidTransition.selector
        );
        _assertRegistryFailure(
            abi.encodeCall(registry.revokeRoute, (ROUTE_A, uint64(3))),
            RouteLifecycleRegistryV2.InvalidTransition.selector
        );
        _assertRegistryFailure(
            abi.encodeCall(registry.replaceRoute, (ROUTE_A, uint64(3), ROUTE_B)),
            RouteLifecycleRegistryV2.InvalidTransition.selector
        );
        _assertRegistryFailure(
            abi.encodeCall(
                registry.activateRoute, (ROUTE_A, address(rootA), address(pfrA), uint64(3))
            ),
            RouteLifecycleRegistryV2.InvalidTransition.selector
        );
        IRouteLifecycleRegistryV2.Route memory stillReplaced = registry.getRoute(ROUTE_A);
        assertEq(keccak256(abi.encode(stillReplaced)), keccak256(abi.encode(replaced)));

        (recordA, pfrAuthorizationA) = _recordAndAuthorization(pfrA, ROUTE_A, 1);
        _assertSettlementFailure(
            settlement,
            pfrA,
            abi.encodeCall(
                settlement.consume,
                (
                    ROUTE_A,
                    recordA,
                    _raw(),
                    _receipt(53_668),
                    pfrAuthorizationA,
                    _signPfr(pfrA, pfrAuthorizationA, 4, 5)
                )
            ),
            StateSyncGKRSettlementV2.RouteNotConsumable.selector
        );

        (
            ReceiptRootEncodingV1.PrimaryFinalityRecord memory recordB,
            IPrimaryFinalityAuthorityV2.Authorization memory pfrAuthorizationB
        ) = _recordAndAuthorization(pfrB, ROUTE_B, 1);
        bytes32 pfrBefore = pfrB.stateDigest();
        _assertSettlementFailure(
            settlement,
            pfrB,
            abi.encodeCall(
                settlement.consume,
                (
                    ROUTE_B,
                    recordB,
                    _raw(),
                    _receipt(53_668),
                    pfrAuthorizationB,
                    _signPfr(pfrB, pfrAuthorizationB, 8, 9)
                )
            ),
            StateSyncGKRSettlementV2.SettlementReplay.selector
        );
        assertEq(pfrB.stateDigest(), pfrBefore);
        assertEq(pfrB.nextAuthorizationNonce(), 1);
    }

    function testIncidentRevocationAndAbandonmentAreFailClosed() public {
        incident.execute(
            address(registry), abi.encodeCall(registry.revokeRoute, (ROUTE_A, uint64(1)))
        );
        IRouteLifecycleRegistryV2.Route memory revokedHistorical = registry.getRoute(ROUTE_A);
        assertEq(
            uint256(revokedHistorical.status),
            uint256(IRouteLifecycleRegistryV2.RouteStatus.Revoked)
        );
        assertEq(revokedHistorical.rootAuthority, address(rootA));
        assertEq(revokedHistorical.pfrAuthority, address(pfrA));

        (RouteLifecycleRegistryV2 registry2, StateSyncGKRSettlementV2 settlement2) =
            _bareLineage(bytes32(uint256(LINEAGE) ^ 2));
        (ReceiptRootAuthorityV2 root2, PrimaryFinalityAuthorityV2 pfr2) =
            _deployAuthoritiesFor(registry2, settlement2, ROUTE_A, 2, 3, 4, 5);
        registry2.activateRoute(ROUTE_A, address(root2), address(pfr2), 0);
        _registerRootFor(root2, ROUTE_A, 2, 3, 53_668, 1);
        IRouteLifecycleRegistryV2.Route memory beforeAbandon = registry2.getRoute(ROUTE_A);
        IReceiptRootAuthorityV2.RegisteredRoot memory rootBeforeAbandon =
            root2.registeredRoot(ReceiptRootEncodingV2.coordinateId(ROUTE_A, NETWORK, 2, 53_668));
        incident.execute(address(registry2), abi.encodeCall(registry2.abandonLineage, ()));
        assertTrue(registry2.lineageAbandoned());
        _assertRegistryFailureFor(
            registry2,
            abi.encodeCall(registry2.revokeRoute, (ROUTE_A, uint64(1))),
            RouteLifecycleRegistryV2.LineageIsAbandoned.selector
        );
        _assertRegistryFailureFor(
            registry2,
            abi.encodeCall(registry2.initializeLineageSettlement, (address(settlement2))),
            RouteLifecycleRegistryV2.LineageIsAbandoned.selector
        );
        _assertRegistryFailureFor(
            registry2,
            abi.encodeCall(
                registry2.activateRoute, (ROUTE_B, address(root2), address(pfr2), uint64(0))
            ),
            RouteLifecycleRegistryV2.LineageIsAbandoned.selector
        );
        _assertRegistryFailureFor(
            registry2,
            abi.encodeCall(registry2.startDrain, (ROUTE_A, uint64(1), uint64(105))),
            RouteLifecycleRegistryV2.LineageIsAbandoned.selector
        );
        _assertRegistryFailureFor(
            registry2,
            abi.encodeCall(registry2.replaceRoute, (ROUTE_A, uint64(1), ROUTE_B)),
            RouteLifecycleRegistryV2.LineageIsAbandoned.selector
        );
        (
            ReceiptRootEncodingV1.PrimaryFinalityRecord memory record,
            IPrimaryFinalityAuthorityV2.Authorization memory pfrAuthorization
        ) = _recordAndAuthorizationFor(settlement2, pfr2, ROUTE_A, 1);
        _assertSettlementFailure(
            settlement2,
            pfr2,
            abi.encodeCall(
                settlement2.consume,
                (
                    ROUTE_A,
                    record,
                    _raw(),
                    _receipt(53_668),
                    pfrAuthorization,
                    _signPfr(pfr2, pfrAuthorization, 4, 5)
                )
            ),
            StateSyncGKRSettlementV2.LineageAbandoned.selector
        );
        IRouteLifecycleRegistryV2.Route memory afterAbandon = registry2.getRoute(ROUTE_A);
        IReceiptRootAuthorityV2.RegisteredRoot memory rootAfterAbandon =
            root2.registeredRoot(ReceiptRootEncodingV2.coordinateId(ROUTE_A, NETWORK, 2, 53_668));
        assertEq(keccak256(abi.encode(afterAbandon)), keccak256(abi.encode(beforeAbandon)));
        assertEq(keccak256(abi.encode(rootAfterAbandon)), keccak256(abi.encode(rootBeforeAbandon)));
    }

    function testCrossLineageSettlementAndAuthorizationReplayAreRejected() public {
        (RouteLifecycleRegistryV2 registry2, StateSyncGKRSettlementV2 settlement2) =
            _bareLineage(bytes32(uint256(LINEAGE) ^ 3));
        (ReceiptRootAuthorityV2 root2, PrimaryFinalityAuthorityV2 pfr2) =
            _deployAuthoritiesFor(registry2, settlement2, ROUTE_A, 2, 3, 4, 5);
        registry2.activateRoute(ROUTE_A, address(root2), address(pfr2), 0);

        IReceiptRootAuthorityV2.Authorization memory lineageOneAuthorization =
            _rootAuthorization(rootA, ROUTE_A, 53_668, 1);
        _assertRootFailure(
            root2,
            abi.encodeCall(
                root2.register,
                (lineageOneAuthorization, _signRoot(rootA, lineageOneAuthorization, 2, 3))
            ),
            ReceiptRootAuthorityV2.AuthorizationContextMismatch.selector
        );

        _registerRootFor(root2, ROUTE_A, 2, 3, 53_668, 1);
        (
            ReceiptRootEncodingV1.PrimaryFinalityRecord memory wrongLineageRecord,
            IPrimaryFinalityAuthorityV2.Authorization memory wrongLineagePfr
        ) = _recordAndAuthorization(pfrA, ROUTE_A, 1);
        _assertSettlementFailure(
            settlement2,
            pfr2,
            abi.encodeCall(
                settlement2.consume,
                (
                    ROUTE_A,
                    wrongLineageRecord,
                    _raw(),
                    _receipt(53_668),
                    wrongLineagePfr,
                    _signPfr(pfrA, wrongLineagePfr, 4, 5)
                )
            ),
            StateSyncGKRSettlementV2.InvalidPrimaryFinalityRecord.selector
        );
    }

    function testRegistrationAndConsumptionWindowsAreHalfOpen() public {
        IReceiptRootAuthorityV2.Authorization memory atUntil =
            _rootAuthorization(rootA, ROUTE_A, 53_668, 1);
        atUntil.validUntilBlock = 101;
        bytes[] memory atUntilSignatures = _signRoot(rootA, atUntil, 2, 3);
        vm.roll(101);
        _assertRootFailure(
            rootA,
            abi.encodeCall(rootA.register, (atUntil, atUntilSignatures)),
            ReceiptRootAuthorityV2.InvalidValidityWindow.selector
        );

        (RouteLifecycleRegistryV2 registry2, StateSyncGKRSettlementV2 settlement2) =
            _bareLineage(bytes32(uint256(LINEAGE) ^ 4));
        (ReceiptRootAuthorityV2 root2, PrimaryFinalityAuthorityV2 pfr2) =
            _deployAuthoritiesFor(registry2, settlement2, ROUTE_A, 2, 3, 4, 5);
        registry2.activateRoute(ROUTE_A, address(root2), address(pfr2), 0);
        IReceiptRootAuthorityV2.Authorization memory exactStart =
            _rootAuthorization(root2, ROUTE_A, 53_668, 1);
        exactStart.validAfterBlock = 102;
        exactStart.validUntilBlock = 120;
        bytes[] memory exactStartSignatures = _signRoot(root2, exactStart, 2, 3);
        vm.roll(102);
        root2.register(exactStart, exactStartSignatures);

        (
            ReceiptRootEncodingV1.PrimaryFinalityRecord memory record,
            IPrimaryFinalityAuthorityV2.Authorization memory pfrAuthorization
        ) = _recordAndAuthorizationFor(settlement2, pfr2, ROUTE_A, 1);
        pfrAuthorization.validUntilBlock = 103;
        bytes[] memory pfrSignatures = _signPfr(pfr2, pfrAuthorization, 4, 5);
        vm.roll(103);
        _assertSettlementFailure(
            settlement2,
            pfr2,
            abi.encodeCall(
                settlement2.consume,
                (ROUTE_A, record, _raw(), _receipt(53_668), pfrAuthorization, pfrSignatures)
            ),
            PrimaryFinalityAuthorityV2.InvalidValidityWindow.selector
        );

        (RouteLifecycleRegistryV2 registry3, StateSyncGKRSettlementV2 settlement3) =
            _bareLineage(bytes32(uint256(LINEAGE) ^ 5));
        (ReceiptRootAuthorityV2 root3, PrimaryFinalityAuthorityV2 pfr3) =
            _deployAuthoritiesFor(registry3, settlement3, ROUTE_A, 2, 3, 4, 5);
        registry3.activateRoute(ROUTE_A, address(root3), address(pfr3), 0);
        IReceiptRootAuthorityV2.Authorization memory expiringRoot =
            _rootAuthorization(root3, ROUTE_A, 53_668, 1);
        expiringRoot.validUntilBlock = 104;
        root3.register(expiringRoot, _signRoot(root3, expiringRoot, 2, 3));
        (record, pfrAuthorization) = _recordAndAuthorizationFor(settlement3, pfr3, ROUTE_A, 1);
        pfrSignatures = _signPfr(pfr3, pfrAuthorization, 4, 5);
        vm.roll(104);
        _assertSettlementFailure(
            settlement3,
            pfr3,
            abi.encodeCall(
                settlement3.consume,
                (ROUTE_A, record, _raw(), _receipt(53_668), pfrAuthorization, pfrSignatures)
            ),
            StateSyncGKRSettlementV2.RootExpired.selector
        );
    }

    function testPfrNonceReuseSkipAndLatentFuturePredecessorAreRejected() public {
        _registerRoot(rootA, ROUTE_A, 2, 3, 53_668, 1);
        (
            ReceiptRootEncodingV1.PrimaryFinalityRecord memory firstRecord,
            IPrimaryFinalityAuthorityV2.Authorization memory firstAuthorization
        ) = _recordAndAuthorization(pfrA, ROUTE_A, 1);
        settlement.consume(
            ROUTE_A,
            firstRecord,
            _raw(),
            _receipt(53_668),
            firstAuthorization,
            _signPfr(pfrA, firstAuthorization, 4, 5)
        );

        ReceiptRootEncodingV1.PrimaryFinalityRecord memory latentRecord =
            _recordWithTransition(bytes32(uint256(firstRecord.primaryTransitionId) ^ 3));
        IPrimaryFinalityAuthorityV2.Authorization memory latentAuthorization =
            _pfrAuthorization(pfrA, ROUTE_A, ReceiptRootEncodingV1.pfrRecordId(latentRecord), 1);
        latentAuthorization.authorizationNonce = 3;
        latentAuthorization.previousAuthorizationDigest = bytes32(0);
        bytes[] memory latentSignatures = _signPfr(pfrA, latentAuthorization, 4, 5);

        ReceiptRootEncodingV1.PrimaryFinalityRecord memory secondRecord =
            _recordWithTransition(bytes32(uint256(firstRecord.primaryTransitionId) ^ 2));
        IPrimaryFinalityAuthorityV2.Authorization memory secondAuthorization =
            _pfrAuthorization(pfrA, ROUTE_A, ReceiptRootEncodingV1.pfrRecordId(secondRecord), 1);
        settlement.consume(
            ROUTE_A,
            secondRecord,
            _raw(),
            _receipt(53_668),
            secondAuthorization,
            _signPfr(pfrA, secondAuthorization, 4, 5)
        );
        assertEq(pfrA.nextAuthorizationNonce(), 3);

        _assertSettlementFailure(
            settlement,
            pfrA,
            abi.encodeCall(
                settlement.consume,
                (
                    ROUTE_A,
                    latentRecord,
                    _raw(),
                    _receipt(53_668),
                    latentAuthorization,
                    latentSignatures
                )
            ),
            PrimaryFinalityAuthorityV2.PreviousAuthorizationDigestMismatch.selector
        );

        ReceiptRootEncodingV1.PrimaryFinalityRecord memory reuseRecord =
            _recordWithTransition(bytes32(uint256(firstRecord.primaryTransitionId) ^ 4));
        IPrimaryFinalityAuthorityV2.Authorization memory reuseAuthorization =
            _pfrAuthorization(pfrA, ROUTE_A, ReceiptRootEncodingV1.pfrRecordId(reuseRecord), 1);
        reuseAuthorization.authorizationNonce = 1;
        _assertSettlementFailure(
            settlement,
            pfrA,
            abi.encodeCall(
                settlement.consume,
                (
                    ROUTE_A,
                    reuseRecord,
                    _raw(),
                    _receipt(53_668),
                    reuseAuthorization,
                    _signPfr(pfrA, reuseAuthorization, 4, 5)
                )
            ),
            PrimaryFinalityAuthorityV2.UnexpectedAuthorizationNonce.selector
        );

        reuseAuthorization.authorizationNonce = 4;
        _assertSettlementFailure(
            settlement,
            pfrA,
            abi.encodeCall(
                settlement.consume,
                (
                    ROUTE_A,
                    reuseRecord,
                    _raw(),
                    _receipt(53_668),
                    reuseAuthorization,
                    _signPfr(pfrA, reuseAuthorization, 4, 5)
                )
            ),
            PrimaryFinalityAuthorityV2.UnexpectedAuthorizationNonce.selector
        );
    }

    function testEpochOneAndCrossRoleActivationAreRejected() public {
        address[] memory rootSigners = _twoSigners(2, 3);
        try new ReceiptRootAuthorityV2(
            ROUTE_B,
            registry,
            address(settlement),
            1,
            rootSigners,
            2,
            20,
            NETWORK,
            GENESIS,
            RUNTIME,
            CONTEXT,
            2
        ) {
            revert AssertionFailed();
        } catch (bytes memory reason) {
            assertTrue(_selector(reason) == ReceiptRootAuthorityV2.EpochTwoRequired.selector);
        }

        address[] memory shared = _twoSigners(6, 7);
        ReceiptRootAuthorityV2 rootB = new ReceiptRootAuthorityV2(
            ROUTE_B,
            registry,
            address(settlement),
            2,
            shared,
            2,
            20,
            NETWORK,
            GENESIS,
            RUNTIME,
            CONTEXT,
            2
        );
        PrimaryFinalityAuthorityV2 pfrB = new PrimaryFinalityAuthorityV2(
            ROUTE_B, address(registry), address(settlement), 2, shared, 2, 20
        );
        _assertRegistryFailure(
            abi.encodeCall(
                registry.activateRoute, (ROUTE_B, address(rootB), address(pfrB), uint64(0))
            ),
            RouteLifecycleRegistryV2.RoleOverlap.selector
        );
    }

    function _deployAuthorities(
        bytes32 routeId,
        uint256 rootKey1,
        uint256 rootKey2,
        uint256 pfrKey1,
        uint256 pfrKey2
    ) internal returns (ReceiptRootAuthorityV2 root, PrimaryFinalityAuthorityV2 pfr) {
        return
            _deployAuthoritiesFor(
                registry, settlement, routeId, rootKey1, rootKey2, pfrKey1, pfrKey2
            );
    }

    function _deployAuthoritiesFor(
        RouteLifecycleRegistryV2 registry_,
        StateSyncGKRSettlementV2 settlement_,
        bytes32 routeId,
        uint256 rootKey1,
        uint256 rootKey2,
        uint256 pfrKey1,
        uint256 pfrKey2
    ) internal returns (ReceiptRootAuthorityV2 root, PrimaryFinalityAuthorityV2 pfr) {
        root = new ReceiptRootAuthorityV2(
            routeId,
            registry_,
            address(settlement_),
            2,
            _twoSigners(rootKey1, rootKey2),
            2,
            20,
            NETWORK,
            GENESIS,
            RUNTIME,
            CONTEXT,
            2
        );
        pfr = new PrimaryFinalityAuthorityV2(
            routeId,
            address(registry_),
            address(settlement_),
            2,
            _twoSigners(pfrKey1, pfrKey2),
            2,
            20
        );
    }

    function _bareLineage(bytes32 lineage)
        internal
        returns (RouteLifecycleRegistryV2 registry_, StateSyncGKRSettlementV2 settlement_)
    {
        registry_ = new RouteLifecycleRegistryV2(lineage, address(this), address(incident), 10);
        settlement_ = new StateSyncGKRSettlementV2(registry_, IMAGE, VERSION);
        registry_.initializeLineageSettlement(address(settlement_));
    }

    function _registerRoot(
        ReceiptRootAuthorityV2 root,
        bytes32 routeId,
        uint256 key1,
        uint256 key2,
        uint64 aggregationId,
        uint64 revision
    ) internal {
        _registerRootFor(root, routeId, key1, key2, aggregationId, revision);
    }

    function _registerRootFor(
        ReceiptRootAuthorityV2 root,
        bytes32 routeId,
        uint256 key1,
        uint256 key2,
        uint64 aggregationId,
        uint64 revision
    ) internal {
        IReceiptRootAuthorityV2.Authorization memory authorization =
            _rootAuthorization(root, routeId, aggregationId, revision);
        root.register(authorization, _signRoot(root, authorization, key1, key2));
    }

    function _rootAuthorization(
        ReceiptRootAuthorityV2 root,
        bytes32 routeId,
        uint64 aggregationId,
        uint64 revision
    ) internal view returns (IReceiptRootAuthorityV2.Authorization memory) {
        return IReceiptRootAuthorityV2.Authorization({
                signerSetEpoch: 2,
                sourceNetworkId: NETWORK,
                sourceGenesisHash: GENESIS,
                sourceRuntimeId: RUNTIME,
                verificationContextHash: CONTEXT,
                domainId: 2,
                sourceBlockNumber: 6_726_351,
                sourceBlockHash: BLOCK_HASH,
                aggregationId: aggregationId,
                root: keccak256(abi.encodePacked(_statement())),
                leafCount: 1,
                routeId: routeId,
                lifecycleRegistry: root.lifecycleRegistry(),
                destinationSettlement: root.destinationSettlement(),
                lifecycleRevision: revision,
                validAfterBlock: uint64(block.number),
                validUntilBlock: uint64(block.number + 20),
                authorizationNonce: root.nextAuthorizationNonce(),
                previousAuthorizationDigest: root.lastAuthorizationDigest()
            });
    }

    function _recordAndAuthorization(
        PrimaryFinalityAuthorityV2 pfr,
        bytes32 routeId,
        uint64 revision
    )
        internal
        view
        returns (
            ReceiptRootEncodingV1.PrimaryFinalityRecord memory record,
            IPrimaryFinalityAuthorityV2.Authorization memory authorization
        )
    {
        return _recordAndAuthorizationFor(settlement, pfr, routeId, revision);
    }

    function _recordAndAuthorizationFor(
        StateSyncGKRSettlementV2 settlement_,
        PrimaryFinalityAuthorityV2 pfr,
        bytes32 routeId,
        uint64 revision
    )
        internal
        view
        returns (
            ReceiptRootEncodingV1.PrimaryFinalityRecord memory record,
            IPrimaryFinalityAuthorityV2.Authorization memory authorization
        )
    {
        record = ReceiptRootEncodingV1.PrimaryFinalityRecord({
            primaryTransitionId: sha256(_raw()),
            routeId: routeId,
            rawStatementSha256: sha256(_raw()),
            preclaimHash: ReceiptRootEncodingV1.preclaimHash(routeId, _raw()),
            source: NETWORK,
            destinationChainId: settlement_.destinationChainId(),
            destinationConsumer: settlement_.destinationConsumer(),
            actionKind: 0,
            checkpoint: 6_726_351,
            sessionId: BLOCK_HASH,
            bvcId: CONTEXT,
            acceptedRoot: ACCEPTED,
            state: 1,
            signerSetEpoch: 2,
            issuanceHeight: 6_726_351,
            hasSupersedes: false,
            supersedesRecordId: bytes32(0)
        });
        authorization =
            _pfrAuthorization(pfr, routeId, ReceiptRootEncodingV1.pfrRecordId(record), revision);
    }

    function _pfrAuthorization(
        PrimaryFinalityAuthorityV2 pfr,
        bytes32 routeId,
        bytes32 pfrId,
        uint64 revision
    ) internal view returns (IPrimaryFinalityAuthorityV2.Authorization memory) {
        return IPrimaryFinalityAuthorityV2.Authorization({
                primaryFinalityRecordId: pfrId,
                routeId: routeId,
                lifecycleRegistry: pfr.lifecycleRegistry(),
                destinationSettlement: pfr.destinationSettlement(),
                signerSetEpoch: 2,
                lifecycleRevision: revision,
                validAfterBlock: uint64(block.number),
                validUntilBlock: uint64(block.number + 20),
                authorizationNonce: pfr.nextAuthorizationNonce(),
                previousAuthorizationDigest: pfr.lastAuthorizationDigest()
            });
    }

    function _recordWithTransition(bytes32 transitionId)
        internal
        view
        returns (ReceiptRootEncodingV1.PrimaryFinalityRecord memory record)
    {
        (record,) = _recordAndAuthorization(pfrA, ROUTE_A, 1);
        record.primaryTransitionId = transitionId;
    }

    function _receipt(uint64 aggregationId)
        internal
        pure
        returns (StateSyncGKRSettlementV2.ReceiptAttachment memory)
    {
        return StateSyncGKRSettlementV2.ReceiptAttachment({
            sourceNetworkId: NETWORK,
            domainId: 2,
            aggregationId: aggregationId,
            sourceBlockNumber: 6_726_351,
            sourceBlockHash: BLOCK_HASH,
            sourceRuntimeId: RUNTIME,
            verificationContextHash: CONTEXT,
            statement: _statement(),
            leafCount: 1,
            leafIndex: 0,
            merklePath: new bytes32[](0)
        });
    }

    function _statement() internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(CONTEXT, IMAGE, VERSION, keccak256(_raw())));
    }

    function _signRoot(
        ReceiptRootAuthorityV2 root,
        IReceiptRootAuthorityV2.Authorization memory authorization,
        uint256 key1,
        uint256 key2
    ) internal returns (bytes[] memory) {
        return _signTwo(key1, key2, root.authorizationDigest(authorization));
    }

    function _signPfr(
        PrimaryFinalityAuthorityV2 pfr,
        IPrimaryFinalityAuthorityV2.Authorization memory authorization,
        uint256 key1,
        uint256 key2
    ) internal returns (bytes[] memory) {
        return _signTwo(key1, key2, pfr.authorizationDigest(authorization));
    }

    function _signTwo(uint256 key1, uint256 key2, bytes32 digest)
        internal
        returns (bytes[] memory signatures)
    {
        signatures = new bytes[](2);
        if (vm.addr(key1) < vm.addr(key2)) {
            signatures[0] = signature(key1, digest);
            signatures[1] = signature(key2, digest);
        } else {
            signatures[0] = signature(key2, digest);
            signatures[1] = signature(key1, digest);
        }
    }

    function _twoSigners(uint256 key1, uint256 key2) internal returns (address[] memory signers) {
        signers = new address[](2);
        address first = vm.addr(key1);
        address second = vm.addr(key2);
        if (first < second) {
            signers[0] = first;
            signers[1] = second;
        } else {
            signers[0] = second;
            signers[1] = first;
        }
    }

    function _assertSignedRootFailure(
        IReceiptRootAuthorityV2.Authorization memory authorization,
        bytes4 selector
    ) internal {
        bytes[] memory signatures = _signRoot(rootA, authorization, 2, 3);
        _assertRootFailure(
            rootA, abi.encodeCall(rootA.register, (authorization, signatures)), selector
        );
    }

    function _assertRootFailure(ReceiptRootAuthorityV2 root, bytes memory callData, bytes4 selector)
        internal
    {
        bytes32 beforeDigest = root.stateDigest();
        vm.recordLogs();
        (bool ok, bytes memory reason) = address(root).call(callData);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(!ok);
        assertTrue(_selector(reason) == selector);
        assertEq(root.stateDigest(), beforeDigest);
        assertEq(logs.length, 0);
    }

    function _assertRegistryFailure(bytes memory callData, bytes4 selector) internal {
        _assertRegistryFailureFor(registry, callData, selector);
    }

    function _assertRegistryFailureFor(
        RouteLifecycleRegistryV2 registry_,
        bytes memory callData,
        bytes4 selector
    ) internal {
        bytes32 beforeDigest = registry_.stateDigest();
        vm.recordLogs();
        (bool ok, bytes memory reason) = address(registry_).call(callData);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(!ok);
        assertTrue(_selector(reason) == selector);
        assertEq(registry_.stateDigest(), beforeDigest);
        assertEq(logs.length, 0);
    }

    function _assertActorRegistryFailure(
        IncidentActorV2 actor,
        bytes memory registryCall,
        bytes4 selector
    ) internal {
        bytes32 beforeDigest = registry.stateDigest();
        vm.recordLogs();
        (bool ok, bytes memory reason) =
            address(actor).call(abi.encodeCall(actor.execute, (address(registry), registryCall)));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(!ok);
        assertTrue(_selector(reason) == selector);
        assertEq(registry.stateDigest(), beforeDigest);
        assertEq(logs.length, 0);
    }

    function _assertSettlementFailure(
        StateSyncGKRSettlementV2 settlement_,
        PrimaryFinalityAuthorityV2 pfr,
        bytes memory callData,
        bytes4 selector
    ) internal {
        bytes32 settlementBefore = settlement_.stateDigest();
        bytes32 pfrBefore = pfr.stateDigest();
        vm.recordLogs();
        (bool ok, bytes memory reason) = address(settlement_).call(callData);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(!ok);
        assertTrue(_selector(reason) == selector);
        assertEq(settlement_.stateDigest(), settlementBefore);
        assertEq(pfr.stateDigest(), pfrBefore);
        assertEq(logs.length, 0);
    }

    function _selector(bytes memory reason) internal pure returns (bytes4 selector) {
        if (reason.length < 4) return bytes4(0);
        assembly ("memory-safe") { selector := mload(add(reason, 32)) }
    }

    function _raw() internal pure returns (bytes memory) {
        return hex"01000100010001001f0000001800000000000000000000000000000000000000abde249a257cd4e6c3ed34f2749a7d8be66fd418f5a5d8595bffc956b45f0e0088957f2aa94f0f483d11f6bbc00b37db9fedd7911eee56e15c1661e14845320088957f2aa94f0f483d11f6bbc00b37db9fedd7911eee56e15c1661e14845320005000000000000000000000000000000000000000000000000000000000000004cc6356134cfb0dcefee384334580a10c3f82929f64a9f8833dd47ebc2cdbf00";
    }
}
