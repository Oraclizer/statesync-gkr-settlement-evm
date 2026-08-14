# Base Sepolia destination-enforcement preflight — 2026-08-14

Status: **PREDEPLOYMENT HOLD / FUNDING PENDING / NOT DEPLOYED**.

This receipt freezes a funding-independent rehearsal for Base Sepolia chain ID
`84532`. It is not a deployment receipt, security audit, production-principal
approval, or authorization to reuse these testnet-only identities elsewhere.

## Source and custody boundary

- Repository commit: `f00aef0f9fb3d3430047ec7990a3e9cacfe794f0`.
- Product semantic authority commit:
  `59f79f5b9cd1382c5acb7368c57402f5015798f9`.
- Current Product remote head:
  `375299a46e2aea938f4ac13fd2d0b7c324ca2009`; the semantic vector authority
  remains the earlier commit named above.
- Current Brain remote head:
  `9eb7457027e18fa8ddd153c8064a8bda86965d34`.
- Frozen Product vector: 28,429 bytes; SHA-256
  `29a4528629d471ab9d3efcefec4a494477a93b5866e689fbeb3010b1e7627141`.
- External public-role manifest: 5,958 bytes; SHA-256
  `fb08172276c186dd340eb79ad22d7469b64f387303d0aa282bb3ce657bba041f`.
  Its encrypted keystores and DPAPI material remain outside every repository.
  Only `SYSTEM` and the owning Windows user have explicit full-control ACLs;
  inheritance is disabled.
- Plaintext passphrases and private keys were never printed, logged, committed,
  or placed in a repository. Signing used Windows CurrentUser DPAPI and a
  mode-`0600` `/dev/shm` password file that was removed after every operation;
  final matching temporary-file count was zero.

Two superseded, invalid custody profiles were excluded without opening their
ciphertext. Their metadata fingerprint grammar is UTF-8 with LF, 1-based
ordinal rows, forward-slash relative paths, and exact rows
`ordinal<TAB>relativePath<TAB>size<LF>`. The `invalid-v1` profile contained two
directories and one file (716 aggregate bytes); its metadata fingerprint is
SHA-256
`a2741a78e2ddafc43db3d08ea474b2c3172d6f145879af52b5fe220caeed2c21`.
The `invalid-v2` profile contained two directories and two files (1,152
aggregate bytes); its equivalent metadata fingerprint is SHA-256
`fe6c71d00f2a54eaf9c981a771152b95d5d5117988e80d87a5ad496d6716e913`.
Neither profile had a public manifest, so no address was inferred by reading
secret material. Both profiles contributed zero constructor members and zero
signatures. Only the v3 public manifest and roles below are in the package.

Public roles are:

- deployer `D0`: `0x26245E085100AE21A1A8a55B54a30b41DF64B900`;
- root set, sorted: `0x2CF24739b41CE76476f47a177Eca3cEea79d1e30`,
  `0x3e097e12c9800Ea68c72584eB953E1Af9AAa8dD2`,
  `0x4EaDD8246bdf73244759DD7f022237e50C507536`,
  `0x9d129d6316EcB11270fd173F00962A82020Ffa17`,
  `0xfc33aCE1A0e34EeFab1e0d886c02a2d79Be4fcf0`;
- PFR set, sorted: `0x5c3D78e1102e92f4e1914ce8BFF918828A9D58DE`,
  `0x65816B71b34bFDaf78A174bBbb8dDDc0A176CE0c`,
  `0x81cdBD7726B0cdB14EbDf64b4a9aCc3B8D074f57`.

The root policy is epoch `1`, threshold `3-of-5`, initial authorization nonce
`1`; its deterministic signing subset is the first three sorted root roles.
The PFR policy is independently epoch `1`, threshold `2-of-3`; its signing
subset is the first two sorted PFR roles. All nine addresses are nonzero,
unique, and the two signer roles are disjoint.

## Exact deployment inputs

Direct CREATE from D0 nonce `0` predicts the root address
`0x4EF2d1A2Ea8FC71347801b0E6A4cCF51E6898056`; nonce `1` predicts the
settlement address `0xD5e6befEfE3aD991e3677be744b6D7Fd3F5c02AE`.

