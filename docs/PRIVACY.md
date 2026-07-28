# Privacy

## Baseline

Book Atlas is local-first and offline by default. A personal bibliography can reveal interests, habits, relationships, and private notes, so library content is treated as sensitive even when individual book metadata is public elsewhere.

## Data handled

Potentially private data includes books, contributors, tags, lists, sources, ratings, status, notes, external URLs, identifiers, imported files, exported archives, backups, local paths, cover caches, database files, and security-scoped bookmark data.

## Collection and sharing

- No account, telemetry, advertising, tracking, analytics, automatic crash upload, cloud sync, or automatic metadata/cover retrieval.
- No network client entitlement by default.
- No file is read until the user explicitly selects it or grants persistent access for a documented feature.
- Import, export, backup, and restore are explicit user actions with visible destinations and results.
- A future network feature requires a product need, privacy review, data-flow documentation, minimal entitlement, and explicit user control before implementation.

## Storage

The production database is stored at `Application Support/BookAtlas/book-atlas.sqlite` inside the app-specific Application Support directory. Tests use temporary or in-memory stores and do not discover a real library. User-requested exports and backups go only to a selected destination. Restore retains a verified UUID-named recovery copy under the app's `Recovery Copies` directory and does not silently delete it. A process-interruption marker contains only a format version, schema version, token, and randomized relative filenames—never the selected backup path or library contents—and is removed after recovery. Prompt 7 stores no security-scoped bookmark.

## Logging

Logs may include operation names, durations, counts, schema versions, and coarse error categories. They must omit or redact titles, contributors, notes, tags, list names, source contents, identifiers, URLs, local paths, imported rows, exported contents, bookmark bytes, and database payloads. Debug logging follows the same rule.

## Repository and testing

- Real databases, reading lists, notes, exports, backups, paths, bookmarks, account data, and credentials are prohibited.
- `SampleData/` contains fictional, reviewable fixtures only.
- `LocalData/` and generated-data directories are ignored.
- Tests use temporary or in-memory stores and never discover or read a real user library.

## User control

The user must be able to inspect and edit records, explicitly initiate export and backup, cancel imports where practical, understand destructive consequences, and remove stored access to external files. Duplicate merging and restore operations require review and confirmation.

Duplicate normalization, scoring, candidate lookup, ignore decisions, previews, and merges run entirely on-device. Ignore storage contains only two book UUIDs, a disposition, and a timestamp; it does not duplicate titles, authors, notes, URLs, or relationship contents. Duplicate and merge errors shown to users are generic and do not expose stored payloads.

Merge preview renders concrete tags, collections, sources, external links, and relation details only in the local UI so the user can judge preservation outcomes. Those values are not emitted to logs. Test previews use fixed fictional records and `example.invalid` URLs in an isolated in-memory store.

Import previews render at most 20 selected-file rows only in the local UI; the full staged import remains in an app-controlled temporary directory and is removed on success, cancellation, failure, or replacement by a newer mapping. Confirmed execution may retain structured issue staging that omits raw rows and values; an error-report CSV is generated only after the user chooses where to save, and issue staging is deleted when discarded or exported. Markdown removes recognizable local absolute paths, CSV formula guards dangerous leading characters, and full backups intentionally contain private library data in an unencrypted SQLite snapshot; the user is responsible for protecting the selected destination.

The Prompt 8 graph reads only the current local database after the user chooses a center book. Titles, author strings, organization names, and manual-relation explanations remain in the local UI and accessibility tree; they are not logged, exported, transmitted, or copied into new persistence. Layout coordinates, filters, selection, and viewport state are transient. Performance and regression tests use only fixed fictional in-memory records.
