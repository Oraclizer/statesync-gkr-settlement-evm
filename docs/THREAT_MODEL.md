# Threat model

## Owned guarantees

- Root and PFR signer roles are immutable, disjoint, nonzero, sorted, bounded
  to 16, and independently thresholded.
- There is no owner, administrator, pause, rotation, upgrade, delete, or
  overwrite path.
- Root coordinates are append-only. A byte-identical registered authorization
  is a replay; any changed signed tuple at the same coordinate is a conflict.
- New coordinates require the exact next nonce; reused and skipped nonces fail.
- Only native one-leaf receipts (`count=1`, `index=0`, empty path) are accepted.
- The selected native statement binds immutable verifier identity and canonical
  raw192; it is checked against the registered native root.
- Claim and route-independent economic settlement keys are rejected and written
  atomically. All checked counter increments are computed before state writes.
- Successful registration and consumption each emit exactly one event; every
  revert leaves storage and logs unchanged.

## Assumptions and non-claims

The immutable constructor values are test-fixture parameters, not approved
production principals. The contracts assume a correct signer threshold and
honest-enough quorum for each independent role. They do not prove source-chain
finality, signer custody, or off-chain operational correctness.

GRANDPA is neither implemented nor claimed, and it is not a deferred obligation
of this v1. A future finalized-header or light-client adapter is a replaceable,
uncommitted design option that would require its own authority and review.

This repository contains unaudited local source, including a private,
non-deployed V2 candidate. A historical V1 Base Sepolia Root/Settlement evidence
deployment exists, but it is unsupported and permanently EVIDENCE-ONLY /
ABANDONED / NON-ACTIVATABLE. Tests and vectors are not an independent security
audit. No supported or activatable production network, deployment, or address
exists. No V2 production bytecode attestation, key ceremony, monitoring service,
incident process, or production activation exists.

## Explicit failure boundaries

- Signature malleability: high-s, invalid v, invalid/zero recovery, duplicates,
  nonmembers, and below-threshold arrays fail.
- Denial of service: signer and signature arrays have explicit bounds; Merkle
  arrays are rejected unless empty.
- Cross-role substitution: a PFR-domain signature cannot authorize a root, and
  a receipt-root signer cannot satisfy the PFR role.
- Arithmetic: nonce/event/transition overflow is rejected before writes.
- Destination confusion: PFR destination must equal runtime chain ID and the
  consuming contract's own address.
- Reentrancy: no external state-changing call occurs; the root lookup is static,
  and replay state is written only after all authentication checks.
