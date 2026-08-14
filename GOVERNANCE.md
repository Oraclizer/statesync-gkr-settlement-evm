# Governance

## Scope

This document governs repository changes, not any deployed protocol, operator,
signer set, external network, or legal entity. Local reference contracts and a
test vector exist, but there is no release, deployment, approved production
principal, or production authority to govern.

## Maintainer

The current repository maintainer and CODEOWNER is `@jay-oraclizer`. CODEOWNERS
identifies review ownership; it is not a security audit, deployment role, signing
role, or guarantee that a proposal will be accepted.

## Change process

- Keep one logical change in one branch and one Pull Request.
- Prefer issue-first discussion for material interface, storage, authorization,
  cryptographic, dependency, compatibility, or governance changes.
- Required Continuous Integration must pass before merge.
- Review must compare implementation, tests, documentation, and claims.
- Force pushes to the default branch, rewritten release tags, and reused release
  identities are not acceptable.
- Repository protection settings and publication remain separate administrative
  gates and are not implied by this tracked policy.

For a single-maintainer repository, repeated self-approval is not treated as an
independent review. Required checks, a focused diff, linear history, immutable
release identities, and explicit disclosure of missing independent review are
the minimum controls. Independent reviewers or additional maintainers may be
required as the implementation and deployment risk grows.

## Decision criteria

Maintainers evaluate:

- semantic correctness and fail-closed behavior;
- compatibility and state/storage migration effects;
- test, fuzz, invariant, and evidence quality;
- security and trust-boundary impact;
- dependency and compiler provenance;
- public claim accuracy; and
- maintainability and operational recovery.

Acceptance of a reference implementation does not select a deployment, signer,
operator, proxy, upgrade authority, supported network, or production release.

## Releases and deployments

A release requires an immutable tag, exact source commit, changelog, toolchain
pins, reproducible commands, checksums for published artifacts, and an explicit
audit and deployment-status statement. An audited release and an unaudited
candidate must use visibly different identities.

Deployment, broadcast, upgrade, role assignment, signer activation, and release
publication require separate authorization and evidence. Merging source alone
does not perform or authorize any of those actions.
