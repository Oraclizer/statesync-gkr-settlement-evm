# Contributing

Thank you for helping improve StateSync-GKR Settlement EVM. A historical V1 Base
Sepolia Root/Settlement evidence deployment exists, but it is unsupported and
permanently EVIDENCE-ONLY / ABANDONED / NON-ACTIVATABLE. No supported or
activatable deployment or address exists. V2 remains an unaudited,
non-deployed local candidate with a frozen test vector; it is not a release or
production system.

## Before opening a change

- Use a GitHub issue first for substantial behavior, storage, authorization,
  cryptographic, dependency, or interface changes.
- Keep one logical change in one focused Pull Request.
- Report suspected vulnerabilities privately according to [`SECURITY.md`](SECURITY.md),
  not in an issue or Pull Request.
- Do not submit credentials, private keys, wallet material, private RPC URLs,
  internal paths, confidential code, or material you do not have the right to
  contribute.

There is no obligation for maintainers to accept a proposal or respond within a
particular time.

## Development environment

Required pins:

- Foundry `1.7.1`, commit
  `4072e48705af9d93e3c0f6e29e93b5e9a40caed8`;
- Solidity `0.8.36+commit.8a079791`;
- EVM target `cancun`.

`foundry.toml` runs offline with compiler auto-detection disabled, so fetch and
verify the exact compiler once (this mirrors the CI step):

```sh
curl --fail --location --proto '=https' --tlsv1.2 \
  --output solc-0.8.36 \
  'https://binaries.soliditylang.org/linux-amd64/solc-linux-amd64-v0.8.36+commit.8a079791'
printf 'c8d35afdddc3cd2743ee88b8f25e0fecd16e2bdd5f2120f37e52cd9cc45ae0e6  solc-0.8.36\n' | sha256sum --check --strict
chmod 0755 solc-0.8.36
```

On macOS or Windows, use the matching platform build and published checksum
from the official `binaries.soliditylang.org` index, or `svm install 0.8.36`.

Then run the same checks CI runs:

```sh
sha256sum -c vectors/risc0-route-b-destination-policy-v1.json.sha256
sha256sum -c vectors/route-lifecycle-recovery-v1.json.sha256
forge fmt --check
forge build --offline --use ./solc-0.8.36
forge build --offline --use ./solc-0.8.36 --sizes --skip script
forge test --offline --use ./solc-0.8.36 --fuzz-seed 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
```

These checks require no RPC endpoint, fork, FFI, external wallet or signing
service, real signer, key custody, broadcast, or deployment. Foundry uses only
deterministic `vm.sign` calls with public, never-production test fixtures. Do not
add external signing or deployment operations to ordinary Continuous Integration.

## Change requirements

A Pull Request should:

1. explain the behavior and claim boundary it changes;
2. include deterministic positive and negative tests proportional to risk;
3. include fuzz or invariant coverage for state-machine surfaces where useful;
4. show that rejecting paths preserve state and events when atomic failure is
   claimed;
5. update documentation, threat assumptions, and changelog entries together;
6. pin new dependencies and explain their provenance and trust impact; and
7. avoid unrelated formatting or generated-output changes.

Contract changes must state storage-layout, upgrade, authorization, replay,
signature, arithmetic, reentrancy, denial-of-service, compiler, and EVM-target
effects as applicable. Tests, fuzzing, invariants, static analysis, formal work,
independent audit, bytecode review, and deployment verification are separate
assurance layers and must not be conflated.

## Commit and review expectations

Use clear commits and a focused branch. Pull Requests must pass required checks
and the review rules in [`GOVERNANCE.md`](GOVERNANCE.md). Maintainers may request
reproduction evidence, narrower scope, additional negative cases, or independent
review before accepting a change.

Meaningful contributions may be recognized through Git history, release notes,
or security advisories, as appropriate to the contribution.

## Contribution license

By submitting a contribution, you represent that you have the right to submit it
and that it contains no third-party confidential or improperly copied material.
You agree that your contribution is licensed under the repository's dual
Apache-2.0 OR MIT terms. No separate Contributor License Agreement or Developer
Certificate of Origin is currently required.

## Signed source identity

The first publication-consolidation commit starts the maintainer signing
policy. Earlier commits retain their original signing status and authorship.
Later maintainer commits are SSH-signed and merged with their signatures
preserved. Maintainer pull requests use merge commits; external contributions
use squash. Rebase merging is disabled. No release tag is claimed by this policy.
