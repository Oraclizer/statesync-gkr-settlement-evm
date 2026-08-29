# Destination receipt enforcement v1 encoding

All hashes and byte strings in this document are exact. Solidity ABI encoding is
not used unless a formula says so.

## Receipt-root authorization

The direct-signing preimage is exactly 260 bytes:

```text
"SSGKR_RECEIPT_ROOT_QUORUM_V1"             bytes28
signer_set_epoch                             u64 BE
source_network_id                            bytes32
source_genesis_hash                          bytes32
source_runtime_id                            bytes32
verification_context_hash                    bytes32
domain_id                                    u32 BE
source_block_number                          u64 BE
source_block_hash                            bytes32
aggregation_id                               u64 BE
root                                         bytes32
leaf_count                                   u32 BE
authorization_nonce                          u64 BE
```

The signing digest is `keccak256(preimage)`, with no EIP-191 or EIP-712 prefix.
The coordinate is
`keccak256("SSGKR_RECEIPT_ROOT_COORDINATE_V1" || source_network_id ||
domain_id_u32_be || aggregation_id_u64_be)`.

Signatures are 65-byte `r || s || v`. The contract explicitly requires nonzero
`r` and `s`, low `s`, `v` in `{27,28}`, nonzero recovery, strictly ascending
distinct configured members, and the immutable threshold. The generic EVM-call
registration surface folds recovery failure to address zero and rejects it as
`ZeroAttester`; the strict recovery oracle exposes the more specific signature
shape errors used by the Product vector.

## Selected native Route-B statement

The native statement is not the legacy stock A6 leaf and is not `sha256(raw192)`:

```text
raw_keccak = keccak256(raw192)
statement = keccak256(
    verification_context_keccak256 ||
    image_id ||
    verifier_version_hash ||
    raw_keccak
)
native_n1_root = keccak256(statement)
```

Each component is 32 bytes. The preimage is exactly 128 bytes. The immutable
consumer pins the image ID and verifier-version hash; the registered receipt
pins the context. The frozen fixture recomputes statement
`b4b058ae...eb8492` and root `7c609ffc...bc466e`.

## Raw statement and settlement identities

`raw192` is six canonical little-endian BN254 scalar encodings. Header version
is LE16 `1`; reserved bytes are zero; packed digest scalars use eight masked
31-bit limbs, each below KoalaBear `0x7f000001`, with bits 248..255 zero.
Action is byte 11 and accepted root is bytes 96..127.

The Product identities are recomputed exactly:

```text
preclaim = sha256("ssgkr/wrap-settlement-preclaim/v1" || route_id || raw192)
PFR ID   = sha256(PFR domain || fixed fields)
claim ID = sha256("ssgkr/wrap-settlement-claim/v1" || route_id || PFR ID || raw192)
settlement key = sha256(
    "ssgkr/settlement-key/v1" || primary_transition_id ||
    destination_chain_id_u64_le || destination_consumer || action
)
```

Within the PFR, destination chain ID, checkpoint, signer epoch, and issuance
height are LE64. The consumer derives destination identity from `block.chainid`
and `address(this)`; it never accepts arbitrary constructor destination values.

Source authority: the vendored vector from `Oraclizer/statesync-gkr`,
bound by content as Git blob `64a1175d358767f5cdc769445fb845f62154c54e` with
SHA-256 `29a4528629d471ab9d3efcefec4a494477a93b5866e689fbeb3010b1e7627141`.
