# Milestone 2 — usable catalog

## Goal

Provide safe foundational book management in a native macOS interface.

## Stage

- Prompt 4: completed — library navigation, detail/edit flows, create/update/delete behavior, validation, empty/error states, keyboard use, and accessibility foundations.

## Completion record

- The library screen lists local books, presents an empty state, and shows a selected book's details.
- `LibraryStore` and `LibraryCatalogService` keep presentation state and editor-draft conversion outside SwiftUI views and route all data operations through the existing repository boundary.
- Create and edit require a title and author, validate publication date and priority, and normalize basic ISBN formatting before persistence.
- Delete requires a native confirmation dialog. Save failures preserve form input; local-store failures use generic messages without exposing a path or book content.
- Command-N starts a new book, Command-S saves an open editor, Escape asks before discarding unsaved edits, Delete starts deletion, and the native list supports keyboard selection.
- Unit and UI tests use fictional data and an in-memory library; no Prompt 4 feature makes a network request or adds a dependency.

## Gates

- UI calls tested use cases instead of implementing database rules.
- Destructive actions are explicit and domain validation is visible.
- Build and relevant tests pass with fictional data.
- Search, bulk import, duplicate merge, graph, and external integrations stay out of scope.
