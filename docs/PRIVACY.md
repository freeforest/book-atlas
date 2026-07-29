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

The production database is stored at `Application Support/BookAtlas/book-atlas.sqlite` inside the app-specific Application Support directory. Tests use temporary or in-memory stores and do not discover a real library. User-requested exports and backups go only to a selected destination. Restore retains a verified UUID-named recovery copy under the app's `Recovery Copies` directory and does not silently delete it. A process-interruption marker contains only a format version, schema version, token, and randomized relative filenames—never the selected backup path or library contents—and is removed after recovery. Prompt 7 stores no bookmark for one-shot portability access. Prompt 9 stores opaque read-only app-scoped bookmark bytes and a safe basename only after the user selects one ordinary file; it does not persist an absolute path or inspect file content.

## Logging

Logs may include operation names, durations, counts, schema versions, and coarse error categories. They must omit or redact titles, contributors, notes, tags, list names, source contents, identifiers, URLs, local paths, imported rows, exported contents, bookmark bytes, and database payloads. Debug logging follows the same rule.

The Prompt 10 source audit found no production `print`, `NSLog`, `os_log`, or
`Logger` call site and no telemetry or automatic crash-upload client.
Fixed-fictional performance values are emitted only by the test target. This
is source-level evidence, not a claim about logs generated internally by macOS
or Xcode.

## Repository and testing

- Real databases, reading lists, notes, exports, backups, paths, bookmarks, account data, and credentials are prohibited.
- `SampleData/` contains fictional, reviewable fixtures only.
- `LocalData/` and generated-data directories are ignored.
- Tests use temporary or in-memory stores and never discover or read a real user library.

Prompt 10 extends the ignore and release-scan policy to the actual
`.bookatlasbackup` and `.xcresult` suffixes. The committed sample CSV and the
fixed-seed generator contain invented names and `example.invalid` destinations
only; generated large fixtures belong outside the repository.

## User control

The user must be able to inspect and edit records, explicitly initiate export and backup, cancel imports where practical, understand destructive consequences, and remove stored access to external files. Duplicate merging and restore operations require review and confirmation.

Duplicate normalization, scoring, candidate lookup, ignore decisions, previews, and merges run entirely on-device. Ignore storage contains only two book UUIDs, a disposition, and a timestamp; it does not duplicate titles, authors, notes, URLs, or relationship contents. Duplicate and merge errors shown to users are generic and do not expose stored payloads.

Merge preview renders concrete tags, collections, sources, external links, and relation details only in the local UI so the user can judge preservation outcomes. Those values are not emitted to logs. Test previews use fixed fictional records and `example.invalid` URLs in an isolated in-memory store.

Import previews render at most 20 selected-file rows only in the local UI; the full staged import remains in an app-controlled temporary directory and is removed on success, cancellation, failure, or replacement by a newer mapping. Confirmed execution may retain structured issue staging that omits raw rows and values; an error-report CSV is generated only after the user chooses where to save, and issue staging is deleted when discarded or exported. Markdown removes recognizable local absolute paths, CSV formula guards dangerous leading characters, and full backups intentionally contain private library data in an unencrypted SQLite snapshot; the user is responsible for protecting the selected destination.

The Prompt 8 graph reads only the current local database after the user chooses a center book. Titles, author strings, organization names, and manual-relation explanations remain in the local UI and accessibility tree; they are not logged, exported, transmitted, or copied into new persistence. Layout coordinates, filters, selection, and viewport state are transient. Performance and regression tests use only fixed fictional in-memory records.

Prompt 9 performs no reachability check, metadata fetch, or background dispatch. A search term or HTTPS destination leaves Book Atlas only after a visible user action and disclosure that an external application may process it. UI presents a validated ASCII host rather than a full private URL. Reading-entry state is bound to one book identity and generation; switching books clears previous rows before loading, and duplicate-candidate inspection uses a separate read-only state scope. Local-file access begins only for selection or an explicit open, refreshes stale authorization visibly, and balances every successful security-scope start with a stop. Opaque bookmark data is limited to 1 MiB per reference, and strict backup validation rejects an oversized length before allocating the BLOB. CSV and Markdown exclude external URLs, local paths, display names, and bookmark bytes; full backups necessarily preserve them as private library data.