The root constructor fixes epoch `1`, the sorted five-address root set,
threshold `3`, source network
`0x63f64f53339e0cfb288c57b0091f4932fa3181361fa87ba1dc583fbc172d836e`,
genesis `0xff7fe5a610f15fe7a0c52f94f86313fb7db7d3786e7f8acf2b66c11d5be7c242`,
runtime `0x7f98ae91ea34aff20365f8f157636ea7b2eccd216212dca424ca4bce2b2b9a8b`,
context `0x676acbc40b7c7b5ba646aee26dd77984104e0674391ebd9f8e70b60d84ca6660`,
and domain `2`. Its ABI-encoded arguments are 448 bytes, SHA-256
`9e874f775f9f18a10230b3ff06682ca9508597469471172a95fd69e9e500f19c`.
The 6,867-byte initcode has SHA-256
`a04316fb42145ebb06218dea61beb45f95c98ed4d73da279fda1aab84864ea42`
and Keccak-256
`0xabceb010a87fac332c46e907860b4d8fcbb24ac4f919c54f886859b7acfc7e55`.

The settlement constructor fixes the predicted root address, independent PFR
epoch `1`, the sorted three-address PFR set, threshold `2`, image ID
`0xdd947fec1fe270c41bc0457912e1e77427c16797ac47dc6a1c825a9323648643`,
and verifier-version hash
`0xaa24368f9ce9025f58596d966209fc3f322c8cac37dae753bb9b0367d273700d`.
Its ABI-encoded arguments are 320 bytes, SHA-256
`f7deed7358f7886fbd8dfb32710dc180c0f3273d146e6dbad5663bdda5743fc1`.
The 8,040-byte initcode has SHA-256
`9096f046cddcde3385b8e5373f134b1e7ce45abf836eeab888b821452bf44c1a`
and Keccak-256
`0x3bb7beb6f94c89babe95ab77e4f497433f1e1c168738ae91b6faa07885824f04`.

## Authorization and settlement identities

The exact root authorization digest is
`0x7ccc4e3c7d7f38c2f37e515e26edf63b9d3cc8b069b463600961c780ea535c7d`.
The three public signatures, in recovered-address order, are:

1. `0x4cb2e57acec4ed6957a99a42b318b47e74383bc97ba7bfe21edd93062eae7ce9775a35e8687034e425347ca3726a5b647a9b3472cba14e3c480b03fa758bfecd1c`
2. `0xb89f65a3afb7b4d4133a56c1f0b56bcf8d8822a4b4ee0cf565fb0bcbb4975f9a4b2f25bdd743d7b1bc807463c22e4ad917483b14c2ceaea0703b436bf8eb7edb1c`
3. `0x3383402db1bc80c770d5c74ee6a468e70800b1112144c1e3782958ea0c015c795d3f67e241bf4cb6194f481c7203cb987d25d0aab5e4b6ef9548074a1bb5a9111c`

The actual-consumer PFR recomputation gives PFR ID
`0x00dc0504fcd956008deed8f46067ead0e7008f40f4dfbf711e016e0aa88f3904`,
claim ID `0xdd781e4b503738241e852484fe1db0af245c61fbb57a9ee4c1c11bd649cd3395`,
and settlement key
`0x8b95044346966f4f9123d718deee56cc78bcf539e35a5eb4ee7460455fbcddf9`.
The two PFR signatures, in recovered-address order, are:

1. `0x5fd02608223b5e3b3b939ab4c8ad2e82e4a7af7a02824f6683be1f34a863c86a4cfc93fa410fa907d8d04730a986c5277af717630a8e52ace1ad9163ee553d9f1c`
2. `0x2d0022e71879a531103f806888e84314f5da54b92a52cef0848fdd37524c78d6034017673464178eb7ed780cbabc01350f05c2baa4c3d038ed9a735ba3b5afd91b`

The 932-byte register calldata has SHA-256
`f86b437aa89b9b3333b468218477d10a931a4e3a4bc7485176b917b0df0b1875`
and Keccak-256
`0xddfeeadfa52fa7a98b637827edcbaa06823e529b0e9ff11b125c36c7d8ea7ad7`.
The 1,604-byte consume calldata has SHA-256
`1e6b34057b557ad8d65a5765c8dab5bb252bc799854ab817b9e0b772bd7f1d4d`
and Keccak-256
`0x86128929397db381f8dda1d32d66c1410535bafe8aa305239a95b2a072558b79`.

## Local direct-CREATE rehearsal

An ephemeral Anvil instance used chain ID `84532` and impersonated only the
public D0 address. It was terminated after the four-step rehearsal; no process
or listener remained.

