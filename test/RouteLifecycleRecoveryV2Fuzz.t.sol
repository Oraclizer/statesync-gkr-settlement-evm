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

contract EncodingV2Harness {
    function rootDigest(
        IReceiptRootAuthorityV2.Authorization memory authorization,
        uint256 chainId,
        address verifyingContract
    ) external pure returns (bytes32) {
        return ReceiptRootEncodingV2.rootAuthorizationDigest(
            authorization, chainId, verifyingContract
        );
    }

    function pfrDigest(
        IPrimaryFinalityAuthorityV2.Authorization memory authorization,
        uint256 chainId,
        address verifyingContract
    ) external pure returns (bytes32) {
        return ReceiptRootEncodingV2.pfrAuthorizationDigest(
            authorization, chainId, verifyingContract
        );
    }

    function settlementKey(bytes32 transitionId, uint64 chainId, bytes32 consumer, uint8 action)
        external
        pure
        returns (bytes32)
    {
        return ReceiptRootEncodingV1.settlementKey(transitionId, chainId, consumer, action);
    }

    function claimId(bytes32 routeId, bytes32 pfrId, bytes memory rawStatement)
        external
        pure
        returns (bytes32)
    {
        return ReceiptRootEncodingV1.claimId(routeId, pfrId, rawStatement);
    }

    function coordinateId(
        bytes32 routeId,
        bytes32 sourceNetworkId,
        uint32 domainId,
        uint64 aggregationId
    ) external pure returns (bytes32) {
        return ReceiptRootEncodingV2.coordinateId(routeId, sourceNetworkId, domainId, aggregationId);
    }
}

contract FuzzActorV2 {
    function execute(address target, bytes calldata data) external returns (bytes memory result) {
        (bool ok, bytes memory returned) = target.call(data);
        if (!ok) {
            assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        }
        return returned;
    }
}

contract RootNonceInvariantHandlerV2 {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    ReceiptRootAuthorityV2 public immutable root;
    bytes32 public immutable routeId;
    uint64 public successfulRegistrations;
    uint64 public rejectedSkips;
    uint64 public rejectedPredecessors;

    constructor(ReceiptRootAuthorityV2 root_, bytes32 routeId_) {
        root = root_;
        routeId = routeId_;
    }

    function step(uint64 aggregationId) external {
        if (successfulRegistrations >= 32) return;
        if (!IRouteLifecycleRegistryV2(root.lifecycleRegistry())
                .rootRegistrationAllowed(routeId, address(root), 1)) return;
        IReceiptRootAuthorityV2.Authorization memory authorization = _authorization(aggregationId);
        bytes32 coordinate = ReceiptRootEncodingV2.coordinateId(
            routeId, authorization.sourceNetworkId, authorization.domainId, aggregationId
        );
        if (root.registeredRoot(coordinate).exists) return;
        root.register(authorization, _sign(authorization));
        ++successfulRegistrations;
    }

    function attemptSkip(uint64 aggregationId) external {
        IReceiptRootAuthorityV2.Authorization memory authorization = _authorization(aggregationId);
        authorization.authorizationNonce += 1;
        bytes32 beforeDigest = root.stateDigest();
        (bool ok,) =
            address(root).call(abi.encodeCall(root.register, (authorization, _sign(authorization))));
        require(!ok && root.stateDigest() == beforeDigest);
        ++rejectedSkips;
    }

    function attemptWrongPredecessor(uint64 aggregationId, bytes32 wrong) external {
        IReceiptRootAuthorityV2.Authorization memory authorization = _authorization(aggregationId);
        if (wrong == root.lastAuthorizationDigest()) wrong = bytes32(uint256(wrong) ^ 1);
        authorization.previousAuthorizationDigest = wrong;
        bytes32 beforeDigest = root.stateDigest();
        (bool ok,) =
            address(root).call(abi.encodeCall(root.register, (authorization, _sign(authorization))));
        require(!ok && root.stateDigest() == beforeDigest);
        ++rejectedPredecessors;
    }

    function _authorization(uint64 aggregationId)
        private
        view
        returns (IReceiptRootAuthorityV2.Authorization memory)
    {
        return IReceiptRootAuthorityV2.Authorization({
            signerSetEpoch: 2,
            sourceNetworkId: keccak256("network"),
            sourceGenesisHash: keccak256("genesis"),
            sourceRuntimeId: keccak256("runtime"),
            verificationContextHash: keccak256("context"),
            domainId: 2,
            sourceBlockNumber: 7,
            sourceBlockHash: keccak256("block"),
            aggregationId: aggregationId,
            root: keccak256(abi.encode(aggregationId)),
            leafCount: 1,
            routeId: routeId,
            lifecycleRegistry: root.lifecycleRegistry(),
            destinationSettlement: root.destinationSettlement(),
            lifecycleRevision: 1,
            validAfterBlock: uint64(block.number),
            validUntilBlock: uint64(block.number + 20),
            authorizationNonce: root.nextAuthorizationNonce(),
            previousAuthorizationDigest: root.lastAuthorizationDigest()
        });
    }

    function _sign(IReceiptRootAuthorityV2.Authorization memory authorization)
        private
        returns (bytes[] memory signatures)
    {
        bytes32 digest = root.authorizationDigest(authorization);
        signatures = new bytes[](2);
        signatures[0] = _signature(2, digest);
        signatures[1] = _signature(3, digest);
    }

    function _signature(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }
}

