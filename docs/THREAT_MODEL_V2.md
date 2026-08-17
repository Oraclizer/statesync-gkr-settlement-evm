# Epoch-2 route lifecycle threat model

## Candidate boundary

This is an unaudited, private, non-deployed candidate. Passing local tests does
not establish safety, production readiness, finality, correct custody, or an
independent security finding. Unresolved Critical/High findings must be zero
before any later deployment or activation decision.

The V2 candidate addresses the published epoch-1 skipped-nonce/destination
replay hazard by binding both root and PFR quorums to chain, verifying authority
contract, stable Settlement, registry, route, epoch, lifecycle revision, strict
nonce, predecessor digest, and expiry. Epoch-1 contracts, roles, balances, and
addresses remain permanently evidence-only, abandoned, and non-activatable.

## SELECT A lineage model

Each lineage has a new direct `RouteLifecycleRegistryV2` and a new direct,
stable `StateSyncGKRSettlementV2`. The registry initializes its Settlement once
and can never change it. Route rotation creates a new route with new Root/PFR
authorities and keys while retaining the same Settlement and its economic
nullifiers.

If the Settlement is compromised or cannot be trusted, the lineage is
fail-closed and irreversibly `ABANDONED`. There is no nullifier export, import,
migration, proxy upgrade, automatic successor, or lineage reactivation. A
successor requires a separate design decision and the complete gate sequence
from zero.

Global lineage abandonment is deliberately incident-only. Governance may
revoke an Active or Draining route, but only the distinct immutable
`incidentAuthority` may invoke `abandonLineage`. This is the selected
least-privilege policy: ordinary lifecycle control cannot erase the usability
of every route, while the incident role retains a narrow fail-closed action.

## Security properties tested

- EIP-712 chain and verifying-contract separation for Root and PFR.
- Exact registry, Settlement, route, epoch, lifecycle revision, nonce,
  predecessor digest, and half-open validity binding.
- Strict Root and PFR nonce/hash chains, including skipped, reused, and latent
  future authorization negatives.
- Governance-only activation, drain, and replacement; governance or incident
  revocation; incident-only irreversible lineage abandonment.
- Exact compare-and-swap revisions and terminal route states.
- Predrain-root-only draining with a bounded half-open consume cutoff.
- Stable route-independent economic nullifiers across route replacement.
- Exact lineage-A signatures and records fail against lineage B because the
  authority domain, Registry, stable Settlement, and route bindings differ.
- A cloned Settlement cannot replace the one-time lineage Settlement; old
  routes cannot leave Replaced or Revoked; failures preserve state and logs
  where observable.
- Historical route/root getters remain available after Revoked, Replaced, and
  lineage ABANDONED states.

## Explicit non-properties and residual risks

EIP-712 and the nonce hash chain do not make a malicious quorum honest. A fully
compromised quorum can sign a sequence of future messages on the same chain and
authority, choose harmful roots or PFRs, or coordinate around an operational
cutoff. Expiry only bounds when the EVM accepts a message; `block.number` is a
destination execution clock, not a source-finality proof or wall clock.

The on-chain registry validates direct signer-address separation between Root,
PFR, governance, and incident roles. It cannot see participant overlap hidden
behind multisig, smart-account, HSM, cloud, or organizational control. A later
custody review must verify beneficial and operational separation.

Governance compromise can activate or drain routes and revoke them. Incident
authority compromise can revoke a route or permanently abandon the lineage.
Neither authority can migrate Settlement nullifiers. Root/PFR authority
compromise remains dangerous until revocation or abandonment is confirmed on
the destination chain.

The stable Settlement nullifier is lineage-local, not a global economic
nullifier shared by all possible successors. An independent quorum could issue
a separately valid authorization in a separately designed lineage. The
contracts do not claim to prevent that globally. The no-automatic-successor,
separate-design-decision, and full-gate policy prevents such a lineage from
being treated as automatic continuity or a migrated receipt history.

No GRANDPA or other source-finality adapter is implemented. No monitoring,
custody ceremony, recovery-time evidence, bytecode reproduction, deployment,
or production operator is included.
