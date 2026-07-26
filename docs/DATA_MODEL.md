# Conceptual data model

## Status

Prompt 3 turns the minimum library vocabulary into the committed production SQLite schema. It remains deliberately smaller than the long-term conceptual model: contributors are stored as a validated author string, while editions, ordered contributors, ratings, series, and duplicate resolution remain future work.

## Candidate concepts

### Book

A library record representing a work or edition as the user understands it. Candidate attributes include an internal identifier, title, optional subtitle, normalized title, publication details, identifiers such as ISBN, reading status, rating, dates, private notes, and audit timestamps.

The exact distinction between work and edition is deliberately unresolved. The first version must not claim to infer editions, translations, or series automatically.

### Author

The first production record stores one required, trimmed author string. It does not infer people, organizations, contributor roles, translations, or editions.

### Tag

A user-defined label linked many-to-many with books. Normalization and uniqueness behavior must be explicit and tested.

### Book collection

A named, user-maintained collection linked many-to-many with books. List membership may carry ordering only if a real product workflow requires it.

### Source

Where the user learned about or acquired a book. A source can have an optional user-entered URL or note. External URLs are private data and must not be logged.

### Relationship

An explicit, user-maintained edge between two books, such as “inspired by,” “responds to,” or “read with.” Relationship types, directionality, uniqueness, deletion behavior, and graph projection rules must be defined in Prompt 3 and Prompt 8.

### External link

An optional user-entered or verified integration destination. A stored link is not proof that another application can open a specific local-library item.

### Attachment reference

If future scope requires a local-file reference, store only the minimum metadata and permission bookmark needed. Book Atlas does not ingest ebook content in the first release.

## Production schema and persistence rules

The schema is owned by `BookAtlas/Persistence/LibraryRepository.swift` and is accessed only through `BookRepository`. The production database convention is `Application Support/BookAtlas/book-atlas.sqlite`; resolving that URL alone does not open it. The current application shell does not create or open a database yet.

- Schema version is recorded in both SQLite `user_version` and the append-only `schema_migrations` table.
- Version 1 creates `books`, `tags`, `book_tags`, `book_collections`, `book_collections_books`, `recommendation_sources`, `book_sources`, `external_links`, and `manual_book_relations`.
- Version 2 adds the optional `book_collections.description` field. Its existence provides a real, data-preserving forward-migration test rather than a disposable spike-only history.
- IDs are UUID text primary keys. Join tables use composite primary keys; required names are case-insensitively unique; relevant foreign keys use `ON DELETE CASCADE`; and indexes cover book status, title, author, ISBN, and reverse joins.
- ISBN is indexed but intentionally not globally unique: the user may keep different records that share an identifier.
- Manual relations are directed, unique by source/target/kind, and reject self-relations in both domain validation and a database check.
- Timestamps are UTC ISO-8601 strings with fractional seconds. Collection membership and all list queries use explicit deterministic orderings.
- Migrations run one version at a time inside `BEGIN IMMEDIATE` transactions. Failures roll back and surface an error; the store never deletes or silently rebuilds an existing database.

## General invariants to validate

- Stable internal identifiers do not depend on titles or file paths.
- Required text is trimmed and cannot be empty.
- Relationships cannot point to a missing endpoint; self-links and duplicate edges need an explicit rule.
- Deleting a book cannot leave orphaned join rows or graph edges.
- Merge operations preserve provenance and are transactional, reviewable, and covered by tests.
- User-entered strings, URLs, notes, paths, and identifiers are private by default.
- Timestamps and sorting rules use a defined locale-independent representation in persistence.

## Duplicate detection

No single field proves identity. Future detection may rank normalized identifiers and combinations of normalized title, contributors, publication data, and source information. It must present candidates, explain why they matched, avoid automatic destructive merging, and keep false-positive behavior testable.

## Schema evolution

Every later schema change must add a numbered forward migration and tests for successful preservation, repeat execution, and safe failure. Backup/restore compatibility must be specified before applying any later migration to user data. Prompt 1's spike migration is not reused; the production migration registry starts with the version-1 schema above and its version-2 collection-description migration.

## Test data

All fixtures must be deterministic and fictional. Approved example titles include 《雾港档案》, 《机器与花园》, 《星图索引》, 《静默算法》, and 《北岸来信》. Contributors, publishers, sources, lists, URLs, identifiers, and relationships must also be fictional.
