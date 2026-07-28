# Conceptual data model

## Status

Prompt 3 established the production SQLite schema, Prompt 5 activated organization and unified queries, and Prompt 6 adds derived duplicate keys, ignored candidate pairs, and transactional record merging. The model remains deliberately smaller than a work/edition authority model: contributors are still an ordered free-form author string, and the app does not infer complete edition, translation, or series structure.

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

An explicit, user-maintained edge between two books, such as “inspired by,” “responds to,” or “read with.” The current schema defines directed, unique, non-self relationships with cascading endpoint deletion. Prompt 8 must define the user-facing relationship vocabulary and graph projection rules before exposing this concept in the production UI.

### External link

An optional user-entered or verified integration destination. A stored link is not proof that another application can open a specific local-library item.

### Attachment reference

If future scope requires a local-file reference, store only the minimum metadata and permission bookmark needed. Book Atlas does not ingest ebook content in the first release.

## Production schema and persistence rules

The schema is owned by `BookAtlas/Persistence/LibraryRepository.swift` and is accessed only through `BookRepository`. The production application opens `Application Support/BookAtlas/book-atlas.sqlite`; XCTest and explicit UI-test launches use an in-memory store.

- Schema version is recorded in both SQLite `user_version` and the append-only `schema_migrations` table.
- Version 1 creates `books`, `tags`, `book_tags`, `book_collections`, `book_collections_books`, `recommendation_sources`, `book_sources`, `external_links`, and `manual_book_relations`.
- Version 2 adds the optional `book_collections.description` field. Its existence provides a real, data-preserving forward-migration test rather than a disposable spike-only history.
- Version 3 adds indexes for original-title lookup and deterministic created, updated, and priority orderings without rewriting book rows.
- Version 4 adds `book_duplicate_keys`, `book_duplicate_title_tokens`, and `ignored_duplicate_pairs`; migration backfills derived keys/tokens for existing rows inside the version transaction.
- IDs are UUID text primary keys. Join tables use composite primary keys; required names are case-insensitively unique; relevant foreign keys use `ON DELETE CASCADE`; and indexes cover book status, title, author, ISBN, and reverse joins.
- ISBN is indexed but intentionally not globally unique: the user may keep different records that share an identifier.
- Duplicate keys contain only derived ISBN/title/author/original-title values. Ignored pairs contain two canonical book UUIDs, one of `not_duplicate`, `separate_edition`, or `separate_translation`, and a timestamp. Identity-bearing edits invalidate affected ignored pairs.
- Manual relations are directed, unique by source/target/kind, and reject self-relations in both domain validation and a database check.
- Timestamps are UTC ISO-8601 strings with fractional seconds. Collection membership and all list queries use explicit deterministic orderings.
- Migrations run one version at a time inside `BEGIN IMMEDIATE` transactions. Failures roll back and surface an error; the store never deletes or silently rebuilds an existing database.

## Query and organization semantics

- Free-text matching covers title, original title, author, and ISBN. User whitespace is collapsed, `%` and `_` are escaped as literals, ISBN search ignores spaces and hyphens, and current text matching follows SQLite `NOCASE` behavior.
- Filter families combine with AND. Reading statuses within their family combine with OR. Selected tags, collections, and sources within each family use all-of semantics.
- Created-time, updated-time, and priority sorting use a stable `id ASC` tie-breaker. Missing priorities sort after assigned priorities.
- Tag, collection, and source names collapse surrounding/repeated whitespace and are unique under case- and diacritic-insensitive comparison.
- Membership join tables prevent duplicates. Deleting organization metadata removes only its joins; books remain. Tag merge inserts missing target memberships, removes the source, and rolls back as one transaction on failure.

## General invariants to validate

- Stable internal identifiers do not depend on titles or file paths.
- Required text is trimmed and cannot be empty.
- Relationships cannot point to a missing endpoint; self-links and duplicate edges need an explicit rule.
- Deleting a book cannot leave orphaned join rows or graph edges.
- Merge operations preserve provenance and are transactional, reviewable, and covered by tests.
- User-entered strings, URLs, notes, paths, and identifiers are private by default.
- Timestamps and sorting rules use a defined locale-independent representation in persistence.

## Duplicate detection and merge

Valid equal ISBN values are Exact. Equal normalized title and ordered author text without explicit ISBN/original-title conflict is Strong. Possible candidates use centralized integer weights for title-token overlap, author, original title, publisher, nearby publication year, edition hints, and conflicting valid ISBN. Different valid ISBN values cannot become Exact or Strong. Every candidate exposes evidence and uncertainty, and no confidence level causes automatic deletion or merge. Exact and Strong indexed lookups have no count cap. Possible token lookup is ordered by book UUID and capped at 250 raw index hits; a 251st hit sets an explicit truncation flag that the review state presents to the user.

An ignored decision belongs to exactly one canonical UUID pair. When a newly created record has several candidates, the first decision creates that record once and suppresses only the selected pair; the saved record becomes the subject for the remaining review.

Merge retains the chosen target UUID, takes the earlier `createdAt`, writes the merge time to `updatedAt`, and uses explicit choices for conflicting scalar fields. The preview lists both records' concrete tags, collections, sources, links, and directed manual relations with keep/add/deduplicate/fill/block outcomes. Tags, collections, sources, and links are unioned; duplicate associations are removed; manual relations are redirected or deduplicated; self-relations, lossy relation-note conflicts, and equal links with different nonempty labels stop the operation. An empty target link label may be filled from the source, and equal labels deduplicate safely. The source book is deleted last in the same transaction. A successful merge therefore leaves one book identity for future graph projection; an explicit keep-separate choice leaves both identities.

## Schema evolution

Every later schema change must add a numbered forward migration and tests for successful preservation, repeat execution, and safe failure. Backup/restore compatibility must be specified before applying any later migration to user data. Prompt 1's spike migration is not reused; the production registry currently ends at version 4.

## Test data

All fixtures must be deterministic and fictional. Approved example titles include 《雾港档案》, 《机器与花园》, 《星图索引》, 《静默算法》, and 《北岸来信》. Contributors, publishers, sources, lists, URLs, identifiers, and relationships must also be fictional.
