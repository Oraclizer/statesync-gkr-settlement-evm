// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

import {IReceiptRootAuthorityV2} from "../interfaces/IReceiptRootAuthorityV2.sol";
import {IPrimaryFinalityAuthorityV2} from "../interfaces/IPrimaryFinalityAuthorityV2.sol";

library ReceiptRootEncodingV2 {
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 internal constant VERSION_HASH = keccak256("2");
    bytes32 internal constant ROOT_NAME_HASH = keccak256("StateSyncGKR Receipt Root Authority");
    bytes32 internal constant PFR_NAME_HASH = keccak256("StateSyncGKR Primary Finality Authority");
    bytes32 internal constant ROOT_AUTHORIZATION_TYPEHASH = keccak256(
        "RootAuthorization(uint64 signerSetEpoch,bytes32 sourceNetworkId,bytes32 sourceGenesisHash,bytes32 sourceRuntimeId,bytes32 verificationContextHash,uint32 domainId,uint64 sourceBlockNumber,bytes32 sourceBlockHash,uint64 aggregationId,bytes32 root,uint32 leafCount,bytes32 routeId,address lifecycleRegistry,address destinationSettlement,uint64 lifecycleRevision,uint64 validAfterBlock,uint64 validUntilBlock,uint64 authorizationNonce,bytes32 previousAuthorizationDigest)"
    );
    bytes32 internal constant PFR_AUTHORIZATION_TYPEHASH = keccak256(
        "PfrAuthorization(bytes32 primaryFinalityRecordId,bytes32 routeId,address lifecycleRegistry,address destinationSettlement,uint64 signerSetEpoch,uint64 lifecycleRevision,uint64 validAfterBlock,uint64 validUntilBlock,uint64 authorizationNonce,bytes32 previousAuthorizationDigest)"
    );
    bytes internal constant COORDINATE_DOMAIN = "SSGKR_RECEIPT_ROOT_COORDINATE_V2";

    function rootAuthorizationDigest(
        IReceiptRootAuthorityV2.Authorization memory authorization,
        uint256 chainId,
        address verifyingContract
    ) internal pure returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                ROOT_AUTHORIZATION_TYPEHASH,
                authorization.signerSetEpoch,
                authorization.sourceNetworkId,
                authorization.sourceGenesisHash,
                authorization.sourceRuntimeId,
                authorization.verificationContextHash,
                authorization.domainId,
                authorization.sourceBlockNumber,
                authorization.sourceBlockHash,
                authorization.aggregationId,
                authorization.root,
                authorization.leafCount,
                authorization.routeId,
                authorization.lifecycleRegistry,
                authorization.destinationSettlement,
                authorization.lifecycleRevision,
                authorization.validAfterBlock,
                authorization.validUntilBlock,
                authorization.authorizationNonce,
                authorization.previousAuthorizationDigest
            )
        );
        return _typedDataDigest(ROOT_NAME_HASH, chainId, verifyingContract, structHash);
    }

    function pfrAuthorizationDigest(
        IPrimaryFinalityAuthorityV2.Authorization memory authorization,
        uint256 chainId,
        address verifyingContract
    ) internal pure returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                PFR_AUTHORIZATION_TYPEHASH,
                authorization.primaryFinalityRecordId,
                authorization.routeId,
                authorization.lifecycleRegistry,
                authorization.destinationSettlement,
                authorization.signerSetEpoch,
                authorization.lifecycleRevision,
                authorization.validAfterBlock,
                authorization.validUntilBlock,
                authorization.authorizationNonce,
                authorization.previousAuthorizationDigest
            )
        );
        return _typedDataDigest(PFR_NAME_HASH, chainId, verifyingContract, structHash);
    }

    function coordinateId(
        bytes32 routeId,
        bytes32 sourceNetworkId,
        uint32 domainId,
        uint64 aggregationId
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(COORDINATE_DOMAIN, routeId, sourceNetworkId, domainId, aggregationId)
        );
    }

    function _typedDataDigest(
        bytes32 nameHash,
        uint256 chainId,
        address verifyingContract,
        bytes32 structHash
    ) private pure returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH, nameHash, VERSION_HASH, chainId, verifyingContract)
        );
        return keccak256(abi.encodePacked(hex"1901", domainSeparator, structHash));
    }
}
