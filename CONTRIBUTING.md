# Contributing to Book Atlas

Thank you for helping improve Book Atlas · 图书志. The project is a native,
local-first macOS bibliography manager. Contributions should preserve that
small, privacy-conscious scope.

## Before proposing a change

1. Read `AGENTS.md`, `README.md`, the core documents under `docs/`, and the
   active milestone plan.
2. Search existing issues before filing a new one.
3. For a product or architecture change, open an issue before implementation.
   A change to persistence, privacy, security, dependencies, entitlements,
   external integrations, or the minimum macOS version normally needs an ADR.
4. Never attach a real library, backup, export, URL, local path, bookmark,
   credential, signing asset, or private note to an issue or pull request.

## Development

The verified local build and test commands are in
`docs/DEVELOPMENT.md`. Keep generated output in `/tmp` or another ignored
location. Tests must use fixed fictional data and temporary or in-memory
databases.

Keep changes focused:

- preserve App Sandbox and offline-by-default behavior;
- keep SQL, migration, merge, parsing, and system-integration rules out of
  SwiftUI views;
- add regression tests for defects and migration tests for schema changes;
- add no dependency without a documented need and license/security review;
- update documentation when behavior or a verified limitation changes.

Before requesting review, run the relevant Debug and Release builds, the full
unit/integration and UI suites, and `git diff --check`. Use the checklist in
`docs/RELEASE_CHECKLIST.md` for release-facing work.

## Pull requests

Describe the user-visible outcome, privacy/security effects, tests actually
run, and unverified items. Keep screenshots fictional and free of private
paths or identifiers. Do not claim a system integration, supported OS, signing
configuration, or performance level that was not actually verified.

## License note

The repository contains an MIT license template whose year and copyright
holder are explicit placeholders. A maintainer must replace them before a
public release. This repository documentation is not legal advice.
