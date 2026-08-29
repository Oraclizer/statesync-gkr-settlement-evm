# Route lifecycle recovery local drill: 2026-08-18

## Evidence identity and subject

This private, local-only checkpoint records validation of implementation commit
`e80ae5daf18b1e72fca39dbaa2076f62d6673a46`, tree
`92a6587990464a186e50bbd15d3cdbf7e017b389`, parent
`2a55440fae65b58ccdc054d7a0742117900ee729`, on
`feature/route-lifecycle-recovery`.

Reviewer B reran the exact evidence carrier
`deb56c49accd3eaf68f1cf395d7498a110527e6b`, tree
`a6240b893ce20d46e50d0bbc85043a89dd29ed90`. Its local HEAD and worktree/index
were exact and clean at both start and end. Upstream and the live remote remained
at implementation commit `e80ae5daf18b1e72fca39dbaa2076f62d6673a46`, so the
carrier was one commit ahead and remote equality remained pending the separately
authorized non-force push.

The subsequent commit that carries this repaired document is deliberately
outside the audit subject. Its hash cannot be included without a circular
self-hash. The implementation subject remains `e80ae5d...`; the exact-rerun
carrier remains `deb56c4...`; the later document-carrier commit is neither.

Named roles were separated as follows:

- canonical writer: Reviewer A;
- exact-commit runner: Reviewer B; and
- independent read-only auditor: Reviewer C.

Reviewers A, B, and C are independent automated review passes. They are non-human and not an
external security auditor, audit firm, or third-party custody reviewer. Reviewer C's
review is an independent read-only automated review of the exact implementation
commit and must not be represented as a human or external audit.

## Scope and non-claims

The drill used only deterministic local fixtures. Test, build, vector, and trace
commands used no real or newly generated key, RPC, fork, test-network access,
funding, signature ceremony, deployment, transaction, activation, merge,
release, or public-visibility change. Fixture signatures use public,
never-production test scalars. The runner's only network operation was a
read-only Git live-remote identity query.

This checkpoint does not approve or claim production readiness, deployment,
source finality, a human security audit, independent custody identity, recovery
SLOs, RTO, RPO, elapsed recovery time, or tolerated data loss. Numeric production
validity windows and drain windows remain unapproved deployment policy.

## Pinned toolchain

| Component | Exact identity |
| --- | --- |
| Foundry | `1.7.1`, commit `4072e48705af9d93e3c0f6e29e93b5e9a40caed8` |
| Foundry archive SHA-256 | `6d41121b4bbb809845821c903619cfee75ed364f2bdc58a6787c9b0454114537` |
| Foundry executable SHA-256 | `6df26c16a6e53519abdd09fcdacf9af1ecdb50e216ee1816fa8012b5a553ef48` |
| Solidity | `0.8.36+commit.8a079791.Windows.msvc` |
| Solidity binary SHA-256 | `38cf5df656da822cf88b854cf736475a196c679f4f5f3f15ddd8c85ce5dbb36a` |
| `foundry.toml` SHA-256 | `d9a04d654b7e51e1318a105841af2102a2a83e41b81e41d9b8cd61125aec7ab0` |
| EVM target | `cancun` |
| Execution mode | forced rebuild and tests with `--offline`; FFI disabled |
| Fixed fuzz seed | `0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f` |

## Reproduction and results

The runner used this exact PowerShell recipe from the content-addressed command
record. Every build and test command pins the same verified Solidity binary with
`--use $solc`.

