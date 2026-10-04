// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

interface IPrimaryFinalityAuthorityV2 {
    struct Authorization {
        bytes32 primaryFinalityRecordId;
        bytes32 routeId;
        address lifecycleRegistry;
        address destinationSettlement;
        uint64 signerSetEpoch;
        uint64 lifecycleRevision;
        uint64 validAfterBlock;
        uint64 validUntilBlock;
        uint64 authorizationNonce;
        bytes32 previousAuthorizationDigest;
    }

    function consumeAuthorization(Authorization calldata authorization, bytes[] calldata signatures)
        external
        returns (bytes32 authorizationDigest);
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
