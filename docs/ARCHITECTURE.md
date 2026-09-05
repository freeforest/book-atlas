# Architecture

## Current state

Prompts 6–10 have passed independent acceptance. Prompt 7 adds versioned CSV import, mapping and preview, safe Markdown/CSV export, SQLite online backup, and validated interruption-safe restore; it was accepted at baseline `b27318c741fee5b4a66e5ad99cb979177285fef5`. Prompt 8's bounded graph projection, deterministic layout, native rendering, and accessible interaction were accepted after its second independent review at baseline `6ae90dd50ee71f574e0b4cc1ffccfd7e4c2e71aa`. Prompt 9's Apple Books and external reading-entry work was accepted at baseline `1f7a35cda11fcafd23aacab0cb5c72e811327d0b` after an independent Debug build, 171/171 tests, and 26/26 UI tests passed. Prompt 10 passed independent acceptance at documentation baseline `ec0b04f1c004ef5c897d3269e335c92034d6021e`, against verified code baseline `4cc20b8c88cb674a4f9a52d3e8de70c295169281`; it changes no product scope or schema.

Prompt 11A has a local working-tree implementation for the manual-relation user
loop, but it is not controller-accepted: its required complete UI gate is
`BLOCKED` after the one permitted clean infrastructure retry. Prompt 11B
`BookKind` work is not part of this implementation.

V1.0.0 source-publication preparation sets the production deployment target
to macOS 26.0, marketing version 1.0.0, build number 1, and application bundle
identifier `io.github.freeforest.BookAtlas`. ADR-0009 supersedes ADR-0003. The
source-only policy adds no dependency, entitlement, network capability, or
binary-distribution architecture.

## Intended shape

Book Atlas will be one sandboxed native macOS application with a small number of focused layers:

- **Presentation:** SwiftUI screens and state scoped to a feature or navigation flow.
- **Domain:** testable entities, value types, validation, duplicate and merge rules, and use-case logic that does not depend on views.
- **Persistence:** one production local-store implementation, schema versions, migrations, and explicit transactions.
- **System integration:** small services for file selection, security-scoped bookmarks, workspace URL opening, logging, and other macOS capabilities.
- **Graph feature:** projections and layout/rendering concerns derived from domain data without adding view coordinates or graph-only state to core bibliography entities.

Dependencies should point from presentation and integrations toward explicit domain behavior. SwiftUI views must not perform complex SQL, migrations, file parsing, or merge decisions.

## Persistence decision

The production direction is direct SQLite through a small internal Swift store boundary; see [ADR-0002](DECISIONS/0002-direct-sqlite-persistence.md). `LibraryDomain.swift` contains entities and validation, `SQLiteDatabase.swift` is the focused SQLite wrapper, and `LibraryRepository.swift` owns all schema, migrations, CRUD, relationship, search, and transaction operations. SwiftUI imports none of that behavior.

The production registry currently advances from version 1 (core tables), through version 2 (collection descriptions), version 3 (query and ordering indexes), version 4 (derived duplicate keys/tokens plus ignored-pair storage), and version 5 (opaque local-file bookmark references). Version 4 transactionally backfills existing books; version 5 preserves all prior records and adds one cascading reference table plus its reverse index. The registry records versions in `schema_migrations` and `PRAGMA user_version`, rejects future versions, and never rebuilds a database after an error. The actor-isolated `LibraryCatalogService` translates editor drafts, review decisions, merge choices, portability requests, reading-entry CRUD, and manual-relation summary/create/delete requests into repository use cases; SwiftUI executes no SQL, parsing, backup, restore, bookmark, workspace, pasteboard, or merge rules.

`DuplicateDetectionEngine` is separate from persistence and centralizes confidence levels, thresholds, integer weights, readable evidence, and uncertainty. `BookRepository` uses ISBN, normalized field, original-title, and token indexes to bound candidate evaluation. Exact and Strong indexed lookups are uncapped and explicitly ordered by book ID. The broader Possible token lookup reads the first 250 book IDs in deterministic order plus one row to detect truncation; that state is returned through the catalog actor and disclosed by the review UI. `BookMergePolicy` creates previews and applies explicit field choices. The repository owns the single merge transaction, membership unions, link/relation deduplication and redirection, ignored-pair migration, and source deletion last. See accepted [ADR-0007](DECISIONS/0007-deterministic-duplicate-resolution.md).

