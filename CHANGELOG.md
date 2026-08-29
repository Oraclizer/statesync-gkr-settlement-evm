# Changelog

All notable user-visible changes will be documented in this file.

The project has no release, stable API, contract, deployed bytecode, or supported
deployment. Version headings will be added only when an actual release identity
exists.

## Unreleased

### Added

- Established the private, pre-deployment repository-production baseline.
- Pinned Foundry `1.7.1` at commit
  `4072e48705af9d93e3c0f6e29e93b5e9a40caed8`, Solidity `0.8.36`, and the
  `cancun` EVM target.
- Added deterministic formatting, build, fuzz, and invariant configuration with
  FFI disabled and no RPC, fork, broadcast, deployment, or wallet workflow.
- Added least-privilege Continuous Integration with immutable action pins,
  community health files, dual Apache-2.0 OR MIT licensing, and explicit
  security, support, governance, contribution, and disclaimer boundaries.

### Scope

- This baseline covers repository policy, toolchain pinning, and Continuous
  Integration. Contracts, cross-language vectors, audits, releases, and
  deployments arrive in later entries as they land.
