# StateSync-GKR Settlement EVM

> **Private, pre-deployment, and unaudited.** This repository currently contains
> only a repository-production baseline. It contains no settlement contract,
> frozen cross-language vector, release, deployed bytecode, or deployed address.
> Do not use it in production or treat it as security-reviewed software.

StateSync-GKR Settlement EVM is the future home of a deterministic EVM reference
for destination receipt enforcement. The repository is intentionally establishing
its security, contribution, licensing, and reproducibility boundaries before any
contract implementation is added.

## Current status

| Area | Status |
| --- | --- |
| Repository policy and Continuous Integration baseline | Present |
| Solidity contracts | Not present |
| Cross-language vectors | Not present |
| Independent security audit | Not performed |
| Deployment or supported network | None |
| Release or stable API | None |

Passing Continuous Integration at this stage means only that the policy-only
Foundry repository is well formed under the pinned toolchain. It is not evidence
of contract correctness, protocol safety, deployment correctness, or production
readiness.

## Quick start

Use Foundry `1.7.1` built from commit
`4072e48705af9d93e3c0f6e29e93b5e9a40caed8`.

```sh
forge --version
forge fmt --check
forge build --offline
forge test --offline --fuzz-seed 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
```

The expected version output contains both:

```text
forge Version: 1.7.1
Commit SHA: 4072e48705af9d93e3c0f6e29e93b5e9a40caed8
```

These commands do not require an RPC endpoint, fork, wallet, signature,
broadcast, or deployment. The repository does not provide scripts for those
operations.

## Pinned build profile

| Setting | Value |
| --- | --- |
| Foundry | `1.7.1` / `4072e48705af9d93e3c0f6e29e93b5e9a40caed8` |
| Solidity | `0.8.36` with auto-detection disabled |
| EVM target | `cancun` |
| Optimizer | enabled, 200 runs |
| Fuzzing | 1,024 runs with the checked-in 32-byte seed |
| Invariants | 256 runs, depth 128, same deterministic test-runner seed |
| FFI | disabled |
| Compiler metadata hash | disabled for deterministic bytecode inputs |

`cancun` is selected instead of a newer default so future artifacts do not
silently depend on Prague or Osaka opcodes before a destination network profile
is explicitly reviewed. A later target change must be treated as a compatibility
and bytecode-identity change.

Foundry 1.7.1 exposes the deterministic runner seed through `fuzz.seed` and the
`--fuzz-seed` flag. The invariant run count and depth are separately pinned in
`foundry.toml`; Continuous Integration supplies the same runner seed explicitly.

## Repository map

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

There is no architecture diagram yet because there is no contract architecture
in this baseline. A diagram must describe actual state ownership, trust boundaries,
and fail-closed paths when implementation is introduced; it must not anticipate
or imply code that does not exist.

## Security and assurance boundary

Do not report vulnerabilities in a public issue. Follow [`SECURITY.md`](SECURITY.md)
and email `security@oraclizer.io`.

Future source review, tests, fuzzing, invariants, cross-language vectors,
independent audits, compiler output review, and deployed-bytecode verification
are distinct assurance layers. Success in one layer does not imply success in
another. No such implementation assurance is claimed by this baseline.

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
