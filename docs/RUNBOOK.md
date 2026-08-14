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
