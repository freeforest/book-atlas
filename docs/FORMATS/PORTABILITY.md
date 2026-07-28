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

Parsing, mapping, and preview never write the library. Preview reports total/importable/warning/error rows, duplicate candidates, new organization names, displayed sample rows, mapping, and display truncation.

Confirmed import uses one SQLite transaction. Recoverable invalid rows are skipped and reported. Before each insert, the same Prompt 6 create-save Exact/Strong detector is run against the proposed record and records already inserted by this import. Any candidate causes that row to be skipped for later ordinary duplicate review; import never overwrites or merges. Broader Possible matching remains available in the ordinary manual duplicate-review flow and is not used to make batch import decisions. Fatal errors, injected failures, or cancellation roll back every write from that import.

An optional error report is itself UTF-8 CSV with stable columns `row,field,code,description,retryable`. It never contains the original row or private field value.

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

The manifest contains no original database path. A backup is moved from a controlled temporary location only after `PRAGMA integrity_check` returns `ok`, and an existing destination is never overwritten.

Restore requires a regular, non-symbolic-link `.bookatlasbackup` with the SQLite header, manifest version 1, a supported schema in 1–4, matching `PRAGMA user_version`, and a successful integrity check. Before replacement, Book Atlas creates and validates a separately retained recovery backup of the current library. The selected snapshot is staged, its manifest removed, and older supported schemas migrate through `1 → 2 → 3 → 4`. Replacement happens only after the live connection is closed; failure restores the original database and attempts to reopen it.

The application schema remains version 4. Prompt 7 introduces file-format versions, not a new persistence schema.
