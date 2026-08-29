# Destination receipt enforcement reference evidence: 2026-08-14

Status: **LOCAL PREDEPLOYMENT CANDIDATE; UNAUDITED; NOT DEPLOYED**.

## Inputs

- Vendored vector content binding: Git blob `64a1175d358767f5cdc769445fb845f62154c54e`.
- Vendored vector: 28,429 bytes, SHA-256
  `29a4528629d471ab9d3efcefec4a494477a93b5866e689fbeb3010b1e7627141`.
- Toolchain: Foundry 1.7.1 commit
  `4072e48705af9d93e3c0f6e29e93b5e9a40caed8`; Solidity 0.8.36; Cancun;
  optimizer 200; via-IR; offline.

## Deterministic parity

Solidity independently recomputes the exact 260-byte authorization preimage,
digest `7ccc4e3c...535c7d`, coordinate `02642bf9...e94698`, native statement
`b4b058ae...eb8492`, N=1 root `7c609ffc...bc466e`, raw SHA-256
`959550f3...b38721`, preclaim `8efaa827...6c3ad`, PFR ID
`a5a5ed3a...ec5df7`, claim ID `92a3b5b9...4d03d4`, settlement key
`e55506cb...82e93d`, and fixture signer recovery.

All 33 typed Product negative rows are covered by the explicit mapping in the
companion JSON. The listed tests compare the exact custom-error selector and,
for stateful paths, whole-state digest, event counter, and recorded log count
before/after. The vector field-presence test also rejects missing typed
operation/field/value/error entries.

## Validation

- `forge fmt --check`: PASS.
- `forge build --offline --sizes`: PASS; production runtime sizes below EIP-170.
- targeted deterministic unit/vector suite: PASS.
- fuzz: 1,024 cases PASS.
- append-only/conflict-preservation and successful-registration
  counter/strict-nonce invariant: 256 runs × 128 calls, zero handler reverts, PASS.
- full offline suite with frozen seed: 13 tests PASS, 0 failed, 0 skipped.

## Claim ceiling

No RPC, fork, broadcast, network deployment, key custody operation, real signer,
production principal, upgrade, or external mutation was used. This evidence is
not an audit, release, deployed-bytecode proof, or authorization to deploy.
It makes no GRANDPA claim or deferred GRANDPA commitment; a future finality
adapter remains a replaceable, uncommitted option.
