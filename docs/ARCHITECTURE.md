# Architecture

## Current state

Prompt 6 and Prompt 7 have passed independent acceptance. Prompt 7 adds versioned CSV import, mapping and preview, safe Markdown/CSV export, SQLite online backup, and validated interruption-safe restore; it was accepted at baseline `b27318c741fee5b4a66e5ad99cb979177285fef5`. Prompt 8's bounded graph projection, deterministic layout, native rendering, and accessible interaction are implemented and awaiting independent review. Prompt 9 external-link actions remain unimplemented.

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

The production registry currently advances from version 1 (core tables), through version 2 (collection descriptions), version 3 (query and ordering indexes), and version 4 (derived duplicate keys/tokens plus ignored-pair storage). Version 4 transactionally backfills existing books. The registry records versions in `schema_migrations` and `PRAGMA user_version`, rejects future versions, and never rebuilds a database after an error. The actor-isolated `LibraryCatalogService` translates editor drafts, review decisions, merge choices, and portability requests into repository use cases; SwiftUI executes no SQL, parsing, backup, restore, or merge rules.

`DuplicateDetectionEngine` is separate from persistence and centralizes confidence levels, thresholds, integer weights, readable evidence, and uncertainty. `BookRepository` uses ISBN, normalized field, original-title, and token indexes to bound candidate evaluation. Exact and Strong indexed lookups are uncapped and explicitly ordered by book ID. The broader Possible token lookup reads the first 250 book IDs in deterministic order plus one row to detect truncation; that state is returned through the catalog actor and disclosed by the review UI. `BookMergePolicy` creates previews and applies explicit field choices. The repository owns the single merge transaction, membership unions, link/relation deduplication and redirection, ignored-pair migration, and source deletion last. See accepted [ADR-0007](DECISIONS/0007-deterministic-duplicate-resolution.md).

## Query contract

`LibraryQuery` is the single input for library reads. Free text searches title, original title, author, and normalized ISBN. Different filter families combine with AND; multiple reading statuses combine with OR; multiple tags, collections, or sources within one family require all selected memberships. Sorting by created time, updated time, or priority always adds the book ID as a deterministic tie-breaker. SQLite work runs behind the catalog actor, and the main-actor store debounces text entry and rejects cancelled or stale responses.

## State and concurrency

UI state remains feature-sized: `LibraryStore` is scoped to catalog/editor/duplicate flow, `CatalogOrganizerStore` owns organization state, `PortabilityStore` owns file-operation presentation, and `GraphStore` owns graph request generations, filters, selection, and view-local coordinates. `StreamingCSVParser`, `LibraryImportCoordinator`, `LibraryExportCoordinator`, `BookAtlasSchemaValidator`, and `LibraryBackupCoordinator` separate parsing, disk staging, preview, transactional writes, serialization, application-schema validation, and SQLite file lifecycle. Import rows live in a controlled JSON-lines staging file; presentation retains aggregate statistics, at most 20 sample rows, and bounded issue details. A source/mapping fingerprint and operation generation prevent stale mapping tasks from publishing old state. SQLite and graph projection/layout work are serialized by the catalog actor instead of running in SwiftUI or on the main actor. That actor also publishes a process-local graph-content revision after graph-relevant mutations; graph generations discard stale center, filter, and older-revision results.

## Storage and sandboxing

The production database location is `Application Support/BookAtlas/book-atlas.sqlite`; tests use temporary or in-memory stores. Temporary import work belongs in system temporary storage and is cleaned on success, cancellation, supersession, and failure. Restore stages same-filesystem old/new databases next to the live path and persists a path-free recovery marker before closing the connection. Startup resolves any marker to a complete schema-valid live, old, or new database before constructing `BookRepository`; ambiguity stops opening instead of creating an empty store. Access outside the sandbox starts with `NSOpenPanel` or `NSSavePanel`. Prompt 7 uses transient, balanced security-scoped access and stores no bookmark; see [ADR-0008](DECISIONS/0008-versioned-portability-formats.md).

App Sandbox is the default. The production entitlement set is App Sandbox plus user-selected read/write files; no network or broad filesystem entitlement is present. Paths and user file content must not appear in logs.

## Graph rendering decision

The graph renderer is native asynchronous SwiftUI `Canvas` with a separate interaction model for hit testing, node dragging, panning, zooming, selection, and an accessible list representation; see [ADR-0004](DECISIONS/0004-bounded-canvas-graph.md). `LibraryGraphProjection` issues bounded indexed queries for the five supported relationship families. `LocalGraphBuilder` performs deterministic one- or two-layer traversal, merges concrete evidence into canonical edges, and enforces the configured bounds. `DeterministicGraphLayout` uses a fixed radial seed and at most 80 force iterations with cancellation checks. The default is 80 nodes/200 edges; hard configuration caps remain 250/500 and truncation is shown to the caller.

The graph remains an optional projection over library relationships; it cannot become the source of truth for books or persist view coordinates in bibliography entities. Re-centering performs a new projection. Re-entry preserves a loaded local layout only while the catalog revision is unchanged; book/organization/manual-relation changes, merge, import, and restore invalidate it. A missing former center clears the old graph and requires a new user selection. These behaviors use existing relational data and an in-memory invalidation token rather than a graph-specific migration.

## External integration decision

Only a user-initiated, allowlisted HTTPS URL may be handed to `NSWorkspace`; Apple Books store URLs are a labeled subset of that rule. Prompt 1 located and background-launched the installed Books app and dispatched a fictional public store search. It did not establish a supported custom `ibooks:` scheme or a way to open a specific item in a user's local Books library. Those behaviors remain unsupported and must degrade to a visible external-link action; see [ADR-0005](DECISIONS/0005-external-links-and-apple-books.md).

## Dependencies

Prefer Apple frameworks. A third-party dependency requires a concrete need, license and maintenance review, a small auditable footprint, and an ADR. Do not add project generators or parallel infrastructure merely for symmetry.

## Observability

Use Apple's unified logging where suitable. Logs are diagnostic metadata, not a mirror of the user's library: titles, authors, notes, paths, URLs, import rows, identifiers tied to private content, and bookmark bytes must be redacted or omitted.
