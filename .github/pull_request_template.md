## Outcome

Describe the focused user or maintenance outcome.

## Scope and decisions

- [ ] The change stays within the current product and milestone scope.
- [ ] Relevant ADRs and documentation are updated.
- [ ] Any schema change is versioned and has migration/rollback tests.
- [ ] Any dependency, entitlement, or system integration has an explicit review.

## Privacy and security

- [ ] Tests and examples use only fixed fictional data.
- [ ] No database, backup, bookmark, private URL/path/note, secret, certificate,
      provisioning profile, or build artifact is included.
- [ ] Logs and user-facing errors do not disclose private payloads.
- [ ] Offline-by-default and App Sandbox behavior are preserved.

## Verification

List exact commands and real results:

- Debug build:
- Release build:
- Unit/integration tests:
- UI tests:
- `git diff --check`:
- Entitlement/dependency/privacy scans:

## Unverified items and risks

State anything that still requires manual testing, external-system validation,
or independent review. Signing/notarization applies only if a future separate
task introduces precompiled binary distribution.