```powershell
$artifactRoot = '<LOCAL_WORKSPACE>'
$forge = '<LOCAL_WORKSPACE>'
$solc = '<LOCAL_WORKSPACE>'
$foundryArchive = '<LOCAL_WORKSPACE>'
$sha256sum = 'C:\Program Files\Git\usr\bin\sha256sum.exe'
$seed = '0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f'

# Each command was wrapped so stdout, stderr, and the native exit code were
# captured in its named log:
& { <COMMAND>; $code=$LASTEXITCODE; Write-Output ('EXIT_CODE=' + $code) } *>&1 |
  Tee-Object -FilePath <LOG>

# identity-status-start.log and identity-status-end.log
git branch --show-current
git rev-parse HEAD
git rev-parse 'HEAD^{tree}'
git rev-parse 'HEAD^'
git rev-parse '@{u}'
git rev-parse origin/feature/route-lifecycle-recovery
git status --short --branch
git diff --quiet -- .
git diff --cached --quiet -- .
git ls-remote --heads origin refs/heads/feature/route-lifecycle-recovery

# toolchain-identity.log
Get-FileHash -Algorithm SHA256 -LiteralPath 'foundry.toml'
Get-FileHash -Algorithm SHA256 -LiteralPath $foundryArchive
Get-FileHash -Algorithm SHA256 -LiteralPath $forge
Get-FileHash -Algorithm SHA256 -LiteralPath $solc
& $forge --version
& $solc --version

# vector1.log and vector2.log
& $sha256sum -c vectors/risc0-route-b-destination-policy-v1.json.sha256
& $sha256sum -c vectors/route-lifecycle-recovery-v1.json.sha256

# fmt.log and forced-build.log
& $forge fmt --check
& $forge build --offline --use $solc --sizes --force

# full.log
& $forge test --offline --use $solc --fuzz-seed $seed --fuzz-runs 1024

# unit.log
& $forge test --offline --use $solc --fuzz-seed $seed --match-contract '^RouteLifecycleRecoveryV2Test$' -vvv

# fuzz-only.log
& $forge test --offline --use $solc --fuzz-seed $seed --fuzz-runs 1024 --match-path 'test/RouteLifecycleRecoveryV2Fuzz.t.sol' --match-test '^testFuzz' -vv

# invariant-only.log
$previousRuns=$env:FOUNDRY_INVARIANT_RUNS
$previousDepth=$env:FOUNDRY_INVARIANT_DEPTH
$env:FOUNDRY_INVARIANT_RUNS='256'
$env:FOUNDRY_INVARIANT_DEPTH='128'
& $forge test --offline --use $solc --fuzz-seed $seed --match-path 'test/RouteLifecycleRecoveryV2Fuzz.t.sol' --match-test '^invariant_' -vv
if ($null -eq $previousRuns) { Remove-Item Env:FOUNDRY_INVARIANT_RUNS -ErrorAction SilentlyContinue } else { $env:FOUNDRY_INVARIANT_RUNS=$previousRuns }
if ($null -eq $previousDepth) { Remove-Item Env:FOUNDRY_INVARIANT_DEPTH -ErrorAction SilentlyContinue } else { $env:FOUNDRY_INVARIANT_DEPTH=$previousDepth }

# trace3.log
& $forge test --offline --use $solc --fuzz-seed $seed --match-path 'test/RouteLifecycleRecoveryV2.t.sol' --match-test 'test(ActiveRouteConsumesAndPreservesV1Identities|RootContextNonceHashChainAndValidityAreFailClosed|LineageSignerReuseIsRejectedAndFreshSignersAreReserved)' -vvvv
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

## Content-addressed runner package

Package root:
`<LOCAL_WORKSPACE>`

- `MANIFEST.sha256` SHA-256:
  `19065de679a4796dcec0d46d730e7b580c68d93ca0e9051c750d887ff48df841`;
- `runner-results.json` SHA-256:
  `278b01e687272f5d12f6141b444063abc8408609bcc0886c29980b89e2f208e2`;
- `commands.txt` SHA-256:
  `37928297ab018299eb1e1e6c0edf88a85a5772f9ae2d2f42ec2b4eb26fd11cb7`.

Every entry in `MANIFEST.sha256` verified `OK`.

| Command ID | Raw log | Exit | Raw-log SHA-256 | Exact result |
| --- | --- | ---: | --- | --- |
| `identity_status_start` | `identity-status-start.log` | 0 | `6739a10a51de6bc65db4a9ae35112514a521f3c9bbf77b5aa57f3e28c5943cf3` | exact carrier; worktree/index clean; upstream/live `e80ae5d...` |
| `toolchain_identity` | `toolchain-identity.log` | 0 | `463722e0ae45d1973b2b5721d5e0aeb8196fe1ce4b2583a12d045aefbd676a41` | pinned Foundry, solc, archive, and `foundry.toml` hashes PASS |
| `vector1` | `vector1.log` | 0 | `12297a9fa5b8aa1e2f176c29867f0f5bdb590a757c4d83266861f91fe6831683` | V1 vector `1/1 PASS` |
| `vector2` | `vector2.log` | 0 | `cb68cd30cf1094dee4a2bee385e158aae9bda636628cabfab30397953673116f` | V2 vector `1/1 PASS` |
| `fmt` | `fmt.log` | 0 | `c1e97067c5f479a44a6f57297a0a8f87a59d181c3c529910f8bf059094bc3abb` | formatting PASS |
| `forced_build` | `forced-build.log` | 0 | `86c91704e25b84b3b860d227dc0a0ab84248a400ecf42680d3bb1ad823a4aeea` | `17/17` Solidity files compiled |
| `full_fixed_seed` | `full.log` | 0 | `b4051e68c0bfdd8fdbc676558a544d56edaf79077e297c0e919fbd26dff5bb52` | `33/33 PASS`; failed/skipped `0/0` |
| `v2_unit` | `unit.log` | 0 | `a80347a73b074ed25aad512f3754703b34b2203221f124140c339a84acf69bbd` | `14/14 PASS`; failed/skipped `0/0` |
| `v2_fuzz_only` | `fuzz-only.log` | 0 | `78ad4ba5aca09b829d3b8509bc2dc3aacb6ba32b0bceb82ce22f66fcfbae10b3` | `3 × 1,024 PASS` |
| `v2_invariant_only` | `invariant-only.log` | 0 | `5cca3cce2ba27df566f6351c0e0a15d87cfe0bdfbdd80dd112ee9baece1f40d2` | `2 × 256 × depth 128`; calls each `32,768`; reverts `0` |
| `detailed_trace3` | `trace3.log` | 0 | `b0b2ac70bbbc5ec84e446aca92177cf9955f1adf83c2522b3ea8ba6c1edd023a` | `3/3 PASS`; `ClaimReplay`, `RootConflict`, `LineageSignerAlreadyReserved` observed |
| `identity_status_end` | `identity-status-end.log` | 0 | `2158f933664b0565536fec6c512b6036b6c0f4e95681789658cf523e5ea73682` | same exact carrier; worktree/index clean; upstream/live unchanged |

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

## Independent read-only automated review

Reviewer C reviewed the exact subject commit independently and read-only. Code finding
counts were Critical `0`, High `0`, Medium `0`, and Low `0`; discrepancy was `0`.
This is an automated reviewer finding disposition, not a human or external security
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
