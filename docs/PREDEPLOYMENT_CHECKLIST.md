# Predeployment checklist

This checklist is intentionally open. The current branch is only a local
predeployment candidate.

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