## Query contract

`LibraryQuery` is the single input for library reads. Free text searches title, original title, author, and normalized ISBN. Different filter families combine with AND; multiple reading statuses combine with OR; multiple tags, collections, or sources within one family require all selected memberships. Sorting by created time, updated time, or priority always adds the book ID as a deterministic tie-breaker. Production reads return a `LibraryPage`: a bounded 200-row slice plus the exact filtered count and a derived `hasMore` state. Manual-relation target search reuses this contract with the source book excluded and exposes its exact count and next page instead of retaining the whole library in view state. The presentation stores append only explicitly requested pages, reset after relevant query or catalog changes, and preserve existing rows if a later page fails. SQLite work runs behind the catalog actor, and main-actor stores reject cancelled or stale responses.

## State and concurrency

UI state remains feature-sized: `LibraryStore` is scoped to catalog/editor/duplicate flow, `ManualRelationStore` owns one selected book's incoming/outgoing relation snapshot and target-search/create/delete state, `CatalogOrganizerStore` owns organization state, `PortabilityStore` owns file-operation presentation, and `GraphStore` owns graph request generations, filters, selection, and view-local coordinates. A book switch makes `ManualRelationStore` synchronously clear the old snapshot, cancel old work, advance its generation, and require both generation and `bookID` to match before publishing. `StreamingCSVParser`, `LibraryImportCoordinator`, `LibraryExportCoordinator`, `BookAtlasSchemaValidator`, and `LibraryBackupCoordinator` separate parsing, disk staging, preview, transactional writes, serialization, application-schema validation, and SQLite file lifecycle. Import rows live in a controlled JSON-lines staging file; presentation retains aggregate statistics, at most 20 sample rows, and bounded issue details. A source/mapping fingerprint and operation generation prevent stale mapping tasks from publishing old state. SQLite and graph projection/layout work are serialized by the catalog actor instead of running in SwiftUI or on the main actor. That actor also publishes a process-local graph-content revision after successful graph-relevant mutations; graph generations discard stale center, filter, and older-revision results.

Command-F navigation is an explicit presentation signal owned by
`LibraryStore`. A focused `NSViewRepresentable` contains the AppKit detail of
making the existing `NSSearchField` first responder.
Search text, debouncing, query cancellation, and persistence remain in their
existing store/catalog layers; the wrapper performs no query or database work.

## Storage and sandboxing

The production database location is `Application Support/BookAtlas/book-atlas.sqlite`; tests use temporary or in-memory stores. The existing-library performance entry accepts only an opaque UUID and supported fixed count, derives one controlled child of the process temporary root, rejects symlinks/non-regular files/unexpected artifacts, and opens its prepared database without create fallback; malformed performance arguments fail instead of resolving the production location. Temporary import work belongs in system temporary storage and is cleaned on success, cancellation, supersession, and failure. Restore stages same-filesystem old/new databases next to the live path and persists a path-free recovery marker before closing the connection. Startup resolves any marker to a complete schema-valid live, old, or new database before constructing `BookRepository`; ambiguity stops opening instead of creating an empty store. Access outside the sandbox starts with `NSOpenPanel` or `NSSavePanel`. Prompt 7 uses transient, balanced security-scoped access and stores no bookmark; Prompt 9 separately retains only opaque, read-only, app-scoped bookmark bytes for a file explicitly selected as a reading entry. It stores a safe basename rather than an absolute path, never reads file content, refreshes stale authorization, and pairs every successful access start with a stop; see [ADR-0006](DECISIONS/0006-sandboxed-file-access.md) and [ADR-0008](DECISIONS/0008-versioned-portability-formats.md).

App Sandbox is the default. The production entitlement set is App Sandbox, user-selected read/write files for explicit Prompt 7 operations, and app-scoped bookmarks for Prompt 9's long-lived read-only references. No network, Apple Events, automation, Downloads, or broad filesystem entitlement is present. Paths and user file content must not appear in logs.

The local Release configuration enables Hardened Runtime and disables base
entitlement injection, so the inspected ad-hoc product contains exactly that
three-item production set and no `get-task-allow`. Debug keeps
`get-task-allow` for testability. Distribution signing and notarization are not
applicable to the source-only V1.0.0 strategy; local signing and Hardened
Runtime remain engineering evidence only.

