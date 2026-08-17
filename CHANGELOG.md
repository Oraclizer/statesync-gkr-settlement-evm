# Changelog

All notable user-visible changes will be documented in this file.

The project has no release, stable API, supported production deployment, or
formal security audit. Version headings will be added only when an actual
release identity exists.

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
- Added immutable receipt-root quorum and native N=1 destination-consumer
  reference contracts with no administrative or upgrade surface.
- Vendored the exact Product cross-language vector with detached SHA-256 and
  independently recomputed authorization, statement, PFR, claim, and settlement identities.
- Added exact replay/conflict, role separation, destination-self binding,
  arithmetic/gas bounds, negative state/log equality, fuzz, and invariants.
- Added encoding, threat-model, local runbook, predeployment checklist, and
  deterministic evidence artifacts.
- Added a Base Sepolia funding-independent preflight receipt covering external
  encrypted testnet-only role custody, exact direct-CREATE inputs,
  constructor-bound local runtime hashes, root-registration and honest-consume
  rehearsal, public signatures, gas ceilings, and L1 data-fee upper bounds.
  At that preflight checkpoint, funding and every live transaction remained on
  hold; the later live receipt below supersedes that captured state.
- Added a normalized, deterministic local Anvil transcript with exact blocks,
  receipts, event hashes, runtime code hashes, and post-state getters. The
  receipt now distinguishes the Product semantic authority from current Product
  and Brain remote heads and excludes invalid predecessor custody profiles by
  non-secret metadata fingerprints; those profiles supplied no role or signature.
- Added a normalized Base Sepolia live receipt for the finalized funding, two
  direct CREATE transactions, exact root registration, and one honest receipt
  consume. It binds runtime code, immutable getters, events, fees, safe/finalized
  convergence, zero EIP-1967 slots, and native/override negative-call state and
  log invariance. D-50 technical execution is 4-of-4 PASS and its operational
  fail-closed policy is bound, so overall conditions 1–5 of 6 PASS. A11 remains
  on hold until condition 6 makes the exact Product/EVM/Brain evidence audited,
  committed, and remote durable.
- Corrected the encrypted-custody bridge description: redirected stdin supplied
  the UTF-8 BOM, so the successful mode-`0600` temporary password file was 67
  bytes from 64 ASCII input bytes; no explicit BOM, password, or raw key is
  recorded, and final shared-memory residue is zero.
- Permanently classified the deployed testnet addresses as evidence-only,
  abandoned, and non-activatable. A published valid skipped-`nonce=3` root
  quorum is latent at current `nextNonce=2` and lacks destination binding, so no
  future D0/root/PFR signing, registration, consume, or reactivation is allowed
  on epoch `1`. Any later experiment requires nonreused keys, fresh epoch-`2`
  direct addresses, and the full gate repeated.
- Added the private W4/A12 epoch-2 SELECT-A candidate: a lineage-specific direct
  lifecycle registry and stable Settlement, route-specific Root/PFR authorities,
  EIP-712 destination/domain binding, strict nonce hash chains, half-open
  expiries and drain cutoffs, irreversible revocation/replacement/abandonment,
  and stable route-independent economic nullifiers. Added deterministic,
  cross-lineage, fuzz, invariant, and independently recomputed Rust-codec vector
  coverage. This is unaudited local candidate work and includes no key,
  signature, RPC, funding, deployment, transaction, activation, merge, release,
  or public-visibility approval.
- Enforced append-only lineage-wide direct signer-address nonreuse on successful
  route activation, added same-role and cross-role reuse negatives, and clarified
  that fresh-address operator or custody overlap remains externally reviewable.

### Not included

- No formal security audit, release, supported production deployment, approved
  production role, monitoring service, further transaction, or activation is
  included or implied.
