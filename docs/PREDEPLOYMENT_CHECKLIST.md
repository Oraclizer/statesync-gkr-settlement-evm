# Predeployment checklist

This checklist is intentionally open and applies to the private, non-deployed V2
candidate and any future supported release candidate. The historical V1 Base
Sepolia Root/Settlement evidence deployment is outside every activation path and
is permanently EVIDENCE-ONLY / ABANDONED / NON-ACTIVATABLE. Passing this
checklist cannot reactivate it.

- [x] Product vector copied byte-exact with detached SHA-256.
- [x] Independent Solidity recomputation of root, native statement, PFR, claim,
  and settlement identities.
- [x] Root and PFR roles immutable, disjoint, bounded, and separately thresholded.
- [x] Strict nonce, replay/conflict, N=1, destination-self, and atomic replay tests.
- [x] Deterministic tuple-binding fuzz and append-only/conflict-preservation plus
  counter/strict-nonce invariant tests.
- [ ] Independent contract security audit.
- [ ] Production signer principals, thresholds, and custody ceremony approved.
- [ ] Target chain/EVM/compiler compatibility independently confirmed.
- [ ] Constructor arguments, creation bytecode, runtime bytecode, and CREATE2 or
  deployment transaction independently reproduced.
- [ ] Deployment rehearsal, gas ceilings, monitoring, incident response, and
  rollback/non-activation decision approved.
- [ ] Live deployment and bytecode verification explicitly authorized.

No unchecked item may be inferred from a passing local test suite.

## Epoch-2 lifecycle/recovery candidate

- [x] Chain, verifying authority, Registry, stable Settlement, route, epoch,
  lifecycle revision, nonce, predecessor digest, and expiry are EIP-712-bound.
- [x] Route transitions use exact revisions and terminal fail-closed states.
- [x] Drain admits only predrain roots before half-open cutoff and root expiry.
- [x] Route replacement preserves the stable Settlement economic nullifier.
- [x] Wrong-chain and cloned Root/PFR domain negatives, one-time Settlement
  clone replacement rejection, registry/route/epoch/revision/expiry binding,
  nonce reuse/skip, and latent-future predecessor negatives are covered locally.
- [x] Replaced/Revoked/ABANDONED terminal failures and retained historical
  route/root getters are covered locally.
- [x] Exact cross-lineage signature/record replay is rejected by domain,
  Registry, Settlement, and route binding. No global cross-lineage nullifier
  property is claimed.
- [x] A pinned Rust codec independently recomputes the V2 vector.
- [ ] Exact candidate commit receives an independent contract/security review.
- [ ] Independent review confirms unresolved Critical/High findings are zero.
- [ ] Human and custody-system separation behind Root, PFR, governance, and
  incident addresses is independently verified.
- [ ] Network, window/cutoff parameters, bytecode, monitoring, and recovery
  targets receive a separate deployment approval.
- [ ] Key generation, funding, signing, RPC mutation, deployment, transaction,
  activation, merge, release, and visibility receive separate exact approvals.