contract LifecycleInvariantHandlerV2 {
    FuzzActorV2 public immutable governance;
    FuzzActorV2 public immutable incident;
    RouteLifecycleRegistryV2 public immutable registry;
    bytes32 public immutable routeId;
    bool public terminalFrozen;
    bytes32 public terminalRouteHash;

    constructor(
        FuzzActorV2 governance_,
        FuzzActorV2 incident_,
        RouteLifecycleRegistryV2 registry_,
        bytes32 routeId_
    ) {
        governance = governance_;
        incident = incident_;
        registry = registry_;
        routeId = routeId_;
    }

    function step(uint8 action, uint64 delta) external {
        IRouteLifecycleRegistryV2.Route memory beforeRoute = registry.getRoute(routeId);
        if (registry.lineageAbandoned()) {
            _attemptAfterTerminal(beforeRoute.revision);
            _checkTerminal();
            return;
        }
        if (beforeRoute.status == IRouteLifecycleRegistryV2.RouteStatus.Active) {
            if (action % 3 == 0) {
                uint64 cutoff = uint64(block.number + 1 + (delta % 10));
                governance.execute(
                    address(registry),
                    abi.encodeCall(registry.startDrain, (routeId, beforeRoute.revision, cutoff))
                );
            } else if (action % 3 == 1) {
                incident.execute(
                    address(registry),
                    abi.encodeCall(registry.revokeRoute, (routeId, beforeRoute.revision))
                );
            } else {
                incident.execute(address(registry), abi.encodeCall(registry.abandonLineage, ()));
            }
        } else if (beforeRoute.status == IRouteLifecycleRegistryV2.RouteStatus.Draining) {
            if (action % 2 == 0) {
                governance.execute(
                    address(registry),
                    abi.encodeCall(registry.revokeRoute, (routeId, beforeRoute.revision))
                );
            } else {
                incident.execute(address(registry), abi.encodeCall(registry.abandonLineage, ()));
            }
        } else {
            _attemptAfterTerminal(beforeRoute.revision);
        }
        _checkTerminal();
    }

    function _attemptAfterTerminal(uint64 revision) private {
        (bool ok,) = address(governance)
            .call(
                abi.encodeCall(
                    governance.execute,
                    (address(registry), abi.encodeCall(registry.revokeRoute, (routeId, revision)))
                )
            );
        require(!ok);
    }

    function _checkTerminal() private {
        IRouteLifecycleRegistryV2.Route memory current = registry.getRoute(routeId);
        bool terminal = registry.lineageAbandoned()
            || current.status == IRouteLifecycleRegistryV2.RouteStatus.Revoked
            || current.status == IRouteLifecycleRegistryV2.RouteStatus.Replaced;
        bytes32 currentHash = keccak256(abi.encode(current));
        if (!terminal) return;
        if (!terminalFrozen) {
            terminalFrozen = true;
            terminalRouteHash = currentHash;
        } else {
            require(currentHash == terminalRouteHash);
        }
    }
}

