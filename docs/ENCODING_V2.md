# Epoch-2 route authorization encoding

This document fixes the candidate byte-level authorization surface for the
lineage-specific V2 contracts. It does not authorize key generation, signing,
funding, RPC mutation, deployment, transaction submission, activation,
or production operation.

## EIP-712 domains

Both authorities use standard EIP-712 typed-data framing:

```text
keccak256(0x1901 || domainSeparator || structHash)
```

The domain type is:

```text
EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)
```

Root authorizations use name `StateSyncGKR Receipt Root Authority`, version
`2`, the executing `block.chainid`, and the exact `ReceiptRootAuthorityV2`
address. PFR authorizations use name `StateSyncGKR Primary Finality Authority`,
version `2`, the executing `block.chainid`, and the exact
`PrimaryFinalityAuthorityV2` address. A signature for a clone, another chain,
or the other authority type is invalid.

## Root authorization

The exact type string is:

```text
RootAuthorization(uint64 signerSetEpoch,bytes32 sourceNetworkId,bytes32 sourceGenesisHash,bytes32 sourceRuntimeId,bytes32 verificationContextHash,uint32 domainId,uint64 sourceBlockNumber,bytes32 sourceBlockHash,uint64 aggregationId,bytes32 root,uint32 leafCount,bytes32 routeId,address lifecycleRegistry,address destinationSettlement,uint64 lifecycleRevision,uint64 validAfterBlock,uint64 validUntilBlock,uint64 authorizationNonce,bytes32 previousAuthorizationDigest)
```

`abi.encode(typehash, fields...)` is hashed as the EIP-712 struct hash. Epoch is
exactly `2`. Registry, stable Settlement, route, lifecycle revision, strict
nonce, previous digest, and half-open validity window are signed fields. The
first authorization requires nonce `1` and a zero previous digest. Each later
authorization requires the current `nextAuthorizationNonce` and exact prior
accepted authorization digest. A signature for a skipped future nonce cannot
become valid later unless it also contains the then-unknown exact predecessor.

The window is `[validAfterBlock, validUntilBlock)`. Registration requires
`validAfterBlock <= block.number < validUntilBlock`, and its total width cannot
exceed the authority's immutable maximum. Settlement consumption separately
requires `block.number < validUntilBlock` for the registered root.

The route-specific coordinate is:

```text
keccak256(
  "SSGKR_RECEIPT_ROOT_COORDINATE_V2" ||
  routeId || sourceNetworkId || uint32_be(domainId) || uint64_be(aggregationId)
)
```

## Primary-finality authorization

The exact type string is:

```text
PfrAuthorization(bytes32 primaryFinalityRecordId,bytes32 routeId,address lifecycleRegistry,address destinationSettlement,uint64 signerSetEpoch,uint64 lifecycleRevision,uint64 validAfterBlock,uint64 validUntilBlock,uint64 authorizationNonce,bytes32 previousAuthorizationDigest)
```

The PFR authority uses the same epoch-`2`, strict nonce/hash-chain, and
half-open-window rules. Only its immutable stable Settlement may consume an
authorization. Settlement first checks the current route and registered root,
then calls the pinned route's PFR authority. A revert preserves both contracts'
state atomically.

`primaryFinalityRecordId` is the unchanged V1 PFR identifier produced by
`ReceiptRootEncodingV1.pfrRecordId`. V2 deliberately preserves the V1 raw192
parser, PFR identifier, preclaim, claim, and economic settlement-key formulas.
The economic key contains destination chain and the stable Settlement address,
but not route ID. Consequently, route rotation inside one lineage cannot reset
an already-consumed economic nullifier.

## Independent vector

[`../vectors/route-lifecycle-recovery-v1.json`](../vectors/route-lifecycle-recovery-v1.json)
was recomputed with the pinned Foundry `cast` Rust ABI/Keccak codec and Python's
standard-library SHA-256, not with Solidity contract helpers. The test suite
independently compares those fixed outputs with `ReceiptRootEncodingV2`. Its
detached SHA-256 covers the complete JSON bytes.
