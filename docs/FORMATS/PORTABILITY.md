# Book Atlas portability formats

## CSV format `bookatlas-csv/1`

Encoding is UTF-8; an optional UTF-8 BOM is accepted. Records follow RFC-style CSV rules: comma separator, double-quote enclosure, doubled quotes, CRLF or LF records, and embedded newlines inside quoted fields.

The stable export order is:

```text
format_version,title,original_title,author,isbn,publisher,publication_date,kind,reading_status,priority,note,started_at,finished_at,tags,collections,sources
```

`format_version`, `title`, and `author` are required. The version value is `bookatlas-csv/1`. Other columns are optional and unknown columns are ignored after the user reviews the mapping. Column order may change. `publication_date` is `YYYY`, `YYYY-MM`, or `YYYY-MM-DD`; timestamps use the same UTC ISO-8601 representation as SQLite persistence. `kind`, `reading_status`, and priority use the documented domain raw values.

Tags, collections, and sources are pipe-separated within one CSV cell. Backslash escapes a pipe or backslash (`\|`, `\\`). Repeated names in a row and existing associations are deduplicated by catalog name rules.

Import limits are 100 MiB per file, 100,000 data rows, 1 MiB per field, 128 columns, and 20 displayed sample rows. Exceeding a parser safety limit is a fatal parse error. The preview's “limited” flag refers to the displayed 20-row sample; confirmed execution still considers every successfully parsed row.

### Formula-injection protection

CSV export prefixes a single apostrophe when a cell begins with `=`, `+`, `-`, `@`, tab, or carriage return. A source value beginning with an apostrophe is prefixed with another apostrophe. The version-1 importer removes exactly those guards, preserving Book Atlas CSV round trips without losing the original leading character. CSV quoting and formula guarding are separate operations.

### Import behavior

Parsing, mapping, and preview never write the library. The selected file is streamed into an app-controlled temporary JSON-lines staging file; SwiftUI receives only aggregate counts, at most 20 sample rows, and at most 80 issue details. Staging metadata binds the records to a random operation token, the source-content fingerprint, the exact field-mapping fingerprint, headers, and row count. Changing the mapping creates a new generation and stale results cannot replace the newest preview. Success, cancellation, mapping replacement, and failure remove superseded staging directories. If the row sample or issue-detail sample is truncated, the preview says so while its aggregate counts still cover every parsed row.

Preview evaluates valid rows in CSV order with the Prompt 6 Exact/Strong rules against both the current library and an isolated temporary batch index containing only earlier rows expected to import. It labels a warning as either `duplicate_existing_library` or `duplicate_current_batch` (including the earlier CSV line). A duplicate row is excluded from importable and new tag/list/source forecasts; no ignored pair, merge, or pending-review record is created.

Confirmed import streams the validated staging file inside one SQLite transaction. Recoverable invalid rows are skipped and reported. Before each insert, the Exact/Strong detector runs again against current transactional state, so changes after preview and earlier inserts in the batch cannot bypass duplicate protection. A newly found candidate is skipped with `duplicate_at_execution`; import never overwrites or merges. Skipped import rows do **not** appear automatically in the ordinary duplicate-review screen because no book identity was created. The user may correct the CSV or add the record through the ordinary create flow if review is wanted. Broader Possible matching remains a manual-review operation and is not used to make import decisions. Fatal errors, injected failures, or cancellation roll back every write from that import.

Only the confirmed execution result can offer an error report. Actual issues are first retained as app-controlled JSON-lines staging—not as a user report—and contain no original row or private field value. Only after the user chooses a non-existing save destination does Book Atlas stream that staging into a UTF-8 CSV report with stable columns `row,field,code,description,retryable`, including execution issues such as `duplicate_at_execution`. Dismissing or exporting the result deletes the controlled issue staging.

## Markdown format `bookatlas-markdown/1`

Markdown starts with its format version and UTC export time, then contains each book's bibliographic fields, reading state, dates, tags, collections, sources, and note. Markdown control characters are escaped, multiline values use `<br>`, and absolute local path patterns are replaced by a local-path omission marker. External links and authorization values are not exported. Book Atlas does not execute links or automatically open the output.

## Backup format version 1

A `.bookatlasbackup` is one complete SQLite snapshot made through `sqlite3_backup`, not a copy of the live main file and not a ZIP archive. The completed snapshot uses single-file DELETE journal mode and contains `_bookatlas_backup_manifest` with exactly one row:

```text
format_version INTEGER
schema_version INTEGER
application_version TEXT
created_at TEXT
```

