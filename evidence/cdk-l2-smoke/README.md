# Local Polygon CDK L2 smoke evidence

## Verdict and scope

The bounded compatibility smoke is **PASS**. The unchanged EVM candidate at
`de13557322237865632a748d1ae6848b9a1d1d15` was deployed and exercised on an
ephemeral stock Polygon CDK OP-Reth L2. The successful transition used the frozen
Route B statement bytes and produced the same route ID, raw-statement SHA-256,
accepted application root, and single-transition result as the Product reference.

This is an EVM execution compatibility result. It is not a native CDK execution
proof, a Base-parent settlement result, a Base confirmation, a
`SECONDARY_FINALIZED` fact, or a production deployment.

## Frozen inputs

| Input | Exact identity |
|---|---|
| EVM authority base | commit `de13557322237865632a748d1ae6848b9a1d1d15`, tree `a92dc39e0ef5ce4f3aad7ccc3eeae5ca62c3b521` |
| Product reference | commit `85ca530b971b5056aea74f73033ae8d2919a56a3`, tree `02e25ddb3337dd998338f60d715634af3e0f192b` |
| Product reference output | Rust and Python stdout byte-equal, 2,034 bytes, SHA-256 `dc81b33f029446338c101faae0ffb841e854b4ce4f508087a1001175fc56c725` |
| Frozen route ID | `0x27b40b99a41976f061e94124b84cc8c43ee4e5ed6bad2e94267057e1d375f2ef` |
| Frozen raw statement SHA-256 | `0x959550f3847e15ae2d69ab027d8ef59621282eeb758746262205fa3f61b38721` |
| Expected next application state | `0x88957f2aa94f0f483d11f6bbc00b37db9fedd7911eee56e15c1661e148453200` |

The Product branch and PR #11 were not changed. The EVM `src/`, `test/`, and
`vectors/` paths have no delta from the frozen base. All new smoke implementation
code is under `script/`, all generated results are under this evidence directory,
and one CI control change keeps the full compile separate from deployment-size
reporting.

## Stock CDK carrier

