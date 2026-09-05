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

V1.0.0 includes a native macOS library interface, book CRUD, tags and lists,
search/filter/sort/pagination, source tracking, duplicate review and merge,
import/export, backup/restore, a bounded relationship graph, and only
explicitly bounded external-link behavior. It is a source-only GitHub release
for macOS 26; users build it with a compatible Xcode 26 toolchain. It does not
promise macOS 14/15 compatibility or provide a precompiled application.

The current implementation provides the native library interface, book CRUD, organization, search/filter/sort, deterministic duplicate review, CSV import with mapping and bounded disk-staged preview, Markdown/CSV export, versioned full-database backup/restore, a bounded local relationship graph, and explicit external reading entries on the accepted direct-SQLite store. Import explains duplicates against both the current library and earlier rows in the same batch, then rechecks at execution; it never overwrites, automatically merges, or creates a hidden pending-review record. Restore validates the physical file and Book Atlas domain schema, creates a recovery copy, and enters a process-interruption-safe replacement protocol only after confirmation. The graph is an optional projection of same-author, shared-tag, same-list, same-source, and explicit manual relationships; it does not infer editions or persist layout state.

The Prompt 11A working tree adds a book-detail loop for explicit manual
relations: incoming and outgoing directions stay distinct; a user can search a
bounded, paged target list, preview source-to-target direction, create a typed
relation with an optional note, navigate to the exact counterpart UUID, and
confirm deletion of only the relation. This local implementation is
`BLOCKED — WAITING FOR CONTROLLER REVIEW`, not an accepted or released feature.
Creation can be cancelled before submission without writing. Once submitted,
cancellation and related draft changes are temporarily disabled until the
write result is known; dismissing a view or cancelling its Task is not database
rollback. Runtime verification of the repaired busy-state/Escape behavior is
still `UNTESTED`.
It does not add relation editing, `BookKind`, a schema or backup/CSV change, or
automatic relationship inference.

External reading actions are always user initiated. The app can hand a validated HTTPS URL to macOS, distinguish `books.apple.com`, offer a confirmed public Apple Books search, launch the installed Apple Books application, copy an ISBN or title, and retain a read-only bookmark for a file the user selected. It does not read ebook content, check URL reachability, use a network client, scan directories, or claim exact access to a private Apple Books library item.

Prompt 10 is the accepted quality and open-source-readiness closure over this
existing scope. V1.0.0 source-publication preparation changes configuration
and public materials, not product capability. It is not a claim that the
repository is public, a tag or GitHub Release exists, or a binary was signed,
notarized, or uploaded.

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
