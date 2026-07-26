# Conceptual data model

## Status

This is a storage-independent vocabulary for product and experiment planning. It is not a committed production SQL schema. Prompt 1 selected direct SQLite as the persistence direction; Prompt 3 defines the production schema, version 1 migration, constraints, and tests behind that store boundary.

## Candidate concepts

### Book

A library record representing a work or edition as the user understands it. Candidate attributes include an internal identifier, title, optional subtitle, normalized title, publication details, identifiers such as ISBN, reading status, rating, dates, private notes, and audit timestamps.

The exact distinction between work and edition is deliberately unresolved. The first version must not claim to infer editions, translations, or series automatically.

### Contributor

A fictional or user-entered person or organization associated with a book, with a role such as author, editor, or translator. A book can have multiple ordered contributors.

### Tag

A user-defined label linked many-to-many with books. Normalization and uniqueness behavior must be explicit and tested.

### Book list

A named, user-maintained collection linked many-to-many with books. List membership may carry ordering only if a real product workflow requires it.

### Source

Where the user learned about or acquired a book. A source can have an optional user-entered URL or note. External URLs are private data and must not be logged.

### Relationship

An explicit, user-maintained edge between two books, such as “inspired by,” “responds to,” or “read with.” Relationship types, directionality, uniqueness, deletion behavior, and graph projection rules must be defined in Prompt 3 and Prompt 8.

### External link

An optional user-entered or verified integration destination. A stored link is not proof that another application can open a specific local-library item.

### Attachment reference

If future scope requires a local-file reference, store only the minimum metadata and permission bookmark needed. Book Atlas does not ingest ebook content in the first release.

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

Every production schema has an integer version stored in SQLite metadata. Each change supplies a transactional forward migration and fixtures that test both successful migration and safe failure. Backup/restore compatibility and transaction boundaries must be specified before applying migrations to user data. The Prompt 1 experiment demonstrated version-1-to-2 and failed version-3 rollback only; it is not the production schema or migration history.

## Test data

All fixtures must be deterministic and fictional. Approved example titles include 《雾港档案》, 《机器与花园》, 《星图索引》, 《静默算法》, and 《北岸来信》. Contributors, publishers, sources, lists, URLs, identifiers, and relationships must also be fictional.