## Graph rendering decision

The graph renderer is native asynchronous SwiftUI `Canvas` with a separate interaction model for hit testing, node dragging, panning, zooming, selection, and an accessible list representation; see [ADR-0004](DECISIONS/0004-bounded-canvas-graph.md). `LibraryGraphProjection` issues bounded indexed queries for the five supported relationship families. `LocalGraphBuilder` performs deterministic one- or two-layer traversal, merges concrete evidence into canonical edges, and enforces the configured bounds. `DeterministicGraphLayout` uses a fixed radial seed and at most 80 force iterations with cancellation checks. The default is 80 nodes/200 edges; hard configuration caps remain 250/500 and truncation is shown to the caller.

The graph remains an optional projection over library relationships; it cannot become the source of truth for books or persist view coordinates in bibliography entities. Re-centering performs a new projection. Re-entry preserves a loaded local layout only while the catalog revision is unchanged; book/organization/manual-relation changes, merge, import, and restore invalidate it. A missing former center clears the old graph and requires a new user selection. These behaviors use existing relational data and an in-memory invalidation token rather than a graph-specific migration.

## External integration decision

Only a user-initiated, 2,048-UTF-8-byte-bounded, credential-free HTTPS URL with a deterministic ASCII host may be handed to `NSWorkspace`; every stored URL is validated again immediately before dispatch, and Apple Books store URLs are a labeled `books.apple.com` subset. Validation rejects raw or one-pass percent-decoded C0/DEL controls, malformed percent encoding, and explicit ports unless the authority contains only decimal digits in `1...65535`; empty, signed, nondigit, zero, and over-range ports are rejected before `URLComponents` normalization can erase the distinction. Unicode/IDN and punycode hosts are rejected rather than displayed ambiguously. Focused replaceable interfaces isolate validation, workspace dispatch, Apple Books launch, pasteboard writes, file selection, and bookmark lifecycle from `ReadingEntryStore` and SwiftUI.

`ReadingEntryStore` binds every published snapshot and operation to one `bookID`. A book change increments a load generation, cancels the old task, clears old rows before loading, and publishes success, empty, or error state only when cancellation, generation, and book identity still match. Row actions additionally require the row identity to exist in that book-scoped snapshot. The main book detail and duplicate-candidate preview use separate stores; the candidate preview is explicitly read-only and resets on return, so it cannot replace the main detail's state.

The duplicate-review presentation hierarchy has one Escape owner. A single `DuplicateReviewSheet` monitor routes the event according to its current child state; candidate detail and merge preview do not stack global monitors or `onExitCommand` handlers. While duplicate review exists, the parent `BookEditorSheet` yields Escape ownership. The first Escape from a candidate detail returns only to duplicate review; the next cancels duplicate review and returns to the editor with its draft intact.

Schema 5 local-file bookmarks are domain-bounded to 1 MiB per record. Creation, stale refresh, re-selection, repository decoding, backup inspection, staged validation, installed-file validation, and startup recovery all share that limit. Strict validation first queries `length(bookmark_data)` and rejects an empty or oversized row before reading the BLOB, then streams valid rows one at a time. Stored display names are accepted only when the raw value is already canonical: nonempty, at most 512 characters, no C0/DEL controls, no leading/trailing whitespace, no slash or backslash, and not `.` or `..`.

The deterministic Apple Books degradation order is: a saved validated store URL, an explicitly confirmed public search, application launch by bundle identifier, ISBN copy, title copy, then another saved HTTPS entry. Prompt 1 did not establish a supported custom `ibooks:` scheme or a way to open a specific item in a user's local Books library. Those capabilities remain respectively unverified and unsupported; no code reads or changes the private Apple Books library. See [ADR-0005](DECISIONS/0005-external-links-and-apple-books.md).

## Dependencies

Prefer Apple frameworks. A third-party dependency requires a concrete need, license and maintenance review, a small auditable footprint, and an ADR. Do not add project generators or parallel infrastructure merely for symmetry.

## Observability

Use Apple's unified logging where suitable. Logs are diagnostic metadata, not a mirror of the user's library: titles, authors, notes, paths, URLs, import rows, identifiers tied to private content, and bookmark bytes must be redacted or omitted.
