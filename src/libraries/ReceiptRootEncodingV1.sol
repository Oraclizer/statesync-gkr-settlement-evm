// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

import {IReceiptRootAuthorityV1} from "../interfaces/IReceiptRootAuthorityV1.sol";

library ReceiptRootEncodingV1 {
    bytes internal constant ROOT_DOMAIN = "SSGKR_RECEIPT_ROOT_QUORUM_V1";
    bytes internal constant COORDINATE_DOMAIN = "SSGKR_RECEIPT_ROOT_COORDINATE_V1";
    bytes internal constant PFR_DOMAIN = "ssgkr/primary-finality-record/v1";
    bytes internal constant PRECLAIM_DOMAIN = "ssgkr/wrap-settlement-preclaim/v1";
    bytes internal constant CLAIM_DOMAIN = "ssgkr/wrap-settlement-claim/v1";
    bytes internal constant SETTLEMENT_DOMAIN = "ssgkr/settlement-key/v1";
    uint256 internal constant BN254_R =
        0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;
    uint32 internal constant KOALA_BEAR_P = 0x7f000001;

    error NonCanonicalStatement();
    error InvalidActionKind();

    struct PrimaryFinalityRecord {
        bytes32 primaryTransitionId;
        bytes32 routeId;
        bytes32 rawStatementSha256;
        bytes32 preclaimHash;
        bytes32 source;
        uint64 destinationChainId;
        bytes32 destinationConsumer;
        uint8 actionKind;
        uint64 checkpoint;
        bytes32 sessionId;
        bytes32 bvcId;
        bytes32 acceptedRoot;
        uint8 state;
        uint64 signerSetEpoch;
        uint64 issuanceHeight;
        bool hasSupersedes;
        bytes32 supersedesRecordId;
    }

    function authorizationPreimage(IReceiptRootAuthorityV1.Authorization memory a)
        internal
        pure
        returns (bytes memory out)
    {
        out = abi.encodePacked(
            ROOT_DOMAIN,
            a.signerSetEpoch,
            a.sourceNetworkId,
            a.sourceGenesisHash,
            a.sourceRuntimeId,
            a.verificationContextHash,
            a.domainId,
            a.sourceBlockNumber,
            a.sourceBlockHash,
            a.aggregationId,
            a.root,
            a.leafCount,
            a.authorizationNonce
        );
        assert(out.length == 260);
    }

    function authorizationDigest(IReceiptRootAuthorityV1.Authorization memory a)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(authorizationPreimage(a));
    }

    function coordinateId(bytes32 sourceNetworkId, uint32 domainId, uint64 aggregationId)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(COORDINATE_DOMAIN, sourceNetworkId, domainId, aggregationId)
        );
    }

    function canonicalStatement(bytes memory raw)
        internal
        pure
        returns (bytes32 rawSha, bytes32 acceptedRoot, uint8 action)
    {
        if (raw.length != 192) revert NonCanonicalStatement();
        for (uint256 i; i < 6; ++i) {
            uint256 value;
            for (uint256 j; j < 32; ++j) {
                value |= uint256(uint8(raw[i * 32 + j])) << (j * 8);
            }
            if (value >= BN254_R) revert NonCanonicalStatement();
        }
        if (uint8(raw[0]) != 1 || uint8(raw[1]) != 0) revert NonCanonicalStatement();
        for (uint256 i = 16; i < 32; ++i) {
            if (raw[i] != 0) revert NonCanonicalStatement();
        }
        for (uint256 i = 136; i < 160; ++i) {
            if (raw[i] != 0) revert NonCanonicalStatement();
        }
        uint256[4] memory packed = [uint256(1), uint256(2), uint256(3), uint256(5)];
        for (uint256 k; k < packed.length; ++k) {
            uint256 value;
            uint256 off = packed[k] * 32;
            for (uint256 j; j < 32; ++j) {
                value |= uint256(uint8(raw[off + j])) << (j * 8);
            }
            if ((value >> 248) != 0) revert NonCanonicalStatement();
            for (uint256 limb; limb < 8; ++limb) {
                uint256 digit = (value >> (31 * limb)) & 0x7fffffff;
                if (digit >= KOALA_BEAR_P) revert NonCanonicalStatement();
            }
        }
        action = uint8(raw[11]);
        if (action > 2) revert InvalidActionKind();
        assembly ("memory-safe") { acceptedRoot := mload(add(raw, 128)) }
        rawSha = sha256(raw);
    }

    function preclaimHash(bytes32 routeId, bytes memory raw) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(PRECLAIM_DOMAIN, routeId, raw));
    }

    function pfrRecordId(PrimaryFinalityRecord memory r) internal pure returns (bytes32) {
        bytes memory suffix = r.hasSupersedes
            ? abi.encodePacked(uint8(1), r.supersedesRecordId)
            : abi.encodePacked(uint8(0));
        return sha256(
            abi.encodePacked(
                PFR_DOMAIN,
                r.primaryTransitionId,
                r.routeId,
                r.rawStatementSha256,
                r.preclaimHash,
                r.source,
                le64(r.destinationChainId),
                r.destinationConsumer,
                r.actionKind,
                le64(r.checkpoint),
                r.sessionId,
                r.bvcId,
                r.acceptedRoot,
                r.state,
                le64(r.signerSetEpoch),
                le64(r.issuanceHeight),
                suffix
            )
        );
    }

    function claimId(bytes32 routeId, bytes32 pfrId, bytes memory raw)
        internal
        pure
        returns (bytes32)
    {
        return sha256(abi.encodePacked(CLAIM_DOMAIN, routeId, pfrId, raw));
    }

    function settlementKey(bytes32 transitionId, uint64 chainId, bytes32 consumer, uint8 action)
        internal
        pure
        returns (bytes32)
    {
        return
            sha256(
                abi.encodePacked(SETTLEMENT_DOMAIN, transitionId, le64(chainId), consumer, action)
            );
    }

    function le64(uint64 value) internal pure returns (bytes8 out) {
        uint64 reversed = ((value & 0x00000000000000ff) << 56)
            | ((value & 0x000000000000ff00) << 40) | ((value & 0x0000000000ff0000) << 24)
            | ((value & 0x00000000ff000000) << 8) | ((value & 0x000000ff00000000) >> 8)
            | ((value & 0x0000ff0000000000) >> 24) | ((value & 0x00ff000000000000) >> 40)
            | ((value & 0xff00000000000000) >> 56);
        out = bytes8(reversed);
    }
}
