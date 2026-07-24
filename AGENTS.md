# Book Atlas repository rules

## Project identity

- Book Atlas · 图书志 is a local-first macOS tool for managing a personal bibliography and exploring relationships between books.
- Build a native Swift and SwiftUI application for macOS only. Use AppKit only where SwiftUI is insufficient.
- This is not an ebook reader and does not replace reading or note-taking applications.
- The application is offline by default. Network access requires an explicit, documented reason.

## Read before work

Before changing anything:

1. Read every applicable `AGENTS.md`, then `README.md`.
2. Read `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, and `docs/DATA_MODEL.md`.
3. Read the current plan in `docs/PLANS/`.
4. Inspect the relevant implementation and tests.
5. Check `git status --short --branch`.

## Working rules

- Understand the existing implementation and make the smallest change needed.
- Do not broaden the task, refactor unrelated modules, add dependencies casually, delete unknown files, or overwrite uncommitted user work.
- Never use destructive Git commands, rewrite history, force-push, or claim results that were not verified.
- Do not claim an unverified macOS or third-party integration works.
- Keep documentation consistent with implementation and decisions.

## Architecture rules

- Keep complex persistence logic out of SwiftUI views; domain rules must be unit-testable.
- Version every schema change and provide migration code and migration tests.
- Isolate system integrations behind focused services.
- Keep graph presentation concerns out of the core bibliography model.
- Avoid global singletons, oversized state objects, oversized views, and abstractions without a concrete need.

## Privacy rules

- Never commit real databases, reading lists, private notes, local absolute paths, secrets, certificates, provisioning profiles, account data, or permission bookmarks.
- Repository sample data, including book, author, publisher, list, source, and relationship data, must be fictional.
- Treat titles, notes, paths, URLs, and imported content as private in logs.
- Do not read files the user did not explicitly select. Any network feature requires a documented privacy review.

## Testing rules

- Add tests for new domain rules and regression tests for defect fixes.
- Test migrations, duplicate detection, and import parsing when those features are introduced.
- Tests must use temporary or in-memory stores and must never read real user files.
- Do not declare a task complete while relevant tests fail.

## Definition of done

- The project builds and relevant tests pass, or the environmental blocker is stated precisely.
- No private data, unrelated changes, or undocumented behavior was introduced.
- Documentation matches the implementation.
- The handoff lists changes, verification commands and results, unverified items, and remaining risks.

