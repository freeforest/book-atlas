# Book Atlas · 图书志

Book Atlas is a lightweight, local-first macOS application for maintaining a personal bibliography and exploring relationships between books. It is designed to make a growing reading list searchable, filterable, maintainable, portable, and explorable without turning it into a cloud service or ebook reader.

## Status

Prompt 6, Prompt 7, and Prompt 8 have passed independent acceptance. Prompt 7 was accepted at baseline `b27318c741fee5b4a66e5ad99cb979177285fef5`; Prompt 8 passed its second independent review at baseline `6ae90dd50ee71f574e0b4cc1ffccfd7e4c2e71aa`. Its independent evidence is a successful Debug build, 146/146 unit/integration/performance tests, and 22/22 macOS UI tests from an interactive session with XCUIAutomation initialized, with no failures or skips. Prompt 9 is implemented, has received its second independent review, and is waiting for another independent review after the second NO-GO closure. The library supports local book CRUD, search/filter/sort, organization, explainable duplicate review and transactional merging, user-selected CSV import, Markdown/CSV export, versioned full-database backup and restore, a local graph projected from existing relationships, and user-initiated HTTPS, Apple Books fallback, clipboard, and sandboxed local-file reading entries. Prompt 10 has not started.

Import previews and field mapping use bounded temporary disk staging and do not write the library. They identify Exact/Strong duplicates against the current library and earlier batch rows; confirmed import rechecks and never overwrites or automatically merges candidates. Backups use SQLite's online backup API and restore requires physical plus exact versioned application-schema object validation, preview, explicit confirmation, a verified recovery copy, backend-authoritative cancellation boundaries, and process-interruption-safe rollback/restart recovery. The graph combines same-author, shared-tag, same-list, same-source, and manual-relation evidence, defaults to one layer and 80 nodes/200 edges, and provides deterministic layout plus a keyboard/accessibility list. A catalog-owned content revision invalidates stale projections after every graph-relevant mutation; unchanged re-entry retains the current local layout, while changed data rebuilds and discards stale asynchronous results. Canvas drag mode is fixed at gesture start so cumulative pan input is applied exactly once.

Reading entries are scoped to an explicit book identity; changing books clears the prior rows immediately, cancels the old request, and rejects late results by generation and book ID. Duplicate-candidate details use a separate read-only scope, so they cannot replace or mutate the main detail's entries. URLs accept only revalidated HTTPS with strict raw and decoded control-character checks, explicit port grammar, and a deterministic ASCII host display. Apple Books integration is limited to a saved `books.apple.com` URL, a confirmed public search, application launch, and clipboard/other-HTTPS fallbacks; it never reads or targets a private Apple Books library item. Local files are selected through `NSOpenPanel` and retained as read-only app-scoped security bookmarks without persistent absolute paths or content inspection; every bookmark is bounded to 1 MiB and every stored display name must already be canonical.

## Product boundaries

- Native macOS application using Swift, SwiftUI, and only necessary AppKit integration.
- Offline by default, with local storage under the app's Application Support directory.
- No accounts, cloud sync, telemetry, advertising, tracking, AI recommendations, automatic metadata downloads, or plugin platform.
- No promise of opening a specific item in a user's Apple Books library until official documentation or an isolated experiment proves it.
- Examples and tests use fictional data only.

The planned Xcode project and Swift module are both `BookAtlas`, the display name is `Book Atlas`, and the bundle identifier placeholder is `com.<developer>.BookAtlas`.

## Documentation

- [Product](docs/PRODUCT.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Conceptual data model](docs/DATA_MODEL.md)
- [Privacy](docs/PRIVACY.md)
- [Security](docs/SECURITY.md)
- [Roadmap and prompt order](docs/ROADMAP.md)
- [Architecture decisions](docs/DECISIONS/README.md)
- [Portability format specification](docs/FORMATS/PORTABILITY.md)
- [Milestone plans](docs/PLANS/README.md)

## Repository data policy

`SampleData/` may contain reviewable fictional fixtures. `LocalData/` is reserved for private development data and is ignored except for its policy file and placeholder. Generated imports, exports, backups, cover caches, logs, database files, secrets, signing material, and security-scoped bookmarks are also ignored.

## Development environment

The verified environment is Xcode 26.6 (build 17F113) with Swift 6.3.3. The product deployment target is macOS 14.0. Prompt 1 kept third-party dependencies out of the repository; the selected production direction is a focused internal SQLite store, specified in [ADR-0002](docs/DECISIONS/0002-direct-sqlite-persistence.md).

### Build and test

The production scheme is `BookAtlas`. The verified commands and current limitations are in [Development](docs/DEVELOPMENT.md) and [Milestone 0](docs/PLANS/MILESTONE-0.md). Prompt 1's isolated experiments remain in `Experiments/TechnicalSpikes/` and are not a production dependency.

## Working on the repository

Read [AGENTS.md](AGENTS.md), the core documents, and the active plan before modifying code. Check the Git worktree first, preserve uncommitted work, keep sample data fictional, and report only commands that were actually run.
