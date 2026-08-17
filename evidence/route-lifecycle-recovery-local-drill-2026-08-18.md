# Route lifecycle recovery local drill — 2026-08-18

## Evidence identity and subject

This private, local-only checkpoint records validation of implementation commit
`e80ae5daf18b1e72fca39dbaa2076f62d6673a46`, tree
`92a6587990464a186e50bbd15d3cdbf7e017b389`, parent
`2a55440fae65b58ccdc054d7a0742117900ee729`, on
`codex/route-lifecycle-recovery`.

The subsequent commit that carries this evidence file is deliberately outside
the audit subject. Its hash cannot be included without a circular self-hash. The
subject is the implementation commit above, not the later evidence-carrier
commit.

Named roles were separated as follows:

- canonical writer: Russell;
- exact-commit runner: Raman; and
- independent read-only auditor: Kuhn.

Russell, Raman, and Kuhn are Codex sub-agents. They are non-human and not an
external security auditor, audit firm, or third-party custody reviewer. Kuhn's
review is an independent read-only Codex review of the exact implementation
commit and must not be represented as a human or external audit.

## Scope and non-claims

The drill used only deterministic local fixtures. It used no real or newly
generated key, RPC, fork, network access, funding, signature ceremony,
deployment, transaction, activation, merge, release, or public-visibility
change. Fixture signatures use public, never-production test scalars.

This checkpoint does not approve or claim production readiness, deployment,
source finality, a human security audit, independent custody identity, recovery
SLOs, RTO, RPO, elapsed recovery time, or tolerated data loss. Numeric production
validity windows and drain windows remain unapproved deployment policy.

## Pinned toolchain

| Component | Exact identity |
| --- | --- |
| Foundry | `1.7.1`, commit `4072e48705af9d93e3c0f6e29e93b5e9a40caed8` |
| Foundry archive SHA-256 | `6d41121b4bbb809845821c903619cfee75ed364f2bdc58a6787c9b0454114537` |
| Solidity | `0.8.36` |
| Solidity binary SHA-256 | `38cf5df656da822cf88b854cf736475a196c679f4f5f3f15ddd8c85ce5dbb36a` |
| EVM target | `cancun` |
| Execution mode | forced rebuild and tests with `--offline`; FFI disabled |
| Fixed fuzz seed | `0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f` |

## Reproduction and results

The runner checked the following command classes against the exact subject:

```sh
sha256sum -c vectors/risc0-route-b-destination-policy-v1.json.sha256
sha256sum -c vectors/route-lifecycle-recovery-v1.json.sha256
forge fmt --check
forge build --force --offline --sizes
forge test --offline --fuzz-seed 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
forge test --offline --match-path test/RouteLifecycleRecoveryV2.t.sol --fuzz-seed 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
forge test --offline --match-path test/RouteLifecycleRecoveryV2Fuzz.t.sol --fuzz-seed 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
```

Results:

- detached vector custody: `2/2 PASS`;
- formatting: `PASS`;
- forced offline build: `17/17 Solidity source files compiled`, `PASS`;
- full fixed-seed suite: `33/33 PASS`, failures `0`, skipped `0`;
- focused V2 lifecycle drill: `14/14 PASS`;
- V2 fuzz properties: `3 × 1,024 PASS`;
- V2 invariants: `2 × 256 runs × depth 128`, `32,768` calls each,
  handler reverts `0`;
- selected detailed traces: `3/3 PASS`.

The focused V2 lifecycle tests were:

1. `testActiveRouteConsumesAndPreservesV1Identities`
2. `testCrossLineageSettlementAndAuthorizationReplayAreRejected`
3. `testDrainAllowsOnlyPredrainRootAndUsesHalfOpenCutoff`
4. `testEip712RejectsWrongChainAndClonedVerifyingContracts`
5. `testEpochOneAndCrossRoleActivationAreRejected`
6. `testIncidentRevocationAndAbandonmentAreFailClosed`
7. `testLifecycleAuthoritiesAreExact`
8. `testLifecycleCasAuthorityAndTransitionGraph`
9. `testLineageSettlementCannotBeReplacedByClone`
10. `testLineageSignerReuseIsRejectedAndFreshSignersAreReserved`
11. `testPfrNonceReuseSkipAndLatentFuturePredecessorAreRejected`
12. `testRegistrationAndConsumptionWindowsAreHalfOpen`
13. `testReplacementUsesStableSettlementAndRouteIndependentNullifier`
14. `testRootContextNonceHashChainAndValidityAreFailClosed`

