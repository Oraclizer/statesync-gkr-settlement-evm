// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

interface IReceiptRootAuthorityV2 {
    struct Authorization {
        uint64 signerSetEpoch;
        bytes32 sourceNetworkId;
        bytes32 sourceGenesisHash;
        bytes32 sourceRuntimeId;
        bytes32 verificationContextHash;
        uint32 domainId;
        uint64 sourceBlockNumber;
        bytes32 sourceBlockHash;
        uint64 aggregationId;
        bytes32 root;
        uint32 leafCount;
        bytes32 routeId;
        address lifecycleRegistry;
        address destinationSettlement;
        uint64 lifecycleRevision;
        uint64 validAfterBlock;
        uint64 validUntilBlock;
        uint64 authorizationNonce;
        bytes32 previousAuthorizationDigest;
    }

    struct RegisteredRoot {
        bytes32 authorizationDigest;
        bytes32 attestersHash;
        bytes32 root;
        uint32 leafCount;
        uint64 sourceBlockNumber;
        bytes32 sourceBlockHash;
        bytes32 sourceRuntimeId;
        bytes32 verificationContextHash;
        bytes32 routeId;
        uint64 lifecycleRevision;
        uint64 registeredAtBlock;
        uint64 validAfterBlock;
        uint64 validUntilBlock;
        uint64 authorizationNonce;
        bool exists;
    }

    function register(Authorization calldata authorization, bytes[] calldata signatures)
        external
        returns (bytes32 coordinateId);
    function registeredRoot(bytes32 coordinateId) external view returns (RegisteredRoot memory);
    function registeredAttesters(bytes32 coordinateId) external view returns (address[] memory);
    function authorizationDigest(Authorization calldata authorization)
        external
        view
        returns (bytes32);
    function routeId() external view returns (bytes32);
    function lifecycleRegistry() external view returns (address);
    function destinationSettlement() external view returns (address);
    function signerSetEpoch() external view returns (uint64);
    function threshold() external view returns (uint16);
    function maxValidityWindowBlocks() external view returns (uint64);
    function isConfiguredSigner(address signer) external view returns (bool);
    function configuredSignerCount() external view returns (uint256);
    function configuredSignerAt(uint256 index) external view returns (address);
    function nextAuthorizationNonce() external view returns (uint64);
    function lastAuthorizationDigest() external view returns (bytes32);
    function transitionCount() external view returns (uint64);
    function eventCount() external view returns (uint64);
    function stateDigest() external view returns (bytes32);
}
