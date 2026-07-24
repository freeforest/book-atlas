# Book Atlas · 图书志

Book Atlas is a lightweight, local-first macOS application for maintaining a personal bibliography and exploring relationships between books. It is designed to make a growing reading list searchable, filterable, maintainable, portable, and explorable without turning it into a cloud service or ebook reader.

## Status

The repository is at Milestone 0. It currently contains project rules and planning documents only—there is no Xcode project, Swift package, application target, build command, or test command yet. Prompt 1 will validate the key technical choices; Prompt 2 will establish the minimal runnable app and its real build/test commands.

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

The intended environment is a supported macOS and Xcode toolchain. Prompt 1 must record the installed Xcode/Swift versions, evaluate deployment-target tradeoffs, and verify candidate APIs. Do not install third-party dependencies or project generators during Milestone 0.

### Build and test

No build or test command exists yet. Do not treat documentation checks as an application build. Prompt 2 will add the project and document reproducible commands after Prompt 1 selects and records the supported toolchain.

## Working on the repository

Read [AGENTS.md](AGENTS.md), the core documents, and the active plan before modifying code. Check the Git worktree first, preserve uncommitted work, keep sample data fictional, and report only commands that were actually run.

