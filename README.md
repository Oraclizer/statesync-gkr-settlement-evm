# StateSync-GKR Settlement EVM

> **Private, pre-deployment, and unaudited.** This branch contains a local
> destination-enforcement reference candidate and a frozen cross-language vector.
> It contains no release, deployed bytecode, approved principals, or deployed address.
> Do not use it in production or treat it as security-reviewed software.

StateSync-GKR Settlement EVM contains a deterministic reference for immutable
receipt-root authorization and native N=1 settlement consumption. It reproduces
the Product vector's encodings and fail-closed state transitions without any
RPC, fork, broadcast, deployment, or real signer.

## Current status

| Area | Status |
| --- | --- |
| Repository policy and Continuous Integration baseline | Present |
| Solidity contracts | Local predeployment candidate |
| Cross-language vectors | Vendored and SHA-256 pinned |
| Independent security audit | Not performed |
| Deployment or supported network | None |
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
- [`docs/ENCODING.md`](docs/ENCODING.md) and [`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md)
  — exact codec and claim boundaries.
- [`vectors/README.md`](vectors/README.md) — frozen Product-vector provenance.
- [`evidence/destination-receipt-enforcement-reference-2026-08-14.md`](evidence/destination-receipt-enforcement-reference-2026-08-14.md)
  — local validation receipt and explicit non-claims.

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

## Security and assurance boundary

Do not report vulnerabilities in a public issue. Follow [`SECURITY.md`](SECURITY.md)
and email `security@oraclizer.io`.

Source review, tests, fuzzing, invariants, cross-language vectors, independent
audits, compiler output review, and deployed-bytecode verification
are distinct assurance layers. Success in one layer does not imply success in
another. The independent audit and every deployment layer remain open.

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
