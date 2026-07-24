# Architecture

## Current state

Milestone 0 contains no application implementation. This document defines boundaries to test, not a completed architecture. Prompt 1 must validate the uncertain choices; accepted choices must be recorded as ADRs before production implementation.

## Intended shape

Book Atlas will be one sandboxed native macOS application with a small number of focused layers:

- **Presentation:** SwiftUI screens and state scoped to a feature or navigation flow.
- **Domain:** testable entities, value types, validation, duplicate and merge rules, and use-case logic that does not depend on views.
- **Persistence:** one production local-store implementation, schema versions, migrations, and explicit transactions.
- **System integration:** small services for file selection, security-scoped bookmarks, workspace URL opening, logging, and other macOS capabilities.
- **Graph feature:** projections and layout/rendering concerns derived from domain data without adding view coordinates or graph-only state to core bibliography entities.

Dependencies should point from presentation and integrations toward explicit domain behavior. SwiftUI views must not perform complex SQL, migrations, file parsing, or merge decisions.

## Persistence decision pending

Prompt 1 will compare a single primary SQLite approach with SwiftData, Core Data, and a reliable lightweight SQLite wrapper. The comparison must consider:

- explicit schema versioning and deterministic migrations;
- transaction and backup behavior;
- test isolation and fixture setup;
- query/search needs around 10,000 fictional books;
- maintainability with the verified deployment target;
- dependency cost and auditability.

No production code will maintain two databases. FTS5 is optional and must be justified by measured needs. The conceptual model in `DATA_MODEL.md` does not imply a storage API or schema.

## State and concurrency

UI state should remain feature-sized. Long-running import, export, backup, graph layout, and migration work must not block the main actor. Concurrency boundaries and store isolation will be chosen only after the toolchain and persistence experiments.

## Storage and sandboxing

Production data is expected under the application-specific macOS Application Support directory. Temporary work belongs in system temporary storage and should be cleaned safely. Access outside the sandbox starts with a user-selected URL and, when long-term access is needed, uses a security-scoped bookmark only after Prompt 1 validates the lifecycle.

App Sandbox is the default. The application will not request the network client entitlement by default. Entitlements must be minimal, documented, and verified.

## Graph rendering decision pending

Prompt 1 will test a bounded local graph using native SwiftUI Canvas, gestures, and only necessary AppKit. The experiment must measure interaction and rendering with fictional data. The graph remains an optional view over library relationships; it cannot become the source of truth for books.

## External integration decision pending

Opening ordinary user-approved URLs through supported macOS APIs may be feasible. Any Apple Books URL scheme, deep link, or ability to identify a specific item in a user's library must be supported by current official documentation or a reproducible experiment and recorded in an ADR. Unsupported behavior must degrade to a safe, visible alternative.

## Dependencies

Prefer Apple frameworks. A third-party dependency requires a concrete need, license and maintenance review, a small auditable footprint, and an ADR. Do not add project generators or parallel infrastructure merely for symmetry.

## Observability

Use Apple's unified logging where suitable. Logs are diagnostic metadata, not a mirror of the user's library: titles, authors, notes, paths, URLs, import rows, identifiers tied to private content, and bookmark bytes must be redacted or omitted.

