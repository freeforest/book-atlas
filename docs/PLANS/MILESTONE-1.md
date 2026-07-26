# Milestone 1 — library core

## Goal

Implement a testable domain model and one production local persistence path with explicit schema versioning.

## Stage

- Prompt 3: completed — entities and value rules, one SQLite repository/use-case boundary, schema versions 1 and 2, deterministic fictional fixtures, and unit/integration tests.

The standalone Prompt 3 text calls this work “Milestone 2”, while the repository roadmap assigns Prompt 3 to Milestone 1. This plan follows the repository roadmap; the next prompt remains Prompt 4 / Milestone 2.

## Gates

- Persistence follows the Prompt 1 ADR; there is no second production store.
- SwiftUI does not contain persistence logic.
- Constraints, transactions, deletion behavior, and migration failure are tested using temporary or in-memory data.
- No real user data enters tests or the repository.

## Completion record

- `BookAtlas/Domain/LibraryDomain.swift` defines the minimal book, tag, collection, source, external-link, and manual-relation values with validation.
- `BookAtlas/Persistence/LibraryRepository.swift` contains the versioned schema, transactional migrator, repository CRUD, relationship operations, keyword search, and explicit transactions.
- Tests use only in-memory SQLite and five deterministic fictional titles. They cover invalid domain values, CRUD, status filtering, safe keyword matching, relationship lifecycle, cascade behavior, transaction rollback, migration preservation/idempotence, failed-migration rollback, and future-version rejection.
- No SwiftUI view, import/export implementation, network feature, second store, or production database instance was added.
