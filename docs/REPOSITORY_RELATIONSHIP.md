# Repository relationship and compatibility

## Ownership

| Repository or actor | Owns | Boundary |
| --- | --- | --- |
| [StateSync-GKR](https://github.com/Oraclizer/statesync-gkr) | Rust proof path, Isabelle models, external proof identity, encodings and recorded public inputs | Model theorems and bounded implementation evidence; no whole-program or Fiat-Shamir security claim |
| This Settlement EVM repository | Solidity Root/PFR authorities, route lifecycle registry and stable Settlement reference | Deterministic local tests and historical execution evidence; unaudited, non-deployed V2 |
| External verifier network | Verification and aggregation of the submitted external proof | Recorded public test-network observations are not production governance or source-finality guarantees |
| Configured Root/PFR quorums | Destination-bound authorization of a root and primary-finality record | Tests use never-production fixture scalars; production operators and custody are not supplied |

The prover does not create a production receipt-root quorum or guarantee a
destination transaction. Settlement publication does not create secondary
finality, deploy a contract, or authorize signing or funding.

## Fixed source and publication identities

- Prover: [v1.1.0 immutable release](https://github.com/Oraclizer/statesync-gkr/releases/tag/v1.1.0),
  [version DOI 10.5281/zenodo.23136385](https://doi.org/10.5281/zenodo.23136385).
- Settlement implementation origin:
  [`5efa0d65e73d07afe9f9a2dbc418e31f6247cbc7`](https://github.com/Oraclizer/statesync-gkr-settlement-evm/tree/5efa0d65e73d07afe9f9a2dbc418e31f6247cbc7).
  Its contracts, tests and vectors are preserved in the maintained branch.
  Pin the actual Settlement Git commit when consuming or citing this source.
- Settlement has no release tag or independent DOI. The prover's version and
  DOI do not identify a Settlement release. The repositories have independent
  release cadences.

## Encoding compatibility with prover v1.1

`vectors/risc0-route-b-destination-policy-v1.json` remains byte-identical to
the prover's protected fixture: 28,429 bytes, SHA-256
`29a4528629d471ab9d3efcefec4a494477a93b5866e689fbeb3010b1e7627141`.
Its raw192 bytes are unchanged in the prover's v1.1 public inputs; the raw
statement SHA-256 is
`959550f3847e15ae2d69ab027d8ef59621282eeb758746262205fa3f61b38721`.

The consumer computes:

```text
statement = keccak256(context || imageId || verifierVersionHash || keccak256(raw192))
one_leaf_root = keccak256(statement)
```

With v1.1 image ID `dc9a5f0da608178bbe56e98604cb895060c555c18329846b453f71d562d16530`
and the recorded context and verifier-version hash, these formulas reproduce
statement `ea414507f2843a858178ece4775ebc99f7502dc5b6554c82c38d77092475ce66`
and receipt root `43820b7d3a614a3df41ce846d149c5955501a208108e8c90e9d9a3dac60fb4b9`.
This is byte and hash-formula compatibility, not a new EVM execution or quorum
authorization result. `StateSyncGKRSettlementV2` fixes image ID and
verifier-version hash in its constructor; a differently configured instance
is a different consumer.

V2 preserves the V1 raw192 parser and PFR/claim/economic-key hash formulas.
Its Root/PFR authorization is separately defined by epoch-2 EIP-712 domains,
registry, stable Settlement, route, lifecycle revision, strict nonce,
predecessor and expiry. Historical V1 authorizations are not V2 authorizations.
See [ENCODING_V2.md](ENCODING_V2.md) and
[StateSyncGKRSettlementV2.sol](../src/StateSyncGKRSettlementV2.sol).

## Execution evidence

Historical Base Sepolia records describe permanently abandoned V1 contracts.
The [local CDK L2 smoke](../evidence/cdk-l2-smoke/README.md) used EVM source
`de13557322237865632a748d1ae6848b9a1d1d15` and earlier prover fixture source
`85ca530b971b5056aea74f73033ae8d2919a56a3`. It established bounded EVM execution
compatibility and rejection behavior for those inputs. No new v1.1 destination
execution was performed for this publication, and no native CDK proof,
CDK L3 deployment, Base-parent settlement or secondary-finality result is claimed.
