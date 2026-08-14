# Security Policy

## Current support boundary

This repository is private, pre-deployment, unaudited, and has no release,
contract, deployed bytecode, supported network, or production user surface.
Security reports about the repository baseline are welcome, but no version is
currently designated production-supported.

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

## No response-time, bounty, or safe-harbor promise

The project does not currently promise an acknowledgement or remediation service
level, bounty, payment, embargo duration, or legal safe harbor. Any recognition,
coordination, disclosure timing, or remediation plan is determined case by case.
This statement does not alter rights or obligations under applicable law or the
repository licenses.

## Out of scope

The following are not security findings by themselves:

- the absence of production contracts or deployments in this baseline;
- issues that require a modified fork not represented by an exact repository
  revision;
- social engineering, denial-of-service traffic against third-party services,
  or access to systems without authorization; and
- claims about a network, bridge, signer, operator, or deployment that this
  repository does not identify as supported.
