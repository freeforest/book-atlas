# Milestone 2 — usable catalog

## Goal

Provide safe foundational book management in a native macOS interface.

## Stage

- Prompt 4: completed — library navigation, detail/edit flows, create/update/delete behavior, validation, empty/error states, keyboard use, and accessibility foundations.
- Prompt 5: completed — unified search, composable filters, stable sorting, tag/collection/source management, memberships, and repeatable query baselines.

## Completion record

- The library screen lists local books, presents an empty state, and shows a selected book's details.
- `LibraryStore` and `LibraryCatalogService` keep presentation state and editor-draft conversion outside SwiftUI views and route all data operations through the existing repository boundary.
- Create and edit require a title and author, validate publication date and priority, and normalize basic ISBN formatting before persistence.
- Delete requires a native confirmation dialog. Save failures preserve form input; local-store failures use generic messages without exposing a path or book content.
- Command-N starts a new book, Command-S saves an open editor, Escape asks before discarding unsaved edits, Delete starts deletion, and the native list supports keyboard selection.
- Unit and UI tests use fictional data and an in-memory library; no Prompt 4 feature makes a network request or adds a dependency.
- `LibraryQuery` searches title, original title, author, and normalized ISBN. Filter families use documented AND/OR/all-of semantics, and every sort has a deterministic identifier tie-breaker.
- Tags support create, rename, confirmed delete, and transactional merge. Collections and recommendation sources support create, edit, confirmed delete, derived book counts, and duplicate-safe memberships.
- The catalog actor keeps SQLite work outside SwiftUI and the main actor. Search is debounced, cancelled queries cannot replace newer results, and organizer snapshot loads also reject stale responses.
- Fixed-seed 1,000-, 5,000-, and 10,000-book baselines exercise search/filter/sort without absolute-path data or an FTS dependency.
- On the verified Apple-silicon macOS 26.5.2 environment, the recorded 1k/5k/10k search baselines were approximately 1.0/2.2/4.1 ms, and combined filter-plus-sort baselines were 9.5/27.4/28.1 ms. These are evidence records rather than pass/fail thresholds.

## Gates

- UI calls tested use cases instead of implementing database rules.
- Destructive actions are explicit and domain validation is visible.
- Build and relevant tests pass with fictional data.
- Bulk import, duplicate-book merge, graph, and external integrations stay out of scope.
