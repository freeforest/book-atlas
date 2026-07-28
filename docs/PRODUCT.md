# Product definition

## Purpose

Book Atlas · 图书志 helps one person turn a growing personal bibliography into a reading map that can be searched, filtered, maintained, backed up, and explored. The first user is the developer; decisions should optimize for a dependable personal tool rather than hypothetical scale.

## Primary jobs

1. Record and edit books with useful bibliographic and personal metadata.
2. Find books by text, structured filters, tags, lists, and sources.
3. Detect likely duplicates and let the user make the final merge decision.
4. Import, export, back up, and restore data through explicit user actions.
5. Explore a bounded local graph of meaningful book relationships.
6. Open supported external destinations without pretending to be a reader.

## Product principles

- Local-first and offline by default.
- The user owns the data and initiates file access, import, export, backup, and restore.
- Simple, inspectable workflows are preferred to automation that can damage a library.
- Search and editing remain useful without graph visualization or external integrations.
- Destructive and ambiguous operations require confirmation and offer a review step where practical.
- Accessibility, keyboard use, privacy, and data portability are core quality attributes.

## First-release scope

The planned first release includes a native macOS library interface, book CRUD, tags and lists, search/filter/sort, source tracking, duplicate review and merge, import/export, backup/restore, a bounded relationship graph, and only experimentally verified external-link behavior.

The current implementation provides the native library interface, book CRUD, organization, search/filter/sort, deterministic duplicate review, CSV import with mapping and bounded disk-staged preview, Markdown/CSV export, and versioned full-database backup/restore on the accepted direct-SQLite store. Import explains duplicates against both the current library and earlier rows in the same batch, then rechecks at execution; it never overwrites, automatically merges, or creates a hidden pending-review record. Restore validates the physical file and Book Atlas domain schema, creates a recovery copy, and enters a process-interruption-safe replacement protocol only after confirmation. The app does not claim automatic edition, translation, or series authority. Additional formats, graph behavior, and integrations remain subject to later staged plans and ADRs.

## Non-goals

Book Atlas is not:

- an ebook reader or annotation engine;
- a replacement for Apple Books, Calibre, Kindle, WeChat Reading, Obsidian, or Notion;
- an account, cloud-sync, social, subscription, advertising, or recommendation service;
- an automatic cover or metadata downloader;
- a general plugin platform;
- an automatic authority-control system for editions, translations, or series.

## Success criteria

- Core library operations are understandable and reversible.
- The app remains useful with networking unavailable.
- A user can export and restore their own data.
- Private content stays on-device unless the user explicitly chooses a destination.
- Tests cover domain rules, persistence migration, import parsing, duplicate handling, and restore safety.
- Documentation states limitations instead of promising unverified system capabilities or fixed performance across all hardware and data sizes.
