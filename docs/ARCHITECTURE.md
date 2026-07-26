# Architecture

## Current state

Milestone 2 contains a production application skeleton, a testable library domain, one local SQLite persistence path, and a usable searchable catalog flow. Prompt 1 recorded accepted decisions, Prompt 2 added an App Sandbox-enabled SwiftUI shell, Prompt 3 added the migration registry and repository boundary, Prompt 4 added book CRUD presentation, and Prompt 5 added unified queries and catalog organization. Import/export, duplicate merge, graph implementation, and external-link actions remain unimplemented.

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

The production registry currently advances from version 1 (core tables), through version 2 (collection descriptions), to version 3 (query and ordering indexes). It records versions in `schema_migrations` and `PRAGMA user_version`, applies each migration transactionally, rejects future versions, and never rebuilds a database after an error. The application opens its one production database at the documented Application Support location; test launches use an in-memory repository. The actor-isolated `LibraryCatalogService` translates editor drafts and catalog actions into repository use cases, while feature-scoped stores own presentation state, stale-request replacement, debounce, selection, forms, confirmations, and generic errors. SwiftUI views do not execute SQL. Repeatable 1,000-, 5,000-, and 10,000-book baselines did not justify FTS5, so it remains deferred.

## Query contract

`LibraryQuery` is the single input for library reads. Free text searches title, original title, author, and normalized ISBN. Different filter families combine with AND; multiple reading statuses combine with OR; multiple tags, collections, or sources within one family require all selected memberships. Sorting by created time, updated time, or priority always adds the book ID as a deterministic tie-breaker. SQLite work runs behind the catalog actor, and the main-actor store debounces text entry and rejects cancelled or stale responses.

## State and concurrency

UI state remains feature-sized: `LibraryStore` is scoped to the catalog screen and editor flow, while `CatalogOrganizerStore` owns metadata and membership presentation. SQLite reads and writes are serialized by an actor-backed service instead of running in SwiftUI or on the main actor. Future long-running import, export, backup, graph layout, and migration work must retain explicit background boundaries.

## Storage and sandboxing

The future production database location is `Application Support/BookAtlas/book-atlas.sqlite`. Temporary work belongs in system temporary storage and should be cleaned safely. Access outside the sandbox starts with a user-selected URL and, when long-term access is needed, uses a read-only, app-scoped security-scoped bookmark; see [ADR-0006](DECISIONS/0006-sandboxed-file-access.md).

App Sandbox is the default. The verified experiment entitlement set is App Sandbox, user-selected read-only files, and app-scoped bookmarks. The application will not request the network client entitlement by default. Bookmark bytes, paths, and user file content must not appear in logs.

## Graph rendering decision

The initial graph renderer will be native SwiftUI `Canvas` with a separate interaction model for hit testing, node dragging, panning, zooming, and an accessible list representation; see [ADR-0004](DECISIONS/0004-bounded-canvas-graph.md). Prompt 1 hosted and laid out the canvas with fictional 50-, 100-, and 250-node fixtures. The initial visible-node cap is 250 until Prompt 8 measures real frame timing and accessibility behavior.

The graph remains an optional projection over library relationships; it cannot become the source of truth for books or persist view coordinates in bibliography entities.

## External integration decision

Only a user-initiated, allowlisted HTTPS URL may be handed to `NSWorkspace`; Apple Books store URLs are a labeled subset of that rule. Prompt 1 located and background-launched the installed Books app and dispatched a fictional public store search. It did not establish a supported custom `ibooks:` scheme or a way to open a specific item in a user's local Books library. Those behaviors remain unsupported and must degrade to a visible external-link action; see [ADR-0005](DECISIONS/0005-external-links-and-apple-books.md).

## Dependencies

Prefer Apple frameworks. A third-party dependency requires a concrete need, license and maintenance review, a small auditable footprint, and an ADR. Do not add project generators or parallel infrastructure merely for symmetry.

## Observability

Use Apple's unified logging where suitable. Logs are diagnostic metadata, not a mirror of the user's library: titles, authors, notes, paths, URLs, import rows, identifiers tied to private content, and bookmark bytes must be redacted or omitted.
