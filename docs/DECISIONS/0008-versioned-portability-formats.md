# ADR-0008: Versioned portability formats and safe database snapshots

- Status: Accepted
- Date: 2026-07-28
- Owners: Project maintainers
- Related: ADR-0006; this ADR extends its explicit-selection rule for one-shot write destinations

## Acceptance

Accepted after the third independent Prompt 7 review at baseline `b27318c741fee5b4a66e5ad99cb979177285fef5`. Independent verification recorded a successful Debug build, 114/114 unit and integration tests, and 17/17 macOS UI tests, with no failures or skipped tests. At that acceptance baseline the production schema was version 4 with migration path 1 → 2 → 3 → 4. Prompt 9 later extends the supported application schema to 5 without changing backup format version 1 or this ADR's accepted portability semantics.

## Context

Prompt 7 requires user-mapped CSV import, human-readable export, spreadsheet-safe CSV export, and complete SQLite backup/restore. Copying a live SQLite main file is not consistent when writes or WAL pages are present. Broad filesystem access, background scanning, ZIP dependencies, and persistent write authorization are outside scope.

## Decision

Use the documented `bookatlas-csv/1` row format for import and CSV export, and `bookatlas-markdown/1` for human-readable export. Parse CSV incrementally as bytes with explicit file, row, column, and field limits. Write parsed rows to a controlled disk staging file bound to the source fingerprint and mapping generation; retain only counts, at most 20 sample rows, and at most 80 issue details in presentation state. Preview and field mapping are side-effect free.

Evaluate preview rows in deterministic CSV order with Prompt 6 Exact/Strong rules against the formal library and an isolated index of earlier accepted rows in the same batch. Confirmed import streams staging within one repository transaction and re-runs Exact/Strong detection against current transactional state. Candidate rows are skipped without overwriting, merging, creating ignored pairs, or creating a persistent pending-review identity. Therefore they do not silently appear in ordinary duplicate review; the actual execution report tells the user which rows must be corrected or created through the normal reviewable flow. Broader Possible matching remains a manual-review operation.

Use a single SQLite file with extension `.bookatlasbackup` as backup format version 1. Create it with SQLite's online backup API, normalize the completed snapshot to single-file DELETE journal mode, add a private manifest table, run physical and application-schema validation, then move the temporary file to a user-selected, non-existing destination. The manifest records backup format, schema, application version, and creation time, but no source path. The maximum supported backup is 4 GiB; source and selected-file size checks happen before copying or an expensive integrity pass. Capacity checks include a 16 MiB safety reserve, and restore accounts for the live database, staged database, and recovery snapshot before each relevant write.

Restore rejects non-regular files, symbolic links, wrong extensions, invalid SQLite headers, missing or invalid manifests, failed physical or application-schema checks, future backup versions, and future schemas. Application validation uses an exact object whitelist for each schema version 1–5: required tables and ordered columns, primary/unique/foreign keys and critical checks; every formally named ordinary index with its table, uniqueness, ordered key columns, direction, and collation; no views; and, in schemas 4 and 5, the exact `invalidate_ignored_duplicate_pairs_after_identity_update` trigger on `books`. Schema 5 additionally validates the local-file-reference table/index, checks bookmark lengths in SQLite before accessing BLOB bytes, streams accepted BLOB rows one at a time, and domain-decodes canonical safe display names, 1-byte-through-1-MiB opaque bookmarks, UUIDs, and timestamps. The backup manifest table is an explicit inspection-only allowance. Unknown tables, ordinary indexes, triggers, or views are rejected. Validation also requires exact migration history, `foreign_key_check`, domain UUID/date/enum decoding, every association family, derived duplicate index rows, and ignored pairs. It runs on inspection, after staged migration, on the installed file before reconnect, and when startup recovery evaluates a candidate.

Inspection, recovery snapshot creation, staging, and migration are cancellable. One lock-protected operation control is the authority for both the current background phase and whether cancellation can still be accepted. A cancellation request does not invalidate presentation state or claim that the library is unchanged until the coordinator returns `cancelled`. The transition into safe replacement and a competing cancellation request are atomic: if cancellation wins, replacement never starts; if safe replacement wins, Cancel/Escape cannot invalidate the operation and its real success or failure is published. Operation identity also rejects delayed progress callbacks after completion or failure. The final replacement and reconnect phase is explicitly non-cancellable in state and UI. Checkpoint the actor-isolated live connection, then, before closing it, persist a path-free state marker naming randomized old and new files in the same directory. Process termination at any later boundary is repaired at startup by selecting a fully schema-valid formal file, otherwise old file, otherwise staged new file. If no unique safe choice exists, repository opening stops with recovery guidance; a missing formal path must never cause empty-database creation while a restore marker exists. Ordinary failures restore the old file and reopen it. Success and automatic recovery clear the marker and controlled old/new files while retaining the verified recovery backup.

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
- A small path-free restore marker and same-filesystem old/new files may survive process termination until startup recovery completes.
- CSV is suitable for interchange but cannot represent external links or manual relations; full-fidelity transfer uses the database backup.
- The current import transaction is all-or-nothing for fatal errors or cancellation; recoverable row validation failures and duplicate candidates are counted and skipped.
- Backup files are SQLite databases and are not encrypted by Book Atlas. Users must choose and protect their destination.

## Privacy and security

Selected paths, rows, notes, URLs, exports, and database payloads are never logged. Confirmed execution stages only structured issue fields—row number, mapped field, stable code, generic description, and retryability—in controlled JSON lines. The actual CSV report is generated only after a save destination is selected. Temporary import/issue/restore artifacts are app-controlled and cleaned on success, cancellation, supersession, and ordinary failure; a verified recovery copy is intentionally retained.

## Validation

Validation uses only temporary directories, in-memory databases, and fixed fictional data. It covers UTF-8/BOM/quoting/multiline/limits, bounded disk staging, stale mapping generations, no-write preview, existing and same-batch Exact/Strong duplicates, actual execution reports, association deduplication, fatal rollback, six formula prefixes, Markdown/path escaping, empty and populated snapshots, uncheckpointed WAL content, incomplete/invalid application schemas, exact schema 1–5 object acceptance, missing/malformed named indexes, missing/modified/extra triggers, extra views, restored ignored-pair invalidation, Schema 5 bookmark-reference preservation, canonical-name and 1 MiB boundary validation, oversized `zeroblob` rejection before formal-library close, streamed multiple-near-limit validation, corrupt/future/symlink/oversized rejection, old-schema restore migration through version 5, capacity and real write-space error mapping, authoritative cancellation on both sides of the safe-replacement boundary, delayed phase suppression, recovery copies, three repeatable process-termination boundaries, replacement rollback, reconnect errors, UI accessibility/keyboard paths, a near-limit memory measurement, and measured 1,000/5,000/10,000-record baselines. Exact commands and results are recorded in `docs/DEVELOPMENT.md`.
