# Security Policy

## Current support boundary

Security reports about the repository baseline are welcome and read with care.
The repository is pre-deployment; no version is currently designated
production-supported, and [`DISCLAIMER.md`](DISCLAIMER.md) records the exact
non-claims.

| Version | Security status |
| --- | --- |
| Unreleased repository baseline | Reports accepted; not production-supported |
| Releases | None |
| Deployments | None |

Future support ranges must identify exact tags or commits. A branch name, an
arbitrary fork, or modified bytecode is not a supported release identity.

## Private reporting

Email `security@oraclizer.io` with the subject
`[statesync-gkr-settlement-evm security]`.

Include when available:

- the exact commit or artifact hash;
- affected source path and function;
- impact and preconditions;
- minimal reproduction or proof of concept;
- whether the issue is already public; and
- a safe way to coordinate follow-up.

Do not include private keys, seed phrases, live credentials, wallet exports, or
unnecessary personal data. If sensitive material is required to demonstrate the
issue, first ask for a safe transfer method.

Do not disclose a suspected vulnerability through a GitHub issue, Pull Request,
discussion, social media post, or other public channel before coordinated review.

## Coordination expectations

Reports are handled case by case: the maintainer coordinates recognition,
disclosure timing, and remediation with the reporter, without promising a
service level, bounty, embargo duration, or legal safe harbor beyond what
applicable law and the repository licenses already provide.

## Out of scope

The following are not security findings by themselves:

- the absence of production contracts or deployments in this baseline;
- issues that require a modified fork not represented by an exact repository
  revision;
- social engineering, denial-of-service traffic against third-party services,
  or access to systems without authorization; and
- claims about a network, bridge, signer, operator, or deployment that this
  repository does not identify as supported.