The three detailed traces covered
`testLineageSignerReuseIsRejectedAndFreshSignersAreReserved`,
`testRootContextNonceHashChainAndValidityAreFailClosed`, and
`testActiveRouteConsumesAndPreservesV1Identities`. They exposed successful
fresh-signer reservation and same/cross-role reuse rejection, V2
same-coordinate `RootConflict`, and exact `ClaimReplay`, respectively.

## Recovery matrix

| Recovery or failure condition | Exact local result |
| --- | --- |
| Normal rotation | A new route with fresh Root/PFR authorities activates against the same Registry and stable Settlement; successful activation permanently reserves its direct signer addresses. |
| Signer reuse | A previously activated Root signer reused as Root, or a previously activated PFR signer reused as Root or PFR, is rejected. Failed activation preserves Registry `stateDigest` and emits zero logs. |
| Expiry | Root registration, Root consumption, and PFR authorization use half-open validity windows and reject at `validUntilBlock`. |
| Draining and in-flight roots | Registration stops on Draining. Only a root registered at or before the drain-start block under the prior active revision remains consumable. |
| Destination cutoff | Consumption succeeds strictly before the half-open destination `consumeUntilBlock` and fails at the cutoff. Operational use requires a finalized destination observation; the contract clock is destination `block.number`, not source-finality evidence. |
| Stable economic nullifier | Route replacement keeps one Settlement. The same transition/chain/consumer/action produces the same economic settlement key across distinct route claims and the second consumption is rejected. |
| Chain and clone replay | EIP-712 chain ID and verifying-authority separation reject wrong-chain signatures and cloned Root/PFR authority signatures. |
| Cross-lineage replay | Registry, Settlement, authority-domain, and route bindings reject lineage-A authorization and record reuse in lineage B. |
| Nonce and predecessor replay | Root and PFR strict nonce plus previous-digest chains reject reuse, skips, and latent future authorizations with a stale predecessor. |
| Root conflict | A new correctly chained authorization for an already occupied route coordinate is rejected as `RootConflict`, without state or logs. |
| Claim replay | Repeating the exact consumed claim is rejected as `ClaimReplay` before PFR state can advance. |
| Revocation | Governance or incident revocation makes the route terminal and non-consumable while historical getters remain readable. |
| Replacement | Only a Draining route may point to an already Active replacement. Replaced is terminal and cannot reactivate. |
| Lineage abandonment | The incident-only action irreversibly blocks later lifecycle mutations, registration, and consumption without creating a successor or migrating nullifiers. |
| Rejection invariance | Negative Root, Registry, Settlement, and PFR paths retain their pre-call `stateDigest`; recorded logs are `0`. |

The matrix models local state-machine and destination-consumer recovery. It does
not measure wall-clock restoration or data-loss recovery and therefore makes no
RTO or RPO claim.

## V1 and prior-evidence immutability

The diff from parent `2a55440fae65b58ccdc054d7a0742117900ee729` to the
subject changed no V1 source, no existing vector, and no existing evidence blob.
The `evidence/` Git tree remained
`b17749fc9fd942bac40eba3e679bbacdd9559e80` on both commits.

Reference blob OIDs remained:

- `src/ReceiptRootAuthorityV1.sol`:
  `41b844c106e83be8b669c60597b060d555d31a10`;
- `src/StateSyncGKRSettlementV1.sol`:
  `56110906b44fe23ca8e0a6eb8811480fe8fc86a5`;
- `vectors/risc0-route-b-destination-policy-v1.json`:
  `64a1175d358767f5cdc769445fb845f62154c54e`;
- `vectors/route-lifecycle-recovery-v1.json`:
  `74d8e282e9398120f90416ecf2b99757a87764aa`.

The detached SHA-256 values checked were
`29a4528629d471ab9d3efcefec4a494477a93b5866e689fbeb3010b1e7627141`
for the frozen V1 Product vector and
`089bf1681666d5a0150ebea74296f5f392b552a9cfbc19b90875cc88e05a08af`
for the V2 lifecycle vector.

## Independent read-only Codex review

Kuhn reviewed the exact subject commit independently and read-only. Code finding
counts were Critical `0`, High `0`, Medium `0`, and Low `0`; discrepancy was `0`.
This is a Codex sub-agent finding disposition, not a human or external security
audit.

Residual boundaries remain:

- a fresh signer address can conceal the same beneficial owner, operator,
  participant, HSM, cloud account, or custody system, so a human custody review
  is still required before any later activation decision;
- no human or formal external contract security audit has been performed;
- production validity-window and drain-window numbers remain unapproved;
- RTO and RPO remain unapproved, and no elapsed-time or data-loss SLO is claimed;
  and
- deployment, transactions, keys, funding, RPC mutation, merge, release, and
  public visibility remain outside this checkpoint.
