// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

import {IRouteLifecycleRegistryV2} from "./interfaces/IRouteLifecycleRegistryV2.sol";
import {IReceiptRootAuthorityV2} from "./interfaces/IReceiptRootAuthorityV2.sol";
import {IPrimaryFinalityAuthorityV2} from "./interfaces/IPrimaryFinalityAuthorityV2.sol";

interface IStateSyncGKRSettlementIdentityV2 {
    function lifecycleRegistry() external view returns (address);
}

/// @notice One lineage's fail-closed route lifecycle and recovery authority.
/// @dev The lineage settlement is initialized once and can never migrate.
contract RouteLifecycleRegistryV2 is IRouteLifecycleRegistryV2 {
    error ZeroLineageId();
    error ZeroAuthority();
    error AuthorityOverlap();
    error InvalidMaxDrainBlocks();
    error GovernanceOnly();
    error IncidentOnly();
    error LineageAlreadyInitialized();
    error InvalidLineageSettlement();
    error LineageNotInitialized();
    error LineageIsAbandoned();
    error ZeroRouteId();
    error InvalidRouteEndpoint();
    error RouteIdentityMismatch();
    error RoleOverlap();
    error RevisionMismatch();
    error InvalidTransition();
    error InvalidDrainCutoff();
    error InvalidReplacement();
    error LineageSignerAlreadyReserved(address signer);
    error ArithmeticOverflow();

    event LineageSettlementInitialized(address indexed settlement);
    event RouteActivated(
        bytes32 indexed routeId,
        uint64 indexed revision,
        address rootAuthority,
        address pfrAuthority
    );
    event RouteDrainStarted(
        bytes32 indexed routeId,
        uint64 indexed revision,
        uint64 drainingFromRevision,
        uint64 drainStartedAtBlock,
        uint64 consumeUntilBlock
    );
    event RouteRevoked(bytes32 indexed routeId, uint64 indexed revision, address indexed actor);
    event RouteReplaced(
        bytes32 indexed routeId, uint64 indexed revision, bytes32 indexed replacementRouteId
    );
    event LineageAbandoned(address indexed actor);

    bytes32 public immutable lineageId;
    address public immutable governanceAuthority;
    address public immutable incidentAuthority;
    uint64 public immutable maxDrainBlocks;
    address public lineageSettlement;
    bool public lineageAbandoned;

    mapping(bytes32 => Route) internal routes;
    mapping(address => bool) public lineageSignerReserved;
    bytes32 internal lifecycleAccumulator;
    uint64 internal transitions;
    uint64 internal eventsEmitted;

    constructor(
        bytes32 lineageId_,
        address governanceAuthority_,
        address incidentAuthority_,
        uint64 maxDrainBlocks_
    ) {
        if (lineageId_ == bytes32(0)) revert ZeroLineageId();
        if (governanceAuthority_ == address(0) || incidentAuthority_ == address(0)) {
            revert ZeroAuthority();
        }
        if (governanceAuthority_ == incidentAuthority_) revert AuthorityOverlap();
        if (maxDrainBlocks_ == 0) revert InvalidMaxDrainBlocks();
        lineageId = lineageId_;
        governanceAuthority = governanceAuthority_;
        incidentAuthority = incidentAuthority_;
        maxDrainBlocks = maxDrainBlocks_;
    }

    function initializeLineageSettlement(address settlement) external {
        _onlyGovernance();
        _requireLiveLineage();
        if (lineageSettlement != address(0)) revert LineageAlreadyInitialized();
        if (
            settlement == address(0) || settlement.code.length == 0
                || settlement == governanceAuthority || settlement == incidentAuthority
        ) revert InvalidLineageSettlement();
        try IStateSyncGKRSettlementIdentityV2(settlement).lifecycleRegistry() returns (
            address registry
        ) {
            if (registry != address(this)) revert InvalidLineageSettlement();
        } catch {
            revert InvalidLineageSettlement();
        }
        lineageSettlement = settlement;
        _record(keccak256(abi.encode("INITIALIZE", settlement)));
        emit LineageSettlementInitialized(settlement);
    }

    function activateRoute(
        bytes32 routeId_,
        address rootAuthority,
        address pfrAuthority,
        uint64 expectedRevision
    ) external {
        _onlyGovernance();
        _requireLiveLineage();
        if (routeId_ == bytes32(0)) revert ZeroRouteId();
        if (lineageSettlement == address(0)) revert LineageNotInitialized();
        Route storage route_ = routes[routeId_];
        if (route_.revision != expectedRevision) revert RevisionMismatch();
        if (route_.status != RouteStatus.Uninitialized || expectedRevision != 0) {
            revert InvalidTransition();
        }
        (address[] memory rootSigners, address[] memory pfrSigners) =
            _validateRouteEndpoints(routeId_, rootAuthority, pfrAuthority);
        _reserveSigners(rootSigners, pfrSigners);

        route_.rootAuthority = rootAuthority;
        route_.pfrAuthority = pfrAuthority;
        route_.status = RouteStatus.Active;
        route_.revision = 1;
        _record(keccak256(abi.encode("ACTIVATE", routeId_, rootAuthority, pfrAuthority, uint64(1))));
        emit RouteActivated(routeId_, 1, rootAuthority, pfrAuthority);
    }

    function startDrain(bytes32 routeId_, uint64 expectedRevision, uint64 consumeUntilBlock)
        external
    {
        _onlyGovernance();
        _requireLiveLineage();
        Route storage route_ = routes[routeId_];
        if (route_.revision != expectedRevision) revert RevisionMismatch();
        if (route_.status != RouteStatus.Active) revert InvalidTransition();
        if (block.number > type(uint64).max) revert ArithmeticOverflow();
        uint64 currentBlock = uint64(block.number);
        if (
            consumeUntilBlock <= currentBlock
                || uint256(consumeUntilBlock) > block.number + maxDrainBlocks
        ) revert InvalidDrainCutoff();
        uint64 nextRevision = _nextRevision(route_.revision);
        route_.status = RouteStatus.Draining;
        route_.revision = nextRevision;
        route_.drainingFromRevision = expectedRevision;
        route_.drainStartedAtBlock = currentBlock;
        route_.consumeUntilBlock = consumeUntilBlock;
        _record(
            keccak256(
                abi.encode(
                    "DRAIN",
                    routeId_,
                    nextRevision,
                    expectedRevision,
                    currentBlock,
                    consumeUntilBlock
                )
            )
        );
        emit RouteDrainStarted(
            routeId_, nextRevision, expectedRevision, currentBlock, consumeUntilBlock
        );
    }

    function revokeRoute(bytes32 routeId_, uint64 expectedRevision) external {
        if (msg.sender != governanceAuthority && msg.sender != incidentAuthority) {
            revert GovernanceOnly();
        }
        _requireLiveLineage();
        Route storage route_ = routes[routeId_];
        if (route_.revision != expectedRevision) revert RevisionMismatch();
        if (route_.status != RouteStatus.Active && route_.status != RouteStatus.Draining) {
            revert InvalidTransition();
        }
        uint64 nextRevision = _nextRevision(route_.revision);
        route_.status = RouteStatus.Revoked;
        route_.revision = nextRevision;
        _record(keccak256(abi.encode("REVOKE", routeId_, nextRevision, msg.sender)));
        emit RouteRevoked(routeId_, nextRevision, msg.sender);
    }

    function replaceRoute(bytes32 routeId_, uint64 expectedRevision, bytes32 replacementRouteId)
        external
    {
        _onlyGovernance();
        _requireLiveLineage();
        Route storage route_ = routes[routeId_];
        if (route_.revision != expectedRevision) revert RevisionMismatch();
        if (route_.status != RouteStatus.Draining) revert InvalidTransition();
        if (replacementRouteId == bytes32(0) || replacementRouteId == routeId_) {
            revert InvalidReplacement();
        }
        Route storage replacement = routes[replacementRouteId];
        if (
            replacement.status != RouteStatus.Active || replacement.rootAuthority == address(0)
                || replacement.pfrAuthority == address(0)
        ) revert InvalidReplacement();
        uint64 nextRevision = _nextRevision(route_.revision);
        route_.status = RouteStatus.Replaced;
        route_.revision = nextRevision;
        route_.replacementRouteId = replacementRouteId;
        _record(keccak256(abi.encode("REPLACE", routeId_, nextRevision, replacementRouteId)));
        emit RouteReplaced(routeId_, nextRevision, replacementRouteId);
    }

    function abandonLineage() external {
        _onlyIncident();
        if (lineageAbandoned) revert LineageIsAbandoned();
        lineageAbandoned = true;
        _record(keccak256(abi.encode("ABANDON", msg.sender)));
        emit LineageAbandoned(msg.sender);
    }

    function getRoute(bytes32 routeId_) external view returns (Route memory) {
        return routes[routeId_];
    }

    function rootRegistrationAllowed(
        bytes32 routeId_,
        address rootAuthority,
        uint64 lifecycleRevision
    ) external view returns (bool) {
        Route storage route_ = routes[routeId_];
        return !lineageAbandoned && lineageSettlement != address(0)
            && route_.status == RouteStatus.Active && route_.rootAuthority == rootAuthority
            && route_.revision == lifecycleRevision;
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
                "SSGKR_ROUTE_LIFECYCLE_STATE_V2",
                lineageId,
                governanceAuthority,
                incidentAuthority,
                maxDrainBlocks,
                lineageSettlement,
                lineageAbandoned,
                transitions,
                eventsEmitted,
                lifecycleAccumulator
            )
        );
    }

    function _validateRouteEndpoints(bytes32 routeId_, address rootAuthority, address pfrAuthority)
        private
        view
        returns (address[] memory rootSigners, address[] memory pfrSigners)
    {
        if (
            rootAuthority == address(0) || pfrAuthority == address(0)
                || rootAuthority.code.length == 0 || pfrAuthority.code.length == 0
        ) revert InvalidRouteEndpoint();
        if (
            rootAuthority == pfrAuthority || rootAuthority == governanceAuthority
                || rootAuthority == incidentAuthority || pfrAuthority == governanceAuthority
                || pfrAuthority == incidentAuthority
        ) revert AuthorityOverlap();

        IReceiptRootAuthorityV2 root = IReceiptRootAuthorityV2(rootAuthority);
        IPrimaryFinalityAuthorityV2 pfr = IPrimaryFinalityAuthorityV2(pfrAuthority);
        if (
            root.routeId() != routeId_ || pfr.routeId() != routeId_
                || root.lifecycleRegistry() != address(this)
                || pfr.lifecycleRegistry() != address(this)
                || root.destinationSettlement() != lineageSettlement
                || pfr.destinationSettlement() != lineageSettlement || root.signerSetEpoch() != 2
                || pfr.signerSetEpoch() != 2
        ) revert RouteIdentityMismatch();

        uint256 rootCount = root.configuredSignerCount();
        uint256 pfrCount = pfr.configuredSignerCount();
        rootSigners = new address[](rootCount);
        pfrSigners = new address[](pfrCount);
        for (uint256 i; i < rootCount; ++i) {
            address rootSigner = root.configuredSignerAt(i);
            if (lineageSignerReserved[rootSigner]) revert LineageSignerAlreadyReserved(rootSigner);
            if (
                rootSigner == governanceAuthority || rootSigner == incidentAuthority
                    || rootSigner == rootAuthority || rootSigner == pfrAuthority
            ) {
                revert RoleOverlap();
            }
            rootSigners[i] = rootSigner;
            for (uint256 j; j < pfrCount; ++j) {
                if (rootSigner == pfr.configuredSignerAt(j)) revert RoleOverlap();
            }
        }
        for (uint256 i; i < pfrCount; ++i) {
            address pfrSigner = pfr.configuredSignerAt(i);
            if (lineageSignerReserved[pfrSigner]) revert LineageSignerAlreadyReserved(pfrSigner);
            if (
                pfrSigner == governanceAuthority || pfrSigner == incidentAuthority
                    || pfrSigner == rootAuthority || pfrSigner == pfrAuthority
            ) {
                revert RoleOverlap();
            }
            pfrSigners[i] = pfrSigner;
        }
    }

    function _reserveSigners(address[] memory rootSigners, address[] memory pfrSigners) private {
        for (uint256 i; i < rootSigners.length; ++i) {
            lineageSignerReserved[rootSigners[i]] = true;
        }
        for (uint256 i; i < pfrSigners.length; ++i) {
            lineageSignerReserved[pfrSigners[i]] = true;
        }
    }

    function _record(bytes32 transition) private {
        if (transitions == type(uint64).max || eventsEmitted == type(uint64).max) {
            revert ArithmeticOverflow();
        }
        lifecycleAccumulator = keccak256(abi.encode(lifecycleAccumulator, transition));
        unchecked {
            ++transitions;
            ++eventsEmitted;
        }
    }

    function _nextRevision(uint64 revision) private pure returns (uint64) {
        if (revision == type(uint64).max) revert ArithmeticOverflow();
        return revision + 1;
    }

    function _onlyGovernance() private view {
        if (msg.sender != governanceAuthority) revert GovernanceOnly();
    }

    function _onlyIncident() private view {
        if (msg.sender != incidentAuthority) revert IncidentOnly();
    }

    function _requireLiveLineage() private view {
        if (lineageAbandoned) revert LineageIsAbandoned();
    }
}