The independently replayable, normalized receipt/block/log/getter transcript is
[`base-sepolia-destination-enforcement-rehearsal-transcript-2026-08-14.json`](base-sepolia-destination-enforcement-rehearsal-transcript-2026-08-14.json)
(10,662 bytes; SHA-256
`a5e09453ffa3bfe38189823dda14f9335de1a451a10559e426c97d59aa321b6f`).
It records an unsigned Anvil impersonation only, never a D0 key signature.

| Nonce | Transition | Local transaction | Gas used | Result |
| ---: | --- | --- | ---: | --- |
| 0 | root direct CREATE | `0xcc205a9ea432461949b6a4974f1edf2dd4db4a606a6b54489e0159a3cc87f450` | 1,530,904 | status 1, predicted address exact |
| 1 | settlement direct CREATE | `0x4e365287d3ca47640850df9ceedca914b148497ecf3ef10d74d7ec654a266bed` | 1,679,458 | status 1, predicted address exact |
| 2 | root registration | `0x9a20afc8b62de4005b18069f16c5c84608b30989dabe27fe22a117e1ea512c30` | 355,181 | status 1, exactly one registration event |
| 3 | honest consume | `0xfea8d18a7ef2fe18078f24b9d9375be9f30297b1c73dc06675bc4ac70af33caa` | 279,871 | status 1, exactly one consume event |

The constructor-bound root runtime is 5,538 bytes, SHA-256
`91c9d765eeca0318e257ebc14431ec29c551686325aee02b60a7a04ea1cafc5f`,
Keccak-256
`0x5892c1b8aeca153e2ed2c0af147f8dfd80e5906b1886a5d581156a3b484c2360`.
The settlement runtime is 6,689 bytes, SHA-256
`61cc9aec11ea7fa532af038c080f4ef0efb8ef9354f3167eb73a5b6cf99d1abe`,
Keccak-256
`0x142573c3c22475fe568e14ca3ded54cbdbd28078af23c6b07bf6fbcc5e5c09cb`.
Post-state root and settlement digests were respectively
`0x1c225049612ac7c2042ae68d0dd129713e9e56e3af68bc4f959418a98824dbef`
and `0x8fed68c3f4aa0e1252779eed59afda66e3b912dcc36b1641ef38c1bb9c27a481`.

## Gas and funding ceiling

Exact 20% ceilings over rehearsal gas are `1,837,085`, `2,015,350`,
`426,218`, and `335,846` gas in nonce order. At safe head `45472269`, the
observed Base Sepolia base fee was 5,000,000 wei and suggested priority fee was
1,000,000 wei; the frozen preflight maximum fee is 11,000,000 wei.

Unsigned EIP-1559 transaction sizes are 6,894, 8,067, 979, and 1,651 bytes.
The Base GasPriceOracle safe-head `getL1FeeUpperBound` results are respectively
367,057,725,853; 429,183,309,165; 53,632,310,639; and 89,208,048,237 wei.
The combined conservative ceiling is 51,698,570,393,894 wei
(`0.000051698570393894 ETH`), below both the recommended future funding amount
of `0.001 ETH` and the authorized absolute funding cap of `0.01 ETH`.
Fees and bounds must be refreshed before funding and again before each D0
transaction signing or broadcast. The already sealed root and PFR quorum
signatures do not depend on transaction fees.

## Live read-only observation and hold

At `2026-08-14T22:13:27.4409945+09:00`, the official public Base Sepolia RPC
reported latest `45472466`, safe `45472269`
(`0xe3fb15070aef3323301ba0df830a7498e31baa4222f599c0685f836b8ca152a0`),
and finalized `45471893`
(`0x61844a2cfcf5e2740c9bd8834247854a8b86d9a7f6410ff9e572da1777c5fc8f`).
D0 nonce was zero at latest, pending, safe, and finalized; its balance was zero.
Both predicted addresses had empty code at latest and safe.

A private-bytecode public-RPC estimate was blocked before transmission and was
not retried. Gas ceilings therefore use exact local successful execution, while
the public RPC received only ordinary head/account/code reads and transaction-size
queries to the canonical GasPriceOracle.

Funding, faucet claim, OAuth authorization, D0 transaction signing, Base
broadcast, deployment, and live state mutation remain zero. Faucet pages were
viewed and a GitHub permission screen was opened, but no authorization or claim
was completed. The next gate requires an
independent byte audit, refreshed nonce/code/fee checks, an exact funding-source
decision, and funding no greater than `0.01 ETH`. Any mismatch stops execution;
an ambiguous submission is resolved by nonce and receipt lookup before any retry.
