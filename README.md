# StateSync-GKR Settlement EVM

> **Private, testnet-deployed, and unaudited.** This branch contains a
> destination-enforcement reference candidate, a frozen cross-language vector,
> and Base Sepolia testnet evidence. It contains no release, production
> activation, approved production principals, or formal security audit. Do not
> use it in production or treat it as security-reviewed software.

StateSync-GKR Settlement EVM contains a deterministic reference for immutable
receipt-root authorization and native N=1 settlement consumption. It reproduces
the Product vector's encodings and fail-closed state transitions. Its local test
suite requires no RPC, fork, broadcast, deployment, or real signer.

## Current status

| Area | Status |
| --- | --- |
| Repository policy and Continuous Integration baseline | Present |
| V1 Solidity contracts | Direct Base Sepolia evidence instances; permanently abandoned and non-activatable |
| V2 Solidity candidate | Local and non-deployed; private implementation/validation checkpoint only |
| Cross-language vectors | Vendored and SHA-256 pinned |
| Base Sepolia package | Four authorized transactions finalized; technical execution 4-of-4 passed |
| W3 / A11 | Closed; validation bundle 4 of 9 closed |
| Gate L Director decision | Option B approved W4 design, implementation, validation, and private checkpoint only |
| W4 implementation architecture | SELECT A: lineage Registry plus stable Settlement and route-specific authorities |
| Current addresses | Evidence-only; no future signing, registration, consume, or reactivation |
| Independent security audit | Not performed; deployment/activation blocked until unresolved Critical/High is zero |
| Production deployment or supported network | None |
| Release or stable API | None |

Passing Continuous Integration means only that deterministic local checks pass
under the pinned toolchain. It is not an independent audit, deployment proof, or
production-readiness finding.

## Quick start

Use Foundry `1.7.1` built from commit
`4072e48705af9d93e3c0f6e29e93b5e9a40caed8`.

```sh
forge --version
sha256sum -c vectors/risc0-route-b-destination-policy-v1.json.sha256
sha256sum -c vectors/route-lifecycle-recovery-v1.json.sha256
forge fmt --check
forge build --offline
forge test --offline --fuzz-seed 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
```

The expected version output contains both:

```text
forge Version: 1.7.1
Commit SHA: 4072e48705af9d93e3c0f6e29e93b5e9a40caed8
```

These commands do not require an RPC endpoint, fork, external wallet, real
signer, key custody, broadcast, or deployment. Foundry tests use only fixed,
public, never-production fixture scalars to generate deterministic signatures.
The repository does not provide scripts for external signing or deployment.

## Pinned build profile

| Setting | Value |
| --- | --- |
| Foundry | `1.7.1` / `4072e48705af9d93e3c0f6e29e93b5e9a40caed8` |
| Solidity | `0.8.36` with auto-detection disabled |
| EVM target | `cancun` |
| Optimizer | enabled, 200 runs |
| Compiler pipeline | via-IR enabled |
| Fuzzing | 1,024 runs with the checked-in 32-byte seed |
| Invariants | 256 runs, depth 128, same deterministic test-runner seed |
| FFI | disabled |
| Filesystem | read-only `./vectors` only |
| Compiler metadata hash | disabled for deterministic bytecode inputs |

`cancun` is selected instead of a newer default so future artifacts do not
silently depend on Prague or Osaka opcodes before a destination network profile
is explicitly reviewed. A later target change must be treated as a compatibility
and bytecode-identity change.

Foundry 1.7.1 exposes the deterministic runner seed through `fuzz.seed` and the
`--fuzz-seed` flag. The invariant run count and depth are separately pinned in
`foundry.toml`; Continuous Integration supplies the same runner seed explicitly.

## Repository map

- [`src/ReceiptRootAuthorityV1.sol`](src/ReceiptRootAuthorityV1.sol) — immutable
  root quorum and append-only coordinate registry.
- [`src/StateSyncGKRSettlementV1.sol`](src/StateSyncGKRSettlementV1.sol) — native
  one-leaf consumer and atomic claim/economic replay enforcement.
- [`src/RouteLifecycleRegistryV2.sol`](src/RouteLifecycleRegistryV2.sol) and
  [`src/StateSyncGKRSettlementV2.sol`](src/StateSyncGKRSettlementV2.sol) — the
  private SELECT-A lineage lifecycle and stable-nullifier candidate.
- [`src/ReceiptRootAuthorityV2.sol`](src/ReceiptRootAuthorityV2.sol) and
  [`src/PrimaryFinalityAuthorityV2.sol`](src/PrimaryFinalityAuthorityV2.sol) —
  route-bound epoch-2 EIP-712 nonce/hash-chain authorities.
