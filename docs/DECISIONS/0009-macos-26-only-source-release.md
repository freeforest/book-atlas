# ADR-0009: macOS 26-only source release

- Status: Accepted
- Date: 2026-08-08
- Owners: Project maintainers
- Supersedes: ADR-0003

## Context

ADR-0003 selected macOS 14.0 before the first production project existed. The
implemented application and accepted Prompt 10 evidence were validated on
macOS 26 with Xcode 26. The maintainer has now chosen a source-only GitHub
release and does not promise macOS 14/15 compatibility or maintain a
multi-version compatibility matrix.

## Decision

Book Atlas V1.0.0 targets macOS 26.0 only. The production project, application,
unit-test target, and UI-test target use `MACOSX_DEPLOYMENT_TARGET = 26.0` in
Debug and Release. Users build the source with a compatible Xcode 26 toolchain.
No precompiled application is distributed.

The historical technical spike and Prompt 0 records remain evidence of the
earlier macOS 14 decision; they are not current V1.0.0 support claims.

## Consequences

- The project has one current deployment target and no macOS 14/15 test matrix.
- Changes may use macOS 26 APIs after normal review, but this decision alone
  does not require a feature refactor.
- Debug, Release, complete non-UI, complete UI, and affected manual checks must
  be rerun after the target change.
- A future minimum-version change must supersede this ADR rather than rewriting
  the historical decision.

## Privacy and security

The deployment-target change adds no entitlement, network access, dependency,
data collection, or persistence behavior. App Sandbox and explicit
user-selected file access remain unchanged.

## Validation

V1.0.0 source-publication preparation records the project-setting audit,
actual-product metadata and entitlement inspection, complete builds/tests, and
the real native file-panel check in the development and quality documents.