The latest stable official carrier on 2026-08-19 was
[`kurtosis-cdk v0.5.21`](https://github.com/0xPolygon/kurtosis-cdk/releases/tag/v0.5.21),
full commit `54e715eafb727bfcc953ee07befd5115964e6115`, tree
`1df9b8c9bb1ceda7b4b229053898ffb4936449a0`.

The byte-exact upstream configuration is
`.github/tests/op-reth/sovereign-ecdsa-multisig.yml`, Git blob
`ba9f23e650095ec64fe6cac17fce9823bf4b4dc1`, SHA-256
`3b4ae959184fb50a2f1caebccf24eb5f638af0bce37013c47040070eeec13d12`.
It selects OP-Reth, sovereign ECDSA multisig consensus, a local Ethereum-like L1,
and no OP Succinct deployment. The package still starts local Agglayer plumbing
with mock proving defaults. No native proof claim is made.

The local chain IDs were `271828` for L1 and `2151908` for L2. All service image
tags, image IDs, and resolved RepoDigests are recorded in
`raw/enclave-container-images-before-teardown.tsv`. Core execution coordinates
included:

| Component | Tag | Resolved RepoDigest |
|---|---|---|
| L1 Reth | `ghcr.io/paradigmxyz/reth:v2.4.1` | `sha256:0d16db7cfaa9e2aa8dc87664f94fd87d9a34f1a79d7eeded1c4867f91f9c13d4` |
| L1 Lighthouse | `sigp/lighthouse:v8.2.1` | `sha256:9538f53d8e11766e3cb5de1889b292074f8e518e0dabe6df13d9054d504d1d62` |
| L2 OP-Reth | `us-docker.pkg.dev/oplabs-tools-artifacts/images/op-reth:v2.4.0` | `sha256:4bc077fc2068b537ec0bffb86fca027b30cac9a0b02dbfdece2363f1c1bbc861` |
| OP Node | `us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:v1.19.3` | `sha256:2254e2a715cff6a937dbbfe1b44b8dc23c464f8b0cac60e4013b30a202fcb72e` |
| OP Batcher | `us-docker.pkg.dev/oplabs-tools-artifacts/images/op-batcher:v1.16.11` | `sha256:af95492b091d0d7759074d8866a0c0daa5227cfdcc1520efc5e3d3ec9934af48` |
| OP Deployer | `europe-west2-docker.pkg.dev/prj-polygonlabs-devtools-dev/public/op-deployer:v0.7.1-cdk` | `sha256:93f6d4a98bba4ceb665947fc3da52e55da1377d5817a1c9941f4dc0d98cca929` |

## Successful execution

The repaired carrier sent six local L2 transactions. Five were exact contract
creations and the sixth was one coordinator transaction that initialized the
lineage, activated the route, registered the receipt root, ran the negative
probes, consumed the valid transition, rejected replay, and emitted the Product
comparison result.

| Contract | Address | Creation Keccak-256 | Runtime Keccak-256 |
|---|---|---|---|
| `NegativeProbe` | `0xb49fa7dd4d70f773015a9c848a8719fa86d81275` | `0x0febf89ed523ae4e2b9688b79369adb32a4b075c5321c3af452c9a9f2840e61f` | `0xeaffb75cd1ea573b63f9e07522731d9a5563537667ba2562ed673d52426c6ed8` |
| `RouteLifecycleRegistryV2` | `0x62bf798edae1b7fde524276864757cc424a5c3dd` | `0xd43f469e239fdf55f1cdc9d983710870b0b3b60cbe5609701b7fdfb28737e1ef` | `0x8d9cf7a1b717bb174d47c89ffb01addae255735ebbaf722596e21c43493dbdb0` |
| `StateSyncGKRSettlementV2` | `0x35b83d5c0fd081da9133c590ac9515d8bf917c03` | `0x4323e26ec9b97895d3996aaef5d1199e40f5d503704660baf2739e800082d9f3` | `0x314e12af1dc7de7cbf166757404f2db631f80ec02f3e538fea41223532f1ec3c` |
| `ReceiptRootAuthorityV2` | `0x9cea3ee97f9eb1c39f3196060f24b7ed52bb7ca3` | `0xe422849166a5b22e2736a113f1975fd0f63fe9c3735e0b184322269ce4e9c19d` | `0xfbc523d8f4e8a58cf283df38d7b76046ed8826af39933e848a8a1357f6fb08c9` |
| `PrimaryFinalityAuthorityV2` | `0xe293a6b8f558422813499bb5c89b60add8c54636` | `0x9de02fcff62ea07820836d9b1d2013d8bc4977b97c877acf7abd3c806e4d39ab` | `0x99ee3683994e0942ed81cc83759b7a1b0dc2b5221bfae4706d4b628eead5f461` |

The coordinator transaction was
`0xd68505332718fbd5055160dacdf11198a09f819796bf833d84eff45ab5813391`,
status `1`, in L2 block `733`, hash
`0x0773e380b83eaf9574bdebd3cb600339573adf248ee0a16af39b4444a4e3d9d1`.
The sequencer and replica returned identical receipts, block hashes, and runtime
bytes.

`SettlementConsumedV2` recorded accepted root
`0x88957f2aa94f0f483d11f6bbc00b37db9fedd7911eee56e15c1661e148453200`.
The final settlement had `transitionCount=1` and `eventCount=1`.

The three nested negative calls returned the expected selectors and emitted
before/after state digests that were byte-equal:

| Probe | Selector | Result |
|---|---|---|
| Wrong receipt statement | `0x1701ddf4` (`ReceiptRootMismatch`) | Settlement and PFR state unchanged |
| Wrong authorization predecessor | `0xcc094867` (`PreviousAuthorizationDigestMismatch`) | Settlement and PFR state unchanged |
| Exact replay | `0x4899bc72` (`ClaimReplay`) | Settlement and PFR state unchanged |

## Routine repair provenance

Four routine defects were repaired without changing `src/`, `test/`, or `vectors/`:

1. WSL stopped after the initial Kurtosis command exited, which stopped Docker and
   the completed enclave. A temporary WSL keepalive was added and the exact
   existing L1, L2, API, and logging service containers were restarted. Both L2
   RPC nodes then advanced from block `336` to `339` together.
2. The first broadcast spread setup and probes over thirteen transactions. The
   local L2 advanced enough blocks to exhaust the contract's existing 20-block
   authorization window, and valid consume reverted with `RootExpired` selector
   `0x9ba67430`. That partial attempt ended with settlement transition/event counts
   `0/0` and PFR nonce `1`. The harness was repaired by combining setup, negatives,
   valid consume, and replay into one coordinator transaction. The 20-block policy
   and all production contracts remained unchanged.
3. Exact runner found one bare-form public local fixture prover key in the
   sanitized transcript. The sanitizer and independent verifier now cover both
   prefixed and bare credential-shaped key fields. The rebuilt transcript has zero
   credential-shaped values, 21 distinct redacted values, 49 replacements, and
   SHA-256
   `a4f05207ea2e9e4b691e14b1a70b448c92f0cbde543bc78e86a342129c1fb174`.
4. Fresh independent audit reproduced the repository's exact CI build and found
   that `forge build --sizes` applies the EIP-170 deployed-contract limit to the
   smoke script. The script embeds five contract creation bytecodes and is 46,796
   bytes, but it is a Foundry orchestration artifact and is never deployed. CI now
   compiles all contracts, tests, and scripts first, then runs the unchanged size
   gate with Foundry 1.7.1's `--skip script` filter. This excludes only `.s.sol`
   orchestration artifacts from deployment-size reporting; all production
   contracts remain measured, and the exact executed harness remains unchanged.

The failed receipt, transaction, pre-state replay, and final partial state are
preserved under `raw/failed-*` and the failed broadcast carrier is preserved as
`raw/forge-broadcast-run-latest.json`.

## Credential and teardown disposition

Kurtosis printed public local fixture credentials in its stdout. The tracked
transcript is deterministically redacted. Twenty-one distinct values and 49
occurrences were replaced. The unredacted transcript, Foundry sensitive cache,
and duplicate broadcast directories were removed.

The exact enclave `w6-component-smoke-20260819` was destroyed with
`kurtosis enclave rm --force`. Enclave-labelled containers, volumes, and networks
are all zero. Pre-smoke container ID/name and volume-name sets are exact; network
name/driver/scope is exact. Docker's built-in `bridge` network received a new local
ID when the daemon restarted, and that reproducible daemon-local drift is recorded
in `raw/docker-baseline-restoration.json`. Pulled image cache was retained.

## Reproduction boundary

The harness is:

- `.github/workflows/ci.yml`
- `script/CdkL2Smoke.s.sol`
- `script/cdk-l2-smoke/sovereign-ecdsa-multisig-v0.5.21.yml`
- `script/cdk-l2-smoke/run-smoke.sh`
- `script/cdk-l2-smoke/collect-evidence.py`
- `script/cdk-l2-smoke/sanitize-devnet-log.py`
- `script/cdk-l2-smoke/build-manifest.py`
- `script/cdk-l2-smoke/verify-manifest.py`

The full smoke requires Docker, Kurtosis `1.20.0`, Foundry `1.7.1`, solc `0.8.36`,
the pinned package commit, and an explicitly supplied local-only funded fixture
key in `CDK_SMOKE_DEPLOYER_PRIVATE_KEY`. The key must not be written into this tree.

The content-addressed runner command after evidence generation is:

```bash
python3 script/cdk-l2-smoke/verify-manifest.py evidence/cdk-l2-smoke/manifest.json
```

## Claim ceiling

This package supports only:

`STOCK POLYGON CDK L2 EVM COMPATIBILITY SMOKE PASS`

It does not support any claim of actual Polygon CDK L3 integration, native CDK
proof generation or verification, Base-parent stock support, Base confirmation,
`SECONDARY_FINALIZED`, production readiness, or public deployment.