The manifest contains no original database path. A backup is moved from a controlled temporary location only after physical and Book Atlas application-schema validation succeeds, and an existing destination is never overwritten. Backup files are capped at 4 GiB. The live database size is checked before `sqlite3_backup`; restore selection checks the backup's regular-file size before opening it or running an expensive integrity check.

Restore requires a regular, non-symbolic-link `.bookatlasbackup` with the SQLite header, manifest version 1, a supported schema in 1–4, matching `PRAGMA user_version`, and a successful application-schema check. That check requires `schema_migrations` to contain exactly every version through `user_version`; verifies the exact versioned set of tables, ordered required columns, primary keys, unique keys, foreign keys, cascade actions, and critical checks; requires `PRAGMA foreign_key_check` to return no rows; and decodes every book, organization, join, external link, manual relation, duplicate index/token row, and ignored pair through domain types. Invalid UUIDs, dates, enums, normalized duplicate keys, orphaned rows, or missing structures are rejected.

The versioned object whitelist requires these ordinary indexes with non-unique, ascending keys and the declared column order:

- schema 1: `idx_books_reading_status(reading_status)`, `idx_books_title(title)`, `idx_books_author(author)`, `idx_books_isbn(isbn)`, `idx_book_tags_tag_id(tag_id)`, `idx_collection_books_book_id(book_id)`, `idx_book_sources_source_id(source_id)`, `idx_external_links_book_id(book_id)`, `idx_manual_relations_source(source_book_id)`, and `idx_manual_relations_target(target_book_id)`;
- schema 3 additionally: `idx_books_original_title(original_title)`, `idx_books_created_order(created_at,id)`, `idx_books_updated_order(updated_at,id)`, and `idx_books_priority_order(priority,id)`;
- schema 4 additionally: `idx_duplicate_keys_isbn(valid_isbn)`, `idx_duplicate_keys_title_author(normalized_title,normalized_author)`, `idx_duplicate_keys_original_title(normalized_original_title)`, `idx_duplicate_title_tokens_token(token,book_id)`, and `idx_ignored_duplicate_pairs_second(second_book_id)`.

Schema 1–3 allow no trigger. Schema 4 requires exactly one trigger, `invalidate_ignored_duplicate_pairs_after_identity_update`, with the formal migration body: after any effective update to title, original title, author, ISBN, publisher, or publication date, delete every ignored pair containing that book. All versions allow no view. Unknown user tables, ordinary indexes, triggers, and views are rejected; `_bookatlas_backup_manifest` is the sole inspection-only auxiliary table. Index name alone is insufficient: table, uniqueness, origin, partial status, ordered key columns, direction, and collation are checked. The same validator runs during inspection, after staged migration, against the installed database before reconnect, and for startup recovery candidate selection.

Before replacement, Book Atlas creates and validates a separately retained recovery backup of the current library. The selected snapshot is staged in the live database's filesystem, its manifest removed, and older supported schemas migrate through `1 → 2 → 3 → 4`. Restore preflights available capacity before the recovery copy, staging, and replacement; Cocoa out-of-space, POSIX `ENOSPC`, and SQLite `FULL` errors map to one insufficient-space result.

Inspection, recovery-copy creation, staging, and migration are cancellable and leave the formal library unchanged. The background operation owns the authoritative phase and cancellation permission. A request in a cancellable phase changes the UI to “正在安全取消恢复…” but does not claim success; only the coordinator's confirmed `cancelled` result produces “已取消且书库未更改。” The phase transition into safe replacement and cancellation acceptance share one lock, so exactly one wins. Once safe replacement wins, delayed UI phase delivery cannot cancel or invalidate that restore, Cancel/Escape stay ineffective, and the final success or real failure remains publishable. Delayed callbacks from an old operation cannot overwrite completion or failure.

Immediately before replacement the UI enters a visible non-cancellable “safe replacement” phase and disables Cancel and Escape. Book Atlas checkpoints the actor-isolated live connection, then persists a path-free recovery-state marker containing only a token, schema version, and randomized relative old/new filenames. It then closes the connection, moves the old complete file aside, installs the new complete file, validates, and reconnects. On the next launch, a remaining marker deterministically chooses a valid formal database first, otherwise the valid old database, otherwise the valid staged database; it never opens the normal repository while the formal path is transiently absent. Ambiguous or wholly invalid evidence stops editing and presents recovery guidance. Successful recovery or ordinary rollback clears the marker and controlled old/new files while retaining the separately verified recovery backup.

The application schema remains version 4. Prompt 7 introduces file-format versions, not a new persistence schema.
