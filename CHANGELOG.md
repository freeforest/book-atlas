# Changelog

## [Unreleased]

### Added

- Local Prompt 11A working-tree implementation for viewing distinct incoming
  and outgoing manual book relations, bounded paged target search, explicit
  source-to-target creation, exact counterpart navigation, and confirmed
  relation-only deletion.

### Validation status

- `BLOCKED — WAITING FOR CONTROLLER REVIEW`: targeted relation tests, related
  regressions, Debug build, 209/209 non-UI tests, and 3/3 targeted UI tests
  passed, but the complete UI gate did not survive its one permitted clean
  infrastructure retry. This entry is not controller acceptance or a release.
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
