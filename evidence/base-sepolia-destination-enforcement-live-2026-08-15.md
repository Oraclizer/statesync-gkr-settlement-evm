# Base Sepolia destination-enforcement live receipt — 2026-08-15

Status: **TECHNICAL EXECUTION 4 OF 4 PASS / D-50 CONDITIONS 1–5 OF 6 PASS /
CONDITION 6 REMOTE DURABILITY OPEN / A11 OVERALL HOLD**.

This receipt supersedes the preflight hold only for the four authorized Base
Sepolia transitions. It proves a finalized testnet deployment, one sealed root,
one honest receipt consumption, and bounded negative-call invariance. It is not
a production activation, formal independent security audit, GRANDPA or
trust-minimized-finality claim, or authorization for another transaction.
The deployed addresses are permanently **EVIDENCE-ONLY / ABANDONED /
NON-ACTIVATABLE**.

The semantic Product authority is commit
`59f79f5b9cd1382c5acb7368c57402f5015798f9`; the current Product remote head is
`375299a46e2aea938f4ac13fd2d0b7c324ca2009`. The deployed Solidity is from EVM
implementation remote head `f00aef0f9fb3d3430047ec7990a3e9cacfe794f0`.
The Brain A11 semantic checkpoint is
`9eb7457027e18fa8ddd153c8064a8bda86965d34`. Current Brain `origin/main` is its
direct child `1d48dde7f2c040d516556124f650645c8509e5a7`, an automatic-backup commit
that is preserved as remote ancestry and is not assimilated here as an A11
semantic change. This new receipt itself remains local until an exact evidence
commit receives runner and independent audit and becomes remote-durable.

## Finalized transaction chain

Funding transaction
`0x050d0d9f81655a341c16db3656d41b9e677428d66b27148e9f47df651ae0a491`
credited D0 `0x26245E085100AE21A1A8a55B54a30b41DF64B900` with
`100000000000000` wei in block `45481276`. The four D0 transactions then used
exact nonces `0` through `3`, value zero, a maximum fee of `11000000` wei/gas,
and priority fee `1000000` wei/gas.

| Nonce | Transition | Transaction | Block | Gas used | All-in fee (wei) | Result |
| ---: | --- | --- | ---: | ---: | ---: | --- |
| 0 | root direct CREATE | `0x716a50ea247fe2cb4b7c2ac94be24fc107ae30f13d120905461775fa7a8fbe40` | 45482374 | 1,530,904 | 9,420,115,189,448 | status 1; Root `0x4EF2d1A2Ea8FC71347801b0E6A4cCF51E6898056` |
| 1 | settlement direct CREATE | `0xa72ab3796f654e6d7fc0814aefa07792658b302d75e5b47896511826af089157` | 45483228 | 1,679,458 | 10,356,510,323,937 | status 1; Settlement `0xD5e6befEfE3aD991e3677be744b6D7Fd3F5c02AE` |
| 2 | root registration | `0xd292660c9ca7048b1c49ba6f0a8cab9ec817630fddd0fe5e9fc07ca51bc3d638` | 45484403 | 355,181 | 2,158,931,403,487 | status 1; exactly one `ReceiptRootRegistered` |
| 3 | honest receipt consume | `0x9e2bde96af3279d955a35afc08b11c05fa2e732b1a8bb95e4867d6aa77fb7036` | 45485219 | 279,871 | 1,714,676,186,374 | status 1; exactly one `SettlementConsumed` |

All four transitions are contained by finalized block `45485221`, hash
`0x51954822f52e1a3a6af56d2578461695ee7ec14b2f9ad6216546da1badfff9b1`,
timestamp `2026-08-15T05:18:50+09:00`, state root
`0xc2f6f9cb4daf02c3d6760b213d0732d21e784f48801b66c79f936fc1caedba05`.
At that pin D0 nonce is `4`, D0 balance is `76349766896754` wei, and the four
D0 fees sum exactly to `23650233103246` wei.

## Finalized code, policy, and post-state

Root runtime is 5,538 bytes, SHA-256
`91c9d765eeca0318e257ebc14431ec29c551686325aee02b60a7a04ea1cafc5f`,
Keccak-256
`0x5892c1b8aeca153e2ed2c0af147f8dfd80e5906b1886a5d581156a3b484c2360`.
Settlement runtime is 6,689 bytes, SHA-256
`61cc9aec11ea7fa532af038c080f4ef0efb8ef9354f3167eb73a5b6cf99d1abe`,
Keccak-256
`0x142573c3c22475fe568e14ca3ded54cbdbd28078af23c6b07bf6fbcc5e5c09cb`.
Both match the constructor-bound rehearsal artifacts.

These are direct, immutable, non-upgradeable deployments. The EIP-1967
implementation, admin, and beacon slots read zero for both contracts at the
finalized pin, and the ABI/source contains no admin, owner, upgrader, pause,
upgrade, or delete surface.

The Root getters bind epoch `1`, threshold `3-of-5`, the sorted v3 root signer
set, source network/genesis/runtime/context/domain, next nonce `2`, transition
and event counts `1`, and registered coordinate
`0x02642bf98eddfd93180e16bd10f7b00206d37d708e281f3bdb331f689ee94698`.
Its state digest is
`0x1c225049612ac7c2042ae68d0dd129713e9e56e3af68bc4f959418a98824dbef`.

