# Milestone 1 — library core

## Goal

Implement a testable domain model and one production local persistence path with explicit schema versioning.

## Stage

- Prompt 3: entities and value rules, persistence repositories/use cases, schema version 1, migrations, deterministic fictional fixtures, and unit/integration tests.

## Gates

- Persistence follows the Prompt 1 ADR; there is no second production store.
- SwiftUI does not contain persistence logic.
- Constraints, transactions, deletion behavior, and migration failure are tested using temporary or in-memory data.
- No real user data enters tests or the repository.

