# Changelog

User-visible changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
No Settlement release tag, stable API or supported production deployment is
claimed. Git commits identify the source independently of the prover's releases.

## Unreleased

### Added

- Consolidated the existing V1 and V2 contracts, deterministic tests, vectors
  and historical execution evidence into the maintained branch while preserving
  their authored history and source bytes.
- Included the lineage registry, stable Settlement, epoch-2 Root/PFR authorities,
  destination-bound EIP-712 authorization, strict nonce and predecessor chains,
  expiry and draining rules, terminal route states, direct signer-address
  nonreuse and route-independent economic nullifiers.
- Preserved historical V1 Base Sepolia evidence and local Polygon CDK L2 smoke
  results. V1 addresses remain permanently abandoned; V2 is non-deployed.
- Added a repository relationship and compatibility map, citation metadata,
  public contribution guidance and a maintainer signing policy.

### Build and validation

- Foundry 1.7.1 at commit `4072e48705af9d93e3c0f6e29e93b5e9a40caed8`,
  exact solc 0.8.36, Cancun, optimizer 200, via-IR, deterministic fuzz seeds,
  FFI disabled and read-only vector permissions remain unchanged from the
  validated implementation source.
- CI preserves frozen-vector checksum checks, full compilation, production
  size reporting with non-deployed smoke scripts excluded, and deterministic
  tests. Checkout uses the current main's immutable v7 action pin.

### Limits

No new contract behavior, vector, execution experiment or formal proof is added.
Publication does not activate contracts, authorize transactions, establish
production safety, or turn historical fixtures into a v1.1 destination run.
