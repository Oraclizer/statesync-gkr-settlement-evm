# Local validation runbook

The validation commands in the first section are local and non-deploying. They
use no RPC, fork, wallet, real key, broadcast, FFI, or environment secret. The
later live-checkpoint section is evidence-only and does not authorize another
network action.

Required toolchain: Foundry 1.7.1 commit
`4072e48705af9d93e3c0f6e29e93b5e9a40caed8`, Solidity 0.8.36.

```sh
sha256sum -c vectors/risc0-route-b-destination-policy-v1.json.sha256
forge fmt --check
forge config --json
forge build --offline --sizes
forge test --offline --fuzz-seed 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
```

Confirm that `offline=true`, `ffi=false`, the only filesystem permission is
read-only `./vectors`, and no `script/`, broadcast, RPC, fork, or deployment
artifact was introduced. A local test deployment inside the Foundry VM is not a
network deployment.

This runbook does not validate GRANDPA. GRANDPA is not a v1 obligation; any
future finalized-header adapter is replaceable and uncommitted.

## Base Sepolia funding-independent preflight

The receipt at
`../evidence/base-sepolia-destination-enforcement-preflight-2026-08-14.md`
freezes a testnet-only package and successful local chain-ID-84532 rehearsal.
That historical receipt's captured state is
`PREDEPLOYMENT HOLD / FUNDING PENDING / NOT DEPLOYED`; the live-checkpoint
section below supersedes it for exactly four authorized transactions.
The [normalized local block, receipt, log, code-hash, and getter transcript](../evidence/base-sepolia-destination-enforcement-rehearsal-transcript-2026-08-14.json)
is independently replayable;
its frozen SHA-256 is
`a5e09453ffa3bfe38189823dda14f9335de1a451a10559e426c97d59aa321b6f`.

Before any funding or Base transaction, independently verify repository,
Product vector, public-role manifest, constructor-argument, initcode, runtime,
calldata, signature, gas, and L1-fee hashes against the companion JSON. Recheck
D0 nonce `0` at latest, pending, safe, and finalized; D0 balance; and empty code
at both predicted CREATE addresses. Refresh all fee bounds and require the sum
to remain below both the selected funding amount and the absolute `0.01 ETH`
cap.

Also verify the semantic Product authority commit `59f79f5b...`, current
Product remote head `375299a4...`, EVM head `f00aef0f...`, and the Brain A11
semantic checkpoint `9eb74570...` in full against the evidence JSON. Current
Brain `origin/main` is direct child `1d48dde7...`, an automatic-backup commit
not assimilated as an A11 semantic change here. The two invalid predecessor
custody profiles are metadata-only exclusions: their ciphertext is not opened,
they supply no constructor member or signature, and only the v3 public manifest
may supply the frozen public roles.

The transaction sequence that was later separately released and executed was
fixed: D0 nonce `0` root direct CREATE, nonce `1` settlement direct CREATE,
nonce `2` exact root registration, and nonce `3` exact honest W2 receipt
consumption. It used explicit
nonce, gas limit, maximum fee, priority fee, zero value, and only the external
encrypted D0 keystore. Never place a private key, mnemonic, passphrase, password
file, or credential-bearing RPC URL in a command, environment variable,
repository, shell history, transcript, or evidence file.

After each transaction the executed gate required status `1`, the expected
address or single event, exact getters and state digest, and safe/finalized
convergence before the next nonce. Finalized runtime code was compared with the
constructor-bound rehearsal hash. The sequence is complete and must not be
rerun.

## Base Sepolia finalized live checkpoint

The four separately authorized D0 transitions are now finalized. The canonical
receipt is
[`base-sepolia-destination-enforcement-live-2026-08-15.md`](../evidence/base-sepolia-destination-enforcement-live-2026-08-15.md)
with a strict normalized
[`JSON transcript`](../evidence/base-sepolia-destination-enforcement-live-2026-08-15.json).
It supersedes `FUNDING PENDING / NOT DEPLOYED` only for those four transitions.

Do not rerun the preflight send sequence. D0 finalized nonce is `4`; Root is
`0x4EF2d1A2Ea8FC71347801b0E6A4cCF51E6898056` and Settlement is
`0xD5e6befEfE3aD991e3677be744b6D7Fd3F5c02AE`. Before any future read-only
verification, pin block `45485221` and hash
`0x51954822f52e1a3a6af56d2578461695ee7ec14b2f9ad6216546da1badfff9b1`
with EIP-1898 where supported. Compare runtime hashes, immutable getters,
registered record, claim/settlement flags, state digests, event counts, and the
three zero EIP-1967 slots with the normalized JSON.

The negative matrix is read-only: native finalized calls must return the frozen
selectors; call-local state overrides must never be broadcast or treated as
persistent state. For every failure, require unchanged full state digests and
event counters, `debug_traceCall` emitted-log count zero, and contract-storage
diff count zero.

The successful custody bridge wrote only the recovered 64 ASCII characters to
redirected stdin. That redirector emits the implicit UTF-8 BOM, yielding the
expected 67-byte mode-`0600` `/dev/shm` password file. Never prefix an explicit
BOM, print a secret, or reuse a temporary file. This diagnostic description is
not authorization to sign.

The current Root and Settlement are permanently `EVIDENCE-ONLY / ABANDONED /
NON-ACTIVATABLE`. Root `nextNonce` is frozen at `2`. The already-public valid
skipped-`nonce=3` quorum would become submit-ready after any valid nonce-`2`
registration, and its digest lacks destination chain/address binding, making it
replayable against a fresh epoch-`1` clone. Therefore no later approval may
permit another D0/root/PFR signature, registration, consume, funding, or
broadcast on either current address or with the current epoch-`1` roles.

Brain semantic checkpoint `9eb74570...` binds the D-50 fail-closed operational
policy. V1 has no on-chain pause, rotation, revocation, owner, or upgrade
primitive. The immediate response is permanent non-activation, halt of all
D0/root/PFR signing, and abandonment of both addresses. The only possible later
path is a separately approved epoch-`2` fresh direct deployment with nonreused
keys that repeats the full evidence gate. This is operational evidence, not an
on-chain control, reactivation path, or authorization to act.

Current gate state is `TECHNICAL EXECUTION 4 OF 4 PASS / D-50 CONDITIONS 1–5
OF 6 PASS / CONDITION 6 REMOTE DURABILITY OPEN / A11 OVERALL HOLD`. The open
condition is exact evidence audit, commit, and Product/EVM/Brain remote
durability. It is not a code, live-consume, negative-matrix, or operational
policy deficit. Production activation, GRANDPA finality, formal security-audit
status, and further transactions remain unclaimed and unauthorized.
