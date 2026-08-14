# Local validation runbook

This runbook is local and non-deploying. It uses no RPC, fork, wallet, real key,
broadcast, FFI, or environment secret.

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
Its current state is `PREDEPLOYMENT HOLD / FUNDING PENDING / NOT DEPLOYED`.
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
Product remote head `375299a4...`, EVM head `f00aef0f...`, and Brain remote
head `9eb74570...` in full against the evidence JSON. The two invalid predecessor
custody profiles are metadata-only exclusions: their ciphertext is not opened,
they supply no constructor member or signature, and only the v3 public manifest
may supply the frozen public roles.

If separately released from hold, transaction order is fixed: D0 nonce `0`
root direct CREATE, nonce `1` settlement direct CREATE, nonce `2` exact root
registration, and nonce `3` exact honest W2 receipt consumption. Use explicit
nonce, gas limit, maximum fee, priority fee, zero value, and only the external
encrypted D0 keystore. Never place a private key, mnemonic, passphrase, password
file, or credential-bearing RPC URL in a command, environment variable,
repository, shell history, transcript, or evidence file.

After each transaction, require status `1`, the expected address or single
event, exact getters and state digest, and safe/finalized convergence before the
next nonce. Re-read finalized runtime code and compare its Keccak-256 with the
constructor-bound rehearsal hash. An ambiguous submission is never retried
until nonce, transaction hash, and receipt searches prove it was not accepted.
Any mismatch leaves the package on hold.
