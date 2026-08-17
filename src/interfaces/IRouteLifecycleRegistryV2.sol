// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

interface IRouteLifecycleRegistryV2 {
    enum RouteStatus {
        Uninitialized,
        Active,
        Draining,
        Revoked,
        Replaced
    }

    struct Route {
        address rootAuthority;
        address pfrAuthority;
        RouteStatus status;
        uint64 revision;
        uint64 drainingFromRevision;
        uint64 drainStartedAtBlock;
        uint64 consumeUntilBlock;
        bytes32 replacementRouteId;
    }

    function lineageId() external view returns (bytes32);
    function governanceAuthority() external view returns (address);
    function incidentAuthority() external view returns (address);
    function maxDrainBlocks() external view returns (uint64);
    function lineageSettlement() external view returns (address);
    function lineageAbandoned() external view returns (bool);
    function getRoute(bytes32 routeId) external view returns (Route memory);

    function initializeLineageSettlement(address settlement) external;
    function activateRoute(
        bytes32 routeId,
        address rootAuthority,
        address pfrAuthority,
        uint64 expectedRevision
    ) external;
    function startDrain(bytes32 routeId, uint64 expectedRevision, uint64 consumeUntilBlock) external;
    function revokeRoute(bytes32 routeId, uint64 expectedRevision) external;
    function replaceRoute(bytes32 routeId, uint64 expectedRevision, bytes32 replacementRouteId)
        external;
    function abandonLineage() external;

    function rootRegistrationAllowed(
        bytes32 routeId,
        address rootAuthority,
        uint64 lifecycleRevision
    ) external view returns (bool);
}
