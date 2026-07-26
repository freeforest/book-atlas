# Book Atlas · 图书志

Book Atlas is a lightweight, local-first macOS application for maintaining a personal bibliography and exploring relationships between books. It is designed to make a growing reading list searchable, filterable, maintainable, portable, and explorable without turning it into a cloud service or ebook reader.

## Status

The repository is at Milestone 2. Prompt 1 validated the technical direction in isolated experiments, Prompt 2 created the production `BookAtlas` macOS application skeleton, Prompt 3 added a testable SQLite-backed library core with explicit migrations, Prompt 4 delivered the first usable book catalog, and Prompt 5 added unified local search, filtering, stable sorting, and catalog organization. The library now supports local book CRUD plus tags, collections, recommendation sources, and per-book memberships. Import/export, duplicate merge, graph implementation, and external-link actions have not been added.

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
- [Milestone plans](docs/PLANS/README.md)

## Repository data policy

`SampleData/` may contain reviewable fictional fixtures. `LocalData/` is reserved for private development data and is ignored except for its policy file and placeholder. Generated imports, exports, backups, cover caches, logs, database files, secrets, signing material, and security-scoped bookmarks are also ignored.

## Development environment

The verified environment is Xcode 26.6 (build 17F113) with Swift 6.3.3. The product deployment target is macOS 14.0. Prompt 1 kept third-party dependencies out of the repository; the selected production direction is a focused internal SQLite store, specified in [ADR-0002](docs/DECISIONS/0002-direct-sqlite-persistence.md).

### Build and test

The production scheme is `BookAtlas`. The verified commands and current limitations are in [Development](docs/DEVELOPMENT.md) and [Milestone 0](docs/PLANS/MILESTONE-0.md). Prompt 1's isolated experiments remain in `Experiments/TechnicalSpikes/` and are not a production dependency.

## Working on the repository

Read [AGENTS.md](AGENTS.md), the core documents, and the active plan before modifying code. Check the Git worktree first, preserve uncommitted work, keep sample data fictional, and report only commands that were actually run.
