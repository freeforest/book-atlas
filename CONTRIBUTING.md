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

Issue and pull-request actions above are for human contributors. Coding agents
follow the owner's current task and [AGENTS.md](AGENTS.md); an explicitly
authorized local change does not require creating an Issue first. All
Git/GitHub operations are manual user actions, including read-only commands.
Agents must not run `git`/`gh`, access `.git`, or use another tool to perform
those operations. Existing commands and historical checklists are not grants
of repository or publication authority.

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

Before requesting review, complete the checks appropriate to the change and
every gate explicitly required by the current task. Follow the
[verification policy](docs/DEVELOPMENT.md#verification-policy): documentation
edits need document checks; behavior changes need relevant regressions and
builds. Full suites and Release checks apply when required by scope or the
authorized acceptance plan, not automatically to every edit. The user runs
`git diff --check` and reviews the complete pending changes manually; keep
that evidence pending if it has not been supplied.

The checklist in `docs/RELEASE_CHECKLIST.md` records the V1.0.0 source release.
It informs separately authorized release work; it neither starts a new
release task nor grants agents Git/GitHub access.

## Pull requests

Describe the user-visible outcome, privacy/security effects, tests actually
run, and unverified items. Keep screenshots fictional and free of private
paths or identifiers. Do not claim a system integration, supported OS, signing
configuration, or performance level that was not actually verified.

## License note

The repository uses the MIT License with the user-confirmed copyright line
`Copyright (c) 2026 FreeForest`. This repository documentation is not legal
advice.