The Settlement getters bind the Root address, independent epoch `1`, threshold
`2-of-3`, sorted v3 PFR signer set, chain `84532`, and its own address as the
destination consumer. Claim
`0xdd781e4b503738241e852484fe1db0af245c61fbb57a9ee4c1c11bd649cd3395`
and settlement key
`0x8b95044346966f4f9123d718deee56cc78bcf539e35a5eb4ee7460455fbcddf9`
are both consumed. Its state digest is
`0x8fed68c3f4aa0e1252779eed59afda66e3b912dcc36b1641ef38c1bb9c27a481`.

The registration event binds the frozen coordinate and authorization digest
`0x7ccc4e3c7d7f38c2f37e515e26edf63b9d3cc8b069b463600961c780ea535c7d`,
root `0x7c609ffcf63004e1203188d6fbed6f5431fa344d6f90990c2c45a6db3bbc466e`,
nonce `1`, and the first three sorted root signers. The consume event binds the
claim and settlement IDs, PFR
`0x00dc0504fcd956008deed8f46067ead0e7008f40f4dfbf711e016e0aa88f3904`,
and accepted root
`0x88957f2aa94f0f483d11f6bbc00b37db9fedd7911eee56e15c1661e148453200`.
The companion JSON freezes every transaction/block hash, fee component, input
hash, topic, event-data hash, getter, and storage-slot result.

## Negative-call evidence

At the finalized EIP-1898 pin, all `25/25` directly runnable frozen Product
vector calls returned the exact custom-error selectors and left the full Root
and Settlement state digests and event counters unchanged. This set is the 33
typed rows minus four constructor-only cases, three overflow cases requiring
call-local state override, and the alternate-valid-PFR `SettlementReplay` case.

Five additional native calls used already-public, independently recovered
signatures over validly signed mutations: same-coordinate different-root
conflict (`0x68693590`), stale epoch (`0xda669d8e`), reused and skipped nonce
(`0x54d5b1df`), and alternate-claim same-settlement replay (`0x1e1e38a4`).
All `5/5` matched and preserved the same getters, digests, and event counts.
Native EIP-1898 `eth_call` supplied each exact
error selector, while `debug_traceCall` with call-tracer logs reported zero
logs.

Targeted getters were identical before and after all five calls: the new
aggregation-`53669` coordinate
`0x6c5de78ee2fa360557e4155df0c6d887c8e5b7994f47b2d9e27f374b892ff07d`
remained all-zero with `exists=false`; the original coordinate and registered
root remained unchanged; Root `nextNonce` remained `2`; alternate claim
`0x949e684ec3a67756cdbed583d656a22225d73ca6a74dc6e9455c0fa11edf683f`
remained unconsumed; and the original settlement key remained consumed.

The validly signed skipped-nonce case is also an activation hazard, not merely
a negative test. Its public R1–R3 quorum authorizes epoch `1`, aggregation
`53669`, nonce `3`. Current Root `nextNonce=2` makes it fail only temporarily:
after any valid nonce-`2` registration it would become submit-ready. The signed
digest also omits destination chain and contract address, so the same public
authorization is replayable against a fresh epoch-`1` clone with matching
policy. This receipt therefore permanently freezes `nextNonce=2` and abandons
the current Root, Settlement, D0, root signer roles, and PFR signer roles for
any future chain action.

Nine call-local override cases exercised coordinate conflict; stale, reused,
and skipped authorization; authority-context and wrong-authorization paths;
settlement replay; and Root and Settlement counter overflow. All `9/9` returned
the expected selector. `debug_traceCall` reported zero emitted logs and zero
contract-storage diff. Overrides were call-local and persistent-chain mutation
count was zero. The JSON records the exact case digests and the invariant
before/after values; it does not contain any private key or password.

## Custody correction and claim ceiling

Only the external encrypted v3 testnet profile was used. Its DPAPI wrapper is
716 lowercase hex characters decoding to a 358-byte DPAPI blob. Windows
CurrentUser unprotection yielded 128 UTF-16LE bytes representing 64 ASCII
characters. The successful bridge wrote those 64 ASCII characters only to
redirected stdin; the redirector supplied an implicit UTF-8 BOM, producing an
exact 67-byte, mode-`0600` `/dev/shm` password file. Supplying an explicit BOM
would double-prefix the stream and the diagnostic attempt failed MAC validation
before signing. Every temporary file was removed; final residue count is zero.
Only ciphertext representation and byte-count metadata are disclosed here.

D-50 technical execution checks are `4/4 PASS`: finalized code/topology,
immutable roles/getters, honest finalized consume, and negative state/log
invariance. Condition 5 also passes by binding Brain semantic checkpoint
`9eb7457027e18fa8ddd153c8064a8bda86965d34`'s fail-closed operational policy.
V1 has no on-chain pause, rotation, revocation, owner, or upgrade primitive; an
public latent authorization requires immediate and permanent non-activation,
halt of D0/root/PFR signing, and abandonment of both addresses. No future
approval may reactivate them or permit another registration or consume. The
only possible later path is a separately approved epoch-`2` fresh direct
redeployment with nonreused keys that repeats the entire evidence gate. This is
operational evidence, not an on-chain control or action approval.

Thus D-50 conditions `1–5 of 6 PASS`. Condition 6 remains open until this exact
Product/EVM/Brain evidence receives runner and independent audit, is committed,
and all three canonical remotes are exact. Therefore A11 remains **OVERALL
HOLD**. No production activation, additional transaction, real-mainnet
principal, formal security audit, or GRANDPA claim is authorized or implied.
