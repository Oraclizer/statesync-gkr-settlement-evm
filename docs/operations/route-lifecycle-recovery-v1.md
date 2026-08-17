# Route lifecycle and recovery runbook — candidate v1

This runbook is local-validation-only. All numeric policy values below are
constructor or transition inputs that require a later exact deployment
approval. This document does not authorize keys, funds, signatures, RPC calls,
deployment, transactions, activation, merge, release, or public visibility.

## Direct lineage topology

1. Create one new direct `RouteLifecycleRegistryV2` for a new lineage.
2. Create one new direct `StateSyncGKRSettlementV2` pinned to that registry.
3. Initialize the registry's `lineageSettlement` exactly once.
4. Create route-specific direct Root and PFR authorities with epoch `2`,
   nonreused keys, bounded validity windows, and the stable Settlement address.
5. Activate a route at compare-and-swap revision `0`; its active revision is
   `1`.

These are design steps, not executable deployment instructions. No deployment
script or external signer workflow is present.

## Normal rotation

Create and independently validate a new route with distinct Root/PFR authorities
and signer addresses that have never been activated in the lineage, but the same
lineage Registry and Settlement. The Registry permanently reserves every direct
Root/PFR signer address on successful activation. Activate the new route.
Start draining the old Active route with an exact expected revision and a
half-open `consumeUntilBlock` no more than `maxDrainBlocks` ahead. During drain,
only roots registered at or before `drainStartedAtBlock`, under the old active
revision, and still within root expiry can settle. Registration on the draining
route is forbidden. Replace the old Draining route with the already-Active new
route. Replaced is terminal.

## Incident response

Governance may revoke an Active or Draining route. The distinct incident
authority may also revoke and is the only role that may irreversibly abandon
the whole lineage. This incident-only global abandon is the selected
least-privilege policy; governance cannot invoke it. Abandonment blocks
registration, consumption, and every later lifecycle mutation while retaining
historical getters. It does not create or authorize a successor.

The address guard cannot detect the same operator, beneficial owner, HSM,
multisig participant, cloud account, or custody system behind a fresh address.
Independent custody review must reject that hidden overlap before activation.

If Settlement integrity is in doubt, abandon the lineage. Do not copy, reset,
or migrate economic nullifiers; do not reactivate any route. Record the exact
destination block and state, preserve receipts, and return to a separate design
decision plus the full gate sequence.

## Cutoff and receipt handling

`consumeUntilBlock` and authorization validity are half-open destination-block
windows. Destination `block.number` is a local execution clock, not a statement
of source finality. A drain accepts only a predrain registered root at blocks
strictly before both the drain cutoff and root expiry. Revoked, Replaced, and
Abandoned states accept nothing.

Historical records remain readable for audit. They are not portable
authorizations. An in-flight receipt that misses a cutoff is rejected; it must
not be silently replayed on a new route or lineage. Any reissuance policy
requires separate authorization and a new, correctly bound receipt.

Exact signatures and records from one lineage cannot be replayed in another
because the EIP-712 authority domain, Registry, Settlement, and route bindings
differ. This is not a global nullifier guarantee: an independent quorum in a
separately designed lineage could create a new valid authorization. Such a
lineage is never an automatic successor. It requires a separate design decision
and the complete gate sequence, and it must not inherit receipt continuity by
assumption.

## Local validation

```sh
sha256sum -c vectors/risc0-route-b-destination-policy-v1.json.sha256
sha256sum -c vectors/route-lifecycle-recovery-v1.json.sha256
forge fmt --check
forge build --offline --sizes
forge test --offline --fuzz-seed 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
```

Confirm `offline=true`, `ffi=false`, read-only vector access only, no deployment
script, no broadcast directory, no RPC/fork configuration, and no real key or
signature. Foundry test signatures use public fixture scalars only.

## Audit gate

The independent review must name the reviewer and exact candidate commit, make
evidence reproducible, and cover destination authority, domain/signature
binding, nonce/replay/conflict behavior, lifecycle/recovery, Settlement
nullifier persistence, and custody/operations. Deployment or activation remains
blocked until unresolved Critical/High findings are zero. Medium/Low findings
require an owner, deadline, and explicit Director disposition.
