## Summary

Describe the user-visible or security-relevant effect of this change.

## Scope and claims

- [ ] The change is focused and contains no unrelated files.
- [ ] Documentation and status claims match the implementation and tests.
- [ ] No internal roadmap identifiers, private paths, credentials, wallet material, RPC URLs, or deployment secrets are included.
- [ ] Any compatibility, trust-boundary, or storage-layout change is called out explicitly.

## Validation

- [ ] `forge fmt --check`
- [ ] `forge build`
- [ ] `forge test --fuzz-seed 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f`
- [ ] New behavior has positive, negative, fuzz, or invariant coverage proportional to risk.
- [ ] Failure paths preserve state and events when atomic rejection is claimed.

List the exact commands, results, tool versions, and any intentionally skipped check:

## Security and deployment

- [ ] I reviewed authorization, replay, reentrancy, denial-of-service, arithmetic, signature, and upgrade implications where applicable.
- [ ] This Pull Request does not deploy, broadcast, sign, fork, or call an RPC endpoint.
- [ ] Any deployment or release action is separately authorized and documented.

## Provenance

List new dependencies, generated files, external specifications, and exact version or commit pins. Explain any lock or supply-chain change.