contract RouteLifecycleRecoveryV2FuzzTest is TestBase {
    bytes32 internal constant ROUTE = keccak256("route/invariant/epoch2");
    EncodingV2Harness internal encoding;
    RouteLifecycleRegistryV2 internal registry;
    StateSyncGKRSettlementV2 internal settlement;
    ReceiptRootAuthorityV2 internal root;
    PrimaryFinalityAuthorityV2 internal pfr;
    FuzzActorV2 internal governance;
    FuzzActorV2 internal incident;
    RootNonceInvariantHandlerV2 internal nonceHandler;
    LifecycleInvariantHandlerV2 internal lifecycleHandler;
    address[] internal targets;

    function setUp() public {
        vm.chainId(84_532);
        vm.roll(100);
        encoding = new EncodingV2Harness();
        governance = new FuzzActorV2();
        incident = new FuzzActorV2();
        registry = new RouteLifecycleRegistryV2(
            keccak256("lineage/invariant"), address(governance), address(incident), 10
        );
        settlement =
            new StateSyncGKRSettlementV2(registry, keccak256("image"), keccak256("version"));
        governance.execute(
            address(registry),
            abi.encodeCall(registry.initializeLineageSettlement, (address(settlement)))
        );
        address[] memory rootSigners = new address[](2);
        rootSigners[0] = vm.addr(2);
        rootSigners[1] = vm.addr(3);
        address[] memory pfrSigners = new address[](2);
        pfrSigners[0] = vm.addr(4);
        pfrSigners[1] = vm.addr(5);
        root = new ReceiptRootAuthorityV2(
            ROUTE,
            registry,
            address(settlement),
            2,
            rootSigners,
            2,
            20,
            keccak256("network"),
            keccak256("genesis"),
            keccak256("runtime"),
            keccak256("context"),
            2
        );
        pfr = new PrimaryFinalityAuthorityV2(
            ROUTE, address(registry), address(settlement), 2, pfrSigners, 2, 20
        );
        governance.execute(
            address(registry),
            abi.encodeCall(registry.activateRoute, (ROUTE, address(root), address(pfr), uint64(0)))
        );
        nonceHandler = new RootNonceInvariantHandlerV2(root, ROUTE);
        lifecycleHandler = new LifecycleInvariantHandlerV2(governance, incident, registry, ROUTE);
        targets.push(address(nonceHandler));
        targets.push(address(lifecycleHandler));
    }

    function targetContracts() public view returns (address[] memory) {
        return targets;
    }

    function testFuzzRootAuthorizationBindsEveryField(
        bytes32 seed,
        uint256 chainId,
        address verifyingContract
    ) public view {
        if (verifyingContract == address(0)) verifyingContract = address(1);
        IReceiptRootAuthorityV2.Authorization memory authorization = _rootAuthorization(seed);
        bytes32 digest = encoding.rootDigest(authorization, chainId, verifyingContract);
        authorization.signerSetEpoch ^= 1;
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.sourceNetworkId = _flip(authorization.sourceNetworkId);
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.sourceGenesisHash = _flip(authorization.sourceGenesisHash);
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.sourceRuntimeId = _flip(authorization.sourceRuntimeId);
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.verificationContextHash = _flip(authorization.verificationContextHash);
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.domainId ^= 1;
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.sourceBlockNumber ^= 1;
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.sourceBlockHash = _flip(authorization.sourceBlockHash);
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.aggregationId ^= 1;
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.root = _flip(authorization.root);
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.leafCount ^= 1;
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.routeId = _flip(authorization.routeId);
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.lifecycleRegistry = _flip(authorization.lifecycleRegistry);
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.destinationSettlement = _flip(authorization.destinationSettlement);
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.lifecycleRevision ^= 1;
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.validAfterBlock ^= 1;
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.validUntilBlock ^= 1;
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.authorizationNonce ^= 1;
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _rootAuthorization(seed);
        authorization.previousAuthorizationDigest = _flip(authorization.previousAuthorizationDigest);
        assertTrue(encoding.rootDigest(authorization, chainId, verifyingContract) != digest);
        assertTrue(
            encoding.rootDigest(_rootAuthorization(seed), chainId ^ 1, verifyingContract) != digest
        );
        assertTrue(
            encoding.rootDigest(_rootAuthorization(seed), chainId, _flip(verifyingContract))
                != digest
        );
    }

    function testFuzzPfrAuthorizationBindsEveryField(bytes32 seed, uint256 chainId) public view {
        IPrimaryFinalityAuthorityV2.Authorization memory authorization = _pfrAuthorization(seed);
        address verifyingContract = address(0x1234);
        bytes32 digest = encoding.pfrDigest(authorization, chainId, verifyingContract);
        authorization.primaryFinalityRecordId = _flip(authorization.primaryFinalityRecordId);
        assertTrue(encoding.pfrDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _pfrAuthorization(seed);
        authorization.routeId = _flip(authorization.routeId);
        assertTrue(encoding.pfrDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _pfrAuthorization(seed);
        authorization.lifecycleRegistry = _flip(authorization.lifecycleRegistry);
        assertTrue(encoding.pfrDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _pfrAuthorization(seed);
        authorization.destinationSettlement = _flip(authorization.destinationSettlement);
        assertTrue(encoding.pfrDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _pfrAuthorization(seed);
        authorization.signerSetEpoch ^= 1;
        assertTrue(encoding.pfrDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _pfrAuthorization(seed);
        authorization.lifecycleRevision ^= 1;
        assertTrue(encoding.pfrDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _pfrAuthorization(seed);
        authorization.validAfterBlock ^= 1;
        assertTrue(encoding.pfrDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _pfrAuthorization(seed);
        authorization.validUntilBlock ^= 1;
        assertTrue(encoding.pfrDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _pfrAuthorization(seed);
        authorization.authorizationNonce ^= 1;
        assertTrue(encoding.pfrDigest(authorization, chainId, verifyingContract) != digest);
        authorization = _pfrAuthorization(seed);
        authorization.previousAuthorizationDigest = _flip(authorization.previousAuthorizationDigest);
        assertTrue(encoding.pfrDigest(authorization, chainId, verifyingContract) != digest);
        assertTrue(
            encoding.pfrDigest(_pfrAuthorization(seed), chainId ^ 1, verifyingContract) != digest
        );
        assertTrue(encoding.pfrDigest(_pfrAuthorization(seed), chainId, address(0x1235)) != digest);
    }

    function testFuzzEconomicNullifierIsRouteIndependent(
        bytes32 transition,
        uint64 chainId,
        bytes32 consumer,
        uint8 action,
        bytes32 routeA,
        bytes32 routeB
    ) public view {
        if (routeA == routeB) routeB = _flip(routeB);
        bytes memory rawStatement = abi.encode(transition, chainId, consumer, action);
        bytes32 claimA = encoding.claimId(routeA, transition, rawStatement);
        bytes32 claimB = encoding.claimId(routeB, transition, rawStatement);
        bytes32 keyA = encoding.settlementKey(transition, chainId, consumer, action);
        bytes32 keyB = encoding.settlementKey(transition, chainId, consumer, action);
        assertTrue(claimA != claimB);
        assertEq(keyA, keyB);
    }

    function testIndependentCastVectorMatchesSolidityCodec() public view {
        bytes32 routeId = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;
        bytes32 source = 0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb;
        IReceiptRootAuthorityV2.Authorization memory rootAuthorization =
            IReceiptRootAuthorityV2.Authorization({
                signerSetEpoch: 2,
                sourceNetworkId: source,
                sourceGenesisHash: 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc,
                sourceRuntimeId: 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd,
                verificationContextHash: 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee,
                domainId: 2,
                sourceBlockNumber: 6_726_351,
                sourceBlockHash: 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
                aggregationId: 53_668,
                root: bytes32(uint256(0x1234)),
                leafCount: 1,
                routeId: routeId,
                lifecycleRegistry: 0x3333333333333333333333333333333333333333,
                destinationSettlement: 0x4444444444444444444444444444444444444444,
                lifecycleRevision: 1,
                validAfterBlock: 100,
                validUntilBlock: 120,
                authorizationNonce: 1,
                previousAuthorizationDigest: bytes32(0)
            });
        assertEq(
            encoding.rootDigest(
                rootAuthorization, 84_532, 0x1111111111111111111111111111111111111111
            ),
            0x69356b7eb6c7ebc8c76996ea504d48a8a437edf92f4901bc593ffe316316251a
        );
        IPrimaryFinalityAuthorityV2.Authorization memory pfrAuthorization =
            IPrimaryFinalityAuthorityV2.Authorization({
                primaryFinalityRecordId: 0x9999999999999999999999999999999999999999999999999999999999999999,
                routeId: routeId,
                lifecycleRegistry: 0x3333333333333333333333333333333333333333,
                destinationSettlement: 0x4444444444444444444444444444444444444444,
                signerSetEpoch: 2,
                lifecycleRevision: 1,
                validAfterBlock: 100,
                validUntilBlock: 120,
                authorizationNonce: 1,
                previousAuthorizationDigest: bytes32(0)
            });
        assertEq(
            encoding.pfrDigest(
                pfrAuthorization, 84_532, 0x2222222222222222222222222222222222222222
            ),
            0xcfd300427285e6e151c98d79cd6d5ffc970537f4cabc590234e13c081bf4e19a
        );
        assertEq(
            encoding.coordinateId(routeId, source, 2, 53_668),
            0x9eafa28b0dabf1046b8016d0b11ddf59eea392ad60bf912bc340795fbce01181
        );
        assertEq(
            encoding.settlementKey(
                0x959550f3847e15ae2d69ab027d8ef59621282eeb758746262205fa3f61b38721,
                84_532,
                bytes32(uint256(uint160(0x4444444444444444444444444444444444444444))),
                0
            ),
            0x2a3823b443c2d6297db8f648dc136839cdd9ccf8832407d237a3468c31500ebd
        );
    }

    function invariant_NonceAndHashChainAdvanceOnlyTogether() public view {
        assertEq(root.nextAuthorizationNonce(), uint256(nonceHandler.successfulRegistrations()) + 1);
        assertEq(root.transitionCount(), nonceHandler.successfulRegistrations());
        assertEq(root.eventCount(), nonceHandler.successfulRegistrations());
        assertTrue(
            (root.lastAuthorizationDigest() == bytes32(0))
                == (nonceHandler.successfulRegistrations() == 0)
        );
    }

    function invariant_LifecycleRevisionCutoffAndTerminalStateAreFailClosed() public view {
        IRouteLifecycleRegistryV2.Route memory route = registry.getRoute(ROUTE);
        if (route.status == IRouteLifecycleRegistryV2.RouteStatus.Active) {
            assertEq(route.revision, 1);
        } else if (route.status == IRouteLifecycleRegistryV2.RouteStatus.Draining) {
            assertEq(route.revision, 2);
            assertEq(route.drainingFromRevision, 1);
            assertTrue(route.consumeUntilBlock > route.drainStartedAtBlock);
            assertTrue(route.consumeUntilBlock <= route.drainStartedAtBlock + 10);
        } else if (route.status == IRouteLifecycleRegistryV2.RouteStatus.Revoked) {
            assertTrue(route.revision == 2 || route.revision == 3);
        }
        if (registry.lineageAbandoned()) {
            assertTrue(!registry.rootRegistrationAllowed(ROUTE, address(root), route.revision));
        }
        if (lifecycleHandler.terminalFrozen()) {
            assertEq(keccak256(abi.encode(route)), lifecycleHandler.terminalRouteHash());
        }
    }

    function _rootAuthorization(bytes32 seed)
        private
        pure
        returns (IReceiptRootAuthorityV2.Authorization memory)
    {
        return IReceiptRootAuthorityV2.Authorization({
            signerSetEpoch: 2,
            sourceNetworkId: keccak256(abi.encode(seed, uint8(1))),
            sourceGenesisHash: keccak256(abi.encode(seed, uint8(2))),
            sourceRuntimeId: keccak256(abi.encode(seed, uint8(3))),
            verificationContextHash: keccak256(abi.encode(seed, uint8(4))),
            domainId: 7,
            sourceBlockNumber: 11,
            sourceBlockHash: keccak256(abi.encode(seed, uint8(5))),
            aggregationId: 13,
            root: keccak256(abi.encode(seed, uint8(6))),
            leafCount: 1,
            routeId: keccak256(abi.encode(seed, uint8(7))),
            lifecycleRegistry: address(0x1111),
            destinationSettlement: address(0x2222),
            lifecycleRevision: 17,
            validAfterBlock: 19,
            validUntilBlock: 23,
            authorizationNonce: 29,
            previousAuthorizationDigest: keccak256(abi.encode(seed, uint8(8)))
        });
    }

    function _pfrAuthorization(bytes32 seed)
        private
        pure
        returns (IPrimaryFinalityAuthorityV2.Authorization memory)
    {
        return IPrimaryFinalityAuthorityV2.Authorization({
            primaryFinalityRecordId: keccak256(abi.encode(seed, uint8(1))),
            routeId: keccak256(abi.encode(seed, uint8(2))),
            lifecycleRegistry: address(0x1111),
            destinationSettlement: address(0x2222),
            signerSetEpoch: 2,
            lifecycleRevision: 17,
            validAfterBlock: 19,
            validUntilBlock: 23,
            authorizationNonce: 29,
            previousAuthorizationDigest: keccak256(abi.encode(seed, uint8(3)))
        });
    }

    function _flip(bytes32 value) private pure returns (bytes32) {
        return bytes32(uint256(value) ^ 1);
    }

    function _flip(address value) private pure returns (address) {
        return address(uint160(value) ^ 1);
    }
}
