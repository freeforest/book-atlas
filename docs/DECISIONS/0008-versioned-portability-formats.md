# ADR-0008: Versioned portability formats and safe database snapshots

- Status: Proposed
- Date: 2026-07-28
- Owners: Project maintainers
- Related: ADR-0006; this ADR extends its explicit-selection rule for one-shot write destinations

## Context

Prompt 7 requires user-mapped CSV import, human-readable export, spreadsheet-safe CSV export, and complete SQLite backup/restore. Copying a live SQLite main file is not consistent when writes or WAL pages are present. Broad filesystem access, background scanning, ZIP dependencies, and persistent write authorization are outside scope.

## Decision

Use the documented `bookatlas-csv/1` row format for import and CSV export, and `bookatlas-markdown/1` for human-readable export. Parse CSV incrementally as bytes with explicit file, row, column, and field limits. Preview and field mapping are side-effect free. Confirmed import uses one repository transaction, re-runs the Prompt 6 create-save Exact/Strong duplicate check for each proposed identity, and skips candidates for later review rather than overwriting or merging. Broader Possible matching remains a manual-review operation.

Use a single SQLite file with extension `.bookatlasbackup` as backup format version 1. Create it with SQLite's online backup API, normalize the completed snapshot to single-file DELETE journal mode, add a private manifest table, run `PRAGMA integrity_check`, then move the temporary file to a user-selected, non-existing destination. The manifest records backup format, schema, application version, and creation time, but no source path.

Restore rejects non-regular files, symbolic links, wrong extensions, invalid SQLite headers, missing or invalid manifests, failed integrity checks, future backup versions, and future schemas. It previews before confirmation, creates and validates a recovery backup, stages and migrates the selected snapshot, closes the live connection, safely replaces the database, and reopens it. Replacement or reconnect failure restores the original file when possible and reports an explicit error.

Prompt 7 uses the App Sandbox `user-selected.read-write` entitlement only for URLs returned by `NSOpenPanel` or `NSSavePanel`. Every security-scoped access lifetime is balanced. No bookmark is retained for these one-shot operations, no directory is scanned, and no network entitlement is added.

## Alternatives considered

- **Copy the SQLite main file:** rejected because WAL or concurrent writes can make it incomplete.
- **ZIP archive with JSON manifest:** rejected because one verified SQLite snapshot needs no archive dependency or path-expansion surface.
- **Automatic duplicate merge during import:** rejected because it bypasses Prompt 6 review and transaction guarantees.
- **Broad or persistent filesystem authorization:** rejected because every Prompt 7 operation is explicitly initiated and one-shot.
- **CSV escaping without formula protection:** rejected because correct RFC-style quoting does not stop spreadsheet formula interpretation.

## Consequences

- Backups are consistent, independently integrity-checkable, and can carry older supported schemas through the existing migration registry.
- Recovery copies consume local Application Support space and are intentionally retained rather than silently deleted.
- CSV is suitable for interchange but cannot represent external links or manual relations; full-fidelity transfer uses the database backup.
- The current import transaction is all-or-nothing for fatal errors or cancellation; recoverable row validation failures and duplicate candidates are counted and skipped.
- Backup files are SQLite databases and are not encrypted by Book Atlas. Users must choose and protect their destination.

## Privacy and security

Selected paths, rows, notes, URLs, exports, and database payloads are never logged. Error reports contain only row number, mapped field, stable error code, generic description, and retryability, and are created only after a save destination is selected. Temporary directories are app-controlled and cleaned on success and failure.

## Validation

Validation uses only temporary directories, in-memory databases, and fixed fictional data. It covers UTF-8/BOM/quoting/multiline/limits, mappings and no-write preview, duplicate reuse, association deduplication, fatal rollback, six formula prefixes, Markdown/path escaping, empty and populated snapshots, uncheckpointed WAL content, corrupt/future/symlink rejection, schema-3 restore migration, recovery copies, replacement rollback, reconnect errors, UI accessibility/keyboard paths, and measured 1,000/5,000/10,000-record baselines. Exact commands and results are recorded in `docs/DEVELOPMENT.md`.
