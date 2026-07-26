# ADR-0002: Direct SQLite persistence

- Status: Accepted
- Date: 2026-07-26
- Owners: Project maintainers

## Context

Book Atlas needs one local store with explicit schema versions, deterministic migrations, transactions, backups, and isolated tests. Prompt 1 compared the direction against SwiftData, Core Data, and a lightweight SQLite wrapper. The repository had no production schema or dependency before the experiment.

The direct system SQLite spike used only fictional data. It verified CRUD, a book-to-author many-to-many relation, a uniqueness constraint, cascade deletion, explicit rollback, independent in-memory stores, a version-1-to-2 migration, rollback of an intentionally failing version-3 migration, and an online backup that could be reopened. In one debug run it inserted 10,000 fictional records in 0.0592855 seconds, with a 2,686,976-byte resident-memory delta.

The SwiftData candidate proved an in-memory many-to-many relation only; it did not prove the production migration path. Core Data was reviewed as a viable Apple-framework alternative, but was not adopted because the first store needs an auditable SQL schema and migration registry. GRDB was reviewed but was neither downloaded nor linked because no concrete production feature yet needs a third-party wrapper.

## Decision

Use SQLite supplied by macOS through a small internal Swift persistence boundary. Prompt 3 will define the production schema, a migration registry using explicit integer versions, transaction ownership, error mapping, and repository interfaces. Backup will use SQLite's supported backup mechanism behind that boundary.

FTS5, sync, encryption beyond platform protections, and a third-party SQLite wrapper are not selected by this ADR. They require separate evidence and a new ADR if later needed.

## Alternatives considered

- **SwiftData:** useful for a small in-memory model probe, but its production migration behavior was not verified in this stage and it provides less direct control over the planned schema and backup workflow.
- **Core Data:** mature Apple technology, but not selected for the initial SQL-oriented migration and audit requirements.
- **GRDB or another wrapper:** can reduce C-API boilerplate, but adds a dependency, license/maintenance review, and supply-chain surface without a demonstrated need.

## Consequences

### Positive

- Schema, constraints, transactions, migrations, and backup behavior are explicit and testable.
- The production target gains no third-party persistence dependency.
- In-memory SQLite stores support fast, isolated fixtures.

### Negative or tradeoffs

- The project owns a focused Swift wrapper, SQL binding discipline, concurrency design, and migration tests.
- The 10,000-record debug insertion is a direction-setting datapoint, not a production performance guarantee.
- Prompt 3 must not copy the disposable spike schema into user data.

## Privacy and security

The store is local and introduces no network entitlement. Database contents, user titles, notes, paths, URLs, identifiers, backup locations, and SQL parameter values remain private and must not be logged. Backups and databases remain in application-controlled storage and are ignored by Git.

## Validation

Completed in `Experiments/TechnicalSpikes/` with fictional data:

```sh
CLANG_MODULE_CACHE_PATH=/tmp/bookatlas-swift-module-cache swift test --package-path Experiments/TechnicalSpikes --scratch-path /tmp/bookatlas-spike-build -Xswiftc -module-cache-path -Xswiftc /tmp/bookatlas-swift-module-cache
CLANG_MODULE_CACHE_PATH=/tmp/bookatlas-swift-module-cache swift run --package-path Experiments/TechnicalSpikes --scratch-path /tmp/bookatlas-spike-build -Xswiftc -module-cache-path -Xswiftc /tmp/bookatlas-swift-module-cache SpikeBenchmark
```

The test suite passed 13 tests on the recorded toolchain. Production schema, migration fixtures, query benchmarks, and backup/restore UX remain work for later prompts.
