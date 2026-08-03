# Book Atlas · 图书志

Book Atlas is a lightweight, local-first macOS application for maintaining a personal bibliography and exploring relationships between books. It is designed to make a growing reading list searchable, filterable, maintainable, portable, and explorable without turning it into a cloud service or ebook reader.

## Status

Prompts 6–9 have passed independent acceptance. Prompt 7 was accepted at baseline `b27318c741fee5b4a66e5ad99cb979177285fef5`; Prompt 8 passed its second independent review at baseline `6ae90dd50ee71f574e0b4cc1ffccfd7e4c2e71aa`; Prompt 9 passed independent review at baseline `1f7a35cda11fcafd23aacab0cb5c72e811327d0b`. Prompt 9's independent evidence is a successful Debug build, 171/171 unit/integration/migration/security/performance tests, and 26/26 macOS UI tests, with no failures or skips. The library supports local book CRUD, search/filter/sort, organization, explainable duplicate review and transactional merging, user-selected CSV import, Markdown/CSV export, versioned full-database backup and restore, a local graph projected from existing relationships, and user-initiated HTTPS, Apple Books fallback, clipboard, and sandboxed local-file reading entries. Prompt 10 quality and open-source preparation is implemented and awaits independent review and the documented human gates; the latest local closure evidence is successful Debug and hardened local Release builds, 190/190 unit/integration/migration/security/performance tests, and 37/37 UI tests. No stable release has been distribution-signed, notarized, tagged, uploaded, or accepted.

Import previews and field mapping use bounded temporary disk staging and do not write the library. They identify Exact/Strong duplicates against the current library and earlier batch rows; confirmed import rechecks and never overwrites or automatically merges candidates. Backups use SQLite's online backup API and restore requires physical plus exact versioned application-schema object validation, preview, explicit confirmation, a verified recovery copy, backend-authoritative cancellation boundaries, and process-interruption-safe rollback/restart recovery. The graph combines same-author, shared-tag, same-list, same-source, and manual-relation evidence, defaults to one layer and 80 nodes/200 edges, and provides deterministic layout plus a keyboard/accessibility list. A catalog-owned content revision invalidates stale projections after every graph-relevant mutation; unchanged re-entry retains the current local layout, while changed data rebuilds and discards stale asynchronous results. Canvas drag mode is fixed at gesture start so cumulative pan input is applied exactly once.

Reading entries are scoped to an explicit book identity; changing books clears the prior rows immediately, cancels the old request, and rejects late results by generation and book ID. Duplicate-candidate details use a separate read-only scope, so they cannot replace or mutate the main detail's entries. URLs accept only revalidated HTTPS with strict raw and decoded control-character checks, explicit port grammar, and a deterministic ASCII host display. Apple Books integration is limited to a saved `books.apple.com` URL, a confirmed public search, application launch, and clipboard/other-HTTPS fallbacks; it never reads or targets a private Apple Books library item. Local files are selected through `NSOpenPanel` and retained as read-only app-scoped security bookmarks without persistent absolute paths or content inspection; every bookmark is bounded to 1 MiB and every stored display name must already be canonical.

The ordinary library list now loads 200 deterministic rows at a time, discloses “已显示数量/总数量”, and offers an accessible, keyboard-operable load-more/retry action. Search, filtering, sorting, and catalog mutations restart from a consistent first page; a failed next page preserves the rows already shown. Cross-module focus and create/edit/merge refreshes preserve an explicitly requested book UUID even when it lies beyond the first page: the catalog returns the normal bounded page plus at most one primary-key-filtered target, which the UI identifies separately without loading intervening pages. A deleted or missing target clears the selection and shows “找不到请求的书籍”; a target excluded by the current query shows “所选书籍不在当前结果中” plus an accessible clear-search/filter action, including when the ordinary result list is empty. Neither case substitutes the first row or falls through to the generic empty/no-results state. The list does not silently stop at 500 or put all 10,000 rows into SwiftUI state.

