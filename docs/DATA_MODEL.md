# Conceptual data model

## Status

Prompt 3 established the production SQLite schema, Prompt 5 activated organization and unified queries, and Prompt 6 added derived duplicate keys, ignored candidate pairs, and transactional record merging. Independently accepted Prompt 7 adds versioned interchange and snapshot formats without changing the production schema. Independently accepted Prompt 8 adds only a read-only graph projection over Schema 4. Prompt 9 advances the current production schema to 5 solely for opaque local-file references; the model remains deliberately smaller than a work/edition authority model.

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

An explicit, user-maintained edge between two books: `related`, `inspired_by`, `responds_to`, or `companion`. The current schema defines directed, unique, non-self relationships with cascading endpoint deletion. The graph preserves direction, relation kind, endpoint identities, and whether a note exists in its evidence; private note text is not copied into graph state.

### Graph projection

`GraphNode`, `GraphEdge`, `GraphSnapshot`, `GraphRelationEvidence`, `GraphBuildOptions`, and `GraphContentRevision` are transient domain values, not persistence records. The revision is a monotonic process-local invalidation token embedded in each scene; it does not alter Schema 4. A canonical undirected display edge may combine five independently readable evidence families: exact same author string, shared tag, shared collection, shared recommendation source, and directed manual relation. Concrete names and manual endpoint/direction metadata remain available for explanation and accessibility. Self-edges and duplicate evidence are removed.

The default projection is one relationship layer, with an optional second layer. It defaults to 80 nodes/200 edges and has hard caps of 250/500. Candidates are ordered by computed weight, title, and UUID; repository queries use explicit count/UUID/name orderings and expose truncation. Weight contributions are manual 100–120, same author 80, shared collections 40–60, shared sources 35–50, and shared tags 20 each up to 60, with the combined edge capped at 250. These values rank and draw a local projection only; they do not assert semantic truth or alter stored data.

### External link

An optional user-entered or verified integration destination. A stored link is not proof that another application can open a specific local-library item.

### Local file reference

A user-selected local reading entry contains a stable reference UUID, owning book UUID, canonical safe display basename, opaque read-only app-scoped bookmark bytes, and creation/update timestamps. The display name is stored only if it is already nonempty, trimmed, free of C0/DEL controls and path separators, not `.`/`..`, and at most 512 characters. Bookmark data must contain 1 through 1,048,576 bytes. It never uses an absolute path as identity and does not ingest, inspect, index, or modify ebook content.

## Production schema and persistence rules

The schema is owned by `BookAtlas/Persistence/LibraryRepository.swift` and is accessed only through `BookRepository`. The production application opens `Application Support/BookAtlas/book-atlas.sqlite`; XCTest and explicit UI-test launches use an in-memory store.

- Schema version is recorded in both SQLite `user_version` and the append-only `schema_migrations` table.
- Version 1 creates `books`, `tags`, `book_tags`, `book_collections`, `book_collections_books`, `recommendation_sources`, `book_sources`, `external_links`, and `manual_book_relations`.
- Version 2 adds the optional `book_collections.description` field. Its existence provides a real, data-preserving forward-migration test rather than a disposable spike-only history.
- Version 3 adds indexes for original-title lookup and deterministic created, updated, and priority orderings without rewriting book rows.
- Version 4 adds `book_duplicate_keys`, `book_duplicate_title_tokens`, and `ignored_duplicate_pairs`; migration backfills derived keys/tokens for existing rows inside the version transaction.
- Version 5 adds `local_file_references` plus `idx_local_file_references_book_id`. A reference has a UUID primary key, a cascading book foreign key, nonempty bounded safe display name, nonempty opaque bookmark BLOB, and timestamps. The 1 MiB bookmark ceiling and canonical display-name rule are application/domain validation constraints shared by normal reads and restore validation; they do not redefine the accepted Schema 5 DDL, so no Schema 6 migration is introduced.
- IDs are UUID text primary keys. Join tables use composite primary keys; required names are case-insensitively unique; relevant foreign keys use `ON DELETE CASCADE`; and indexes cover book status, title, author, ISBN, and reverse joins.
- ISBN is indexed but intentionally not globally unique: the user may keep different records that share an identifier.
- Duplicate keys contain only derived ISBN/title/author/original-title values. Ignored pairs contain two canonical book UUIDs, one of `not_duplicate`, `separate_edition`, or `separate_translation`, and a timestamp. Identity-bearing edits invalidate affected ignored pairs.
- Manual relations are directed, unique by source/target/kind, and reject self-relations in both domain validation and a database check.
- Timestamps are UTC ISO-8601 strings with fractional seconds. Collection membership and all list queries use explicit deterministic orderings.
- Migrations run one version at a time inside `BEGIN IMMEDIATE` transactions. Failures roll back and surface an error; the store never deletes or silently rebuilds an existing database.
- Prompt 8 retained Schema 4. Prompt 9's complete path is `1 → 2 → 3 → 4 → 5`; graph positions, zoom, pan, selection, and filters are never stored in SQLite.

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

Merge retains the chosen target UUID, takes the earlier `createdAt`, writes the merge time to `updatedAt`, and uses explicit choices for conflicting scalar fields. The preview lists both records' concrete tags, collections, sources, links, local-file display names, and directed manual relations with keep/add/deduplicate/fill/block outcomes. Tags, collections, sources, and links are unioned; duplicate associations are removed; every opaque local-file reference is preserved and reassigned because a display name is not file identity; manual relations are redirected or deduplicated. Self-relations, lossy relation-note conflicts, and equal links with different nonempty labels stop the operation. An empty target link label may be filled from the source, and equal labels deduplicate safely. The source book is deleted last in the same transaction. A successful merge therefore leaves one book identity for future graph projection; an explicit keep-separate choice leaves both identities.

## Schema evolution

Every later schema change must add a numbered forward migration and tests for successful preservation, repeat execution, and safe failure. Backup/restore compatibility must be specified before applying any later migration to user data. Prompt 1's spike migration is not reused; the production registry currently ends at version 5.

Prompt 7 backups record both backup format version 1 and the actual schema version. Prompt 9 keeps backup format 1 and extends supported application schemas from 1–4 to 1–5. Restore stages and migrates older snapshots through the same registry and rejects future schemas. Before inspection can become a restore preview, the backup must have migration history equal to `user_version`, every required table/column/key/constraint, no `foreign_key_check` result, and domain-decodable books, organizations, joins, links, relations, duplicate indexes, ignored pairs, and—at Schema 5—local-file references. For Schema 5, BLOB lengths are checked before materialization and valid rows are streamed one at a time through canonical domain validation. The validator runs again after migration and on the installed file before reconnect. Import staging metadata and recovery markers remain temporary operation formats, not schema tables. CSV and Markdown omit external URLs, local paths, and bookmark bytes; full-fidelity transfer uses backup format 1. See `docs/FORMATS/PORTABILITY.md`.

## Test data

All fixtures must be deterministic and fictional. Approved example titles include 《雾港档案》, 《机器与花园》, 《星图索引》, 《静默算法》, and 《北岸来信》. Contributors, publishers, sources, lists, URLs, identifiers, and relationships must also be fictional.