- [`docs/ENCODING.md`](docs/ENCODING.md) and [`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md)
  — exact codec and claim boundaries.
- [`docs/ENCODING_V2.md`](docs/ENCODING_V2.md),
  [`docs/THREAT_MODEL_V2.md`](docs/THREAT_MODEL_V2.md), and the
  [route lifecycle runbook](docs/operations/route-lifecycle-recovery-v1.md) —
  V2 candidate encoding, residual risks, and fail-closed operations.
- [`vectors/README.md`](vectors/README.md) — frozen Product-vector provenance.
- [`evidence/destination-receipt-enforcement-reference-2026-08-14.md`](evidence/destination-receipt-enforcement-reference-2026-08-14.md)
  — local validation receipt and explicit non-claims.
- [`evidence/base-sepolia-destination-enforcement-preflight-2026-08-14.md`](evidence/base-sepolia-destination-enforcement-preflight-2026-08-14.md)
  — testnet-only public-role, direct-CREATE rehearsal, gas, and funding-hold receipt.

- [`evidence/base-sepolia-destination-enforcement-rehearsal-transcript-2026-08-14.json`](evidence/base-sepolia-destination-enforcement-rehearsal-transcript-2026-08-14.json)
  is the normalized local-only block, receipt, event, code-hash, and getter transcript.
- [`evidence/base-sepolia-destination-enforcement-live-2026-08-15.md`](evidence/base-sepolia-destination-enforcement-live-2026-08-15.md)
  and its [normalized JSON](evidence/base-sepolia-destination-enforcement-live-2026-08-15.json)
  freeze the finalized Base Sepolia transactions, deployed code, getters,
  events, fees, topology, and negative-call invariance.

- [`foundry.toml`](foundry.toml) — compiler, EVM, optimizer, fuzz, invariant,
  formatting, and sandbox settings.
- [`.github/workflows/ci.yml`](.github/workflows/ci.yml) — least-privilege,
  immutable-action Continuous Integration.
- [`SECURITY.md`](SECURITY.md) — private vulnerability reporting and current
  support boundary.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — contribution and validation rules.
- [`GOVERNANCE.md`](GOVERNANCE.md) — review, merge, release, and authority rules.
- [`SUPPORT.md`](SUPPORT.md) — support scope and routing.
- [`DISCLAIMER.md`](DISCLAIMER.md) — plain-language non-claims.
- [`CHANGELOG.md`](CHANGELOG.md) — user-relevant repository changes.

The root and PFR roles are immutable and disjoint. The root registry is
append-only; the consumer binds the selected native Route-B statement to raw192,
then consumes delivery claim and economic settlement identities atomically.

The live receipt supersedes the preflight funding/deployment hold for exactly
four authorized D0 transactions. The direct Root and Settlement contracts are
deployed on Base Sepolia and one honest receipt is consumed. The later exact
Product/EVM/Brain evidence audit and remote-durability checkpoint closed
W3/A11. No further transaction or production activation is authorized. The two
current addresses and epoch-`1` roles are
permanently abandoned and non-activatable; later approval cannot reactivate
them.

This permanent boundary is required because the published valid root quorum for
the skipped `nonce=3` mutation is latent while Root `nextNonce=2`: any accepted
nonce-`2` registration would make it submit-ready, and the digest does not bind
a destination chain or contract address. No future D0/root/PFR signing,
registration, or consume may occur on these addresses. The only possible later
path is separately approved epoch-`2` fresh direct addresses with nonreused
keys and the full evidence gate repeated from zero. The Gate L Director decision
approved option B only for W4 design, implementation, validation, and a private
checkpoint. The later W4 implementation architecture selected SELECT A: a
lineage-specific direct Registry and stable Settlement, route-specific rotating
Root/PFR authorities, append-only lineage-wide direct signer-address nonreuse,
no nullifier migration, and irreversible lineage abandonment if Settlement
integrity fails. Fresh addresses do not prove independent operators or custody;
that residual requires separate review. The checked-in V2 code is an
unaudited private candidate only; it does not authorize or perform keys,
signatures, RPC mutation, funding, deployment, transactions, activation, merge,
release, or publication.

The closed W3 evidence pins Product
`03530f3062c28048c11afe96c37a39ca9b8019b8`, EVM
`3746a81eb9114725376d9e6d883c6995f8c1a671`, and Brain
`7b0098d63082c7367486d4cad317d451eca4a9bf`. Invalid predecessor custody
profiles remain excluded by non-secret metadata fingerprints and supply no
signer, constructor member, or signature.

## Security and assurance boundary

Do not report vulnerabilities in a public issue. Follow [`SECURITY.md`](SECURITY.md)
and email `security@oraclizer.io`.

Source review, tests, fuzzing, invariants, cross-language vectors, independent
evidence review, formal security audits, compiler output review, and
deployed-bytecode verification
are distinct assurance layers. Success in one layer does not imply success in
another. No formal independent security audit or production-readiness finding
is claimed.

## Contributing, governance, and support

Read [`CONTRIBUTING.md`](CONTRIBUTING.md) before proposing a change. Project
decisions and merge authority are described in [`GOVERNANCE.md`](GOVERNANCE.md).
General support boundaries are in [`SUPPORT.md`](SUPPORT.md), and all
participation is governed by [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## License

Licensed under either the Apache License, Version 2.0 or the MIT License, at your
option. See [`LICENSE-APACHE`](LICENSE-APACHE) and [`LICENSE-MIT`](LICENSE-MIT).

This README and [`DISCLAIMER.md`](DISCLAIMER.md) summarize important boundaries;
the license files control the warranty and liability terms.
