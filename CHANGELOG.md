# Changelog

## [Unreleased]

### Added

- Authorized Prompt 11B BookKind selector, detail display and shared-query
  multi-select filtering with unchanged stored values and default. Limited
  validation now has historical 11 passing tests plus two newly authorized
  precondition-repair tests passing; not one 13/13 run. UI awaits fresh session
  confirmation; Release/manual checks remain pending. P11 awaits final
  controller acceptance. The P11B plan preserves the earlier 11/13 failure.

- Local Prompt 11A working-tree implementation for viewing distinct incoming
  and outgoing manual book relations, bounded paged target search, explicit
  source-to-target creation, exact counterpart navigation, and confirmed
  relation-only deletion.

### Fixed

- Narrow manual-relation save lifecycle repair: Store-level duplicate-submit
  and draft-mutation guards, cancellation only before submission, and local
  draft identity checks against late write/refresh results. Unknown failures
  no longer claim rollback; failed drafts remain editable and cancellable.

### Validation status

- Prompt 11A has passed controller functional acceptance and remains unreleased.
  Evidence: Store 45/45, complete non-UI 221/221, relation UI 4/4 including
  busy-state/Escape, Release build/product checks, and user-confirmed manual
  creation, navigation, cancelled deletion and confirmed deletion in the
  verified Release fictional in-memory instance. The controller accepted the
  historical full UI 44/45 plus the diagnosed expectation repair's independent
  1/1; this is not a single full UI 45/45 result and no full rerun is required
  for that repair. User Git and complete pending-change review remain PENDING;
  real-user database persistence manual verification and Intel hardware
  execution remain unverified. Prompt 11B is now separately authorized;
  its validation does not reuse these P11A results.
- Historical save-lifecycle repair (`BLOCKED` at that time): it first
  reproduced four failing non-UI cases (exit 65), then passed 12/12 Store tests,
  217/217 complete non-UI tests, and one Debug build (each exit 0). Structured
  result parsing completed. Previous 209/209 and UI 3/3 results predate this fix.
- Read-only UI evidence correction: full-ui-36 is 44 total / 31 passed /
  13 failed / 0 skipped; retry-37 is a parseable interrupted run with 5 total /
  1 passed / 4 failed / 0 skipped, including a cancellation. Connection loss,
  authorization errors, and exact input-value mismatches do not establish a
  common root cause. No new UI run was performed in that repair; busy-state/
  Escape runtime checks, Release, and final audits were unverified at that
  time. That repair alone was not controller acceptance or a release; all Git
  checks remain manual user work. Later acceptance is recorded above.
- No Schema 5, CSV, backup format, dependency, entitlement, marketing version,
  build number, or V1.0.0 release-history change is intended by Prompt 11A.

## [1.0.0] - 2026-08-10

### Added

- Local book creation, viewing, editing, and deletion with validation.
- Search, structured filtering, deterministic sorting, exact counts, and
  bounded pagination.
- Tags, reading lists, sources, and book memberships.
- Explainable duplicate detection with user-confirmed transactional merge.
- Versioned CSV import with mapping and bounded preview.
- CSV and Markdown export with privacy and formula-injection safeguards.
- Versioned SQLite backup, validation, restore preview, recovery copy, and
  interruption-safe recovery.
- Bounded local relationship graph with deterministic layout and a semantic
  keyboard/accessibility list.
- User-initiated HTTPS entries, conservative Apple Books fallbacks, and
  security-scoped local-file entries.
- Keyboard operation, VoiceOver support, Reduce Motion-safe behavior, semantic
  accessibility labels, and responsive Light/Dark layouts.

### Privacy and distribution

- Offline by default with no account, telemetry, advertising, tracking, cloud
  sync, or automatic metadata download.
- Source-only GitHub release for macOS 26; users build with Xcode 26.
- No precompiled `.app`, `.dmg`, `.pkg`, or binary application archive.
- No claim of exact Apple Books private-library targeting or permanent
  whole-application zero-warning Accessibility Inspector results.

[1.0.0]: https://github.com/freeforest/book-atlas/releases/tag/v1.0.0
