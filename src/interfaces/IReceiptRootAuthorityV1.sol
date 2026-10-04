// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

interface IReceiptRootAuthorityV1 {
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
        uint64 authorizationNonce;
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
        uint64 authorizationNonce;
        bool exists;
    }

    function register(Authorization calldata authorization, bytes[] calldata signatures)
        external
        returns (bytes32 coordinateId);

    function registeredRoot(bytes32 coordinateId) external view returns (RegisteredRoot memory);
    function registeredAttesters(bytes32 coordinateId) external view returns (address[] memory);
    function isConfiguredSigner(address signer) external view returns (bool);
    function nextAuthorizationNonce() external view returns (uint64);
    function transitionCount() external view returns (uint64);
    function eventCount() external view returns (uint64);
    function stateDigest() external view returns (bytes32);
}