The latest Prompt 10 closure run built Debug and Hardened Runtime Release products, passed 190/190 unit/integration/migration/security/performance tests and 37/37 actually executed macOS UI tests, and retained three-run fixed-fictional existing-library launch, database-open, 200-row first-page, next-page, disclosed multi-page scrolling/hitch, tag-count, and Schema 1–4→5 measurements. The search/filter regression now selects and verifies the fixed A101 UUID before excluding it, while the shared text-input helper activates the app, confirms its window and the field exist, and requires real keyboard focus before replacing text. A relaunch-enabled, no-retry run passed all 10 repetitions; the final unique full-suite result bundle independently parsed as 37 passed, zero failed, and zero skipped. Earlier closure attempts remain relevant evidence: one full run was 36/37, and that failure plus one focused rerun showed SwiftUI `TextEditor` reported unreliable `hittable`/`enabled` accessibility attributes even though click, focus, and typing then succeeded. The final helper therefore treats post-click keyboard focus—not those advisory attributes—as the input authority. The measured Debug launch processes only reopen an already-created temporary Schema 5 database; data generation is outside the timing window and invalid performance arguments cannot fall back to the production database. Exact UUID focus from the graph and create/edit/merge refreshes preserves an existing page-out target with one bounded filtered primary-key lookup and never substitutes an unrelated first-row book; the latest regressions also prove the two precise failure states render above generic zero-result placeholders and expose the query-reset recovery action. Release Instruments launch measurement remains unverified because the measured desktop trace could not be authorized from this execution surface. These are one-host regression observations, not cross-device promises. On 2026-08-03 a fixed-fictional in-memory Debug app was started for another real-desktop audit attempt, but the native Computer Use pipe failed before it could read even the running-app list or Book Atlas accessibility tree. A real manual VoiceOver and Accessibility Inspector traversal therefore still could not be completed; Light/Dark, non-default accent, 520×360, Reduce Motion, spoken focus/order, and Inspector findings remain explicit unverified release gates. Prompt 10 still awaits independent review.

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
- [Prompt 10 quality audit](docs/QUALITY_AUDIT.md)
- [Performance evidence](docs/PERFORMANCE.md)
- [Roadmap and prompt order](docs/ROADMAP.md)
- [Architecture decisions](docs/DECISIONS/README.md)
- [Portability format specification](docs/FORMATS/PORTABILITY.md)
- [Milestone plans](docs/PLANS/README.md)
- [Stable release checklist](docs/RELEASE_CHECKLIST.md)

## Repository data policy

`SampleData/` may contain reviewable fictional fixtures. `LocalData/` is reserved for private development data and is ignored except for its policy file and placeholder. Generated imports, exports, backups, cover caches, logs, database files, secrets, signing material, and security-scoped bookmarks are also ignored.

## Development environment

The verified environment is Xcode 26.6 (build 17F113) with Swift 6.3.3. The product deployment target is macOS 14.0. Prompt 1 kept third-party dependencies out of the repository; the selected production direction is a focused internal SQLite store, specified in [ADR-0002](docs/DECISIONS/0002-direct-sqlite-persistence.md).

### Build and test

Open `BookAtlas.xcodeproj` in Xcode, or build the production `BookAtlas` scheme:

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bookatlas-debug \
  build
```

The complete commands, test isolation rules, effective-entitlement check, and current limitations are in [Development](docs/DEVELOPMENT.md). Prompt 1's isolated experiments remain in `Experiments/TechnicalSpikes/` and are not a production dependency.

## Local data and privacy

The application keeps its SQLite library inside its sandboxed Application Support container. It does not create an account, send telemetry, or fetch metadata. Files outside the container are accessed only after a visible file-picker action; long-lived local reading entries retain a bounded opaque bookmark rather than an absolute path. CSV/Markdown are selective exports, while a full backup contains the private library and should be protected by the user. See [Privacy](docs/PRIVACY.md) and [Security](docs/SECURITY.md) before using portability features.

`SampleData/bookatlas-small.csv` and the fixed-seed generator are fictional and are never loaded automatically. The generator writes only to a new destination selected on the command line; the recommended destination is `/tmp`.

## Contributing and license

See [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), and the repository [security policy](SECURITY.md). Issue and pull-request templates live under `.github/`.

`LICENSE` is an MIT template, but its year and copyright holder remain explicit placeholders pending maintainer/legal review. It is not release-ready and this statement is not legal advice.

## Screenshots

No production screenshot is committed yet. Before adding one, use only the fixed fictional fixture and complete the privacy/accessibility checks in the [release checklist](docs/RELEASE_CHECKLIST.md); do not substitute a mock image or private library screenshot.

## Working on the repository

Read [AGENTS.md](AGENTS.md), the core documents, and the active plan before modifying code. Check the Git worktree first, preserve uncommitted work, keep sample data fictional, and report only commands that were actually run.
