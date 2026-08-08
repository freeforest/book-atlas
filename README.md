# Book Atlas · 图书志

Book Atlas is a lightweight, local-first macOS application for maintaining a personal bibliography and exploring relationships between books. It is designed to make a growing reading list searchable, filterable, maintainable, portable, and explorable without turning it into a cloud service or ebook reader.

## Status

Prompts 0–10 are complete. Prompt 10 passed independent acceptance at documentation baseline `ec0b04f1c004ef5c897d3269e335c92034d6021e`; its verified code baseline is `4cc20b8c88cb674a4f9a52d3e8de70c295169281`. There is no automatic Prompt 11: subsequent work is GitHub source-publication preparation, not a new product-development stage. The final accepted evidence includes successful Debug and local Hardened Runtime Release builds, 3/3 targeted historical graph regressions, 41/41 complete macOS UI tests after XCUIAutomation initialized, and 200/200 complete non-UI tests, with zero failures and zero skips. Schema remains 5 with migration path `1 → 2 → 3 → 4 → 5`. Fixed-fictional manual evidence covers Light/Dark, the purple accent, Reduce Motion, complete pointer-free keyboard operation, VoiceOver, exact 520×360, and the repaired graph layout. Inspector formal audits reported zero warnings separately in the unselected-library state and selected A101 detail state; this is evidence only for those two states. Earlier accent, Reduce Motion, keyboard, and VoiceOver evidence was not fully rerun on `4cc20b8c…`, automation is not substituted for human gates, and the native file action remains `PASS WITH LIMITATION` because an actual `NSOpenPanel` did not appear.

Import previews and field mapping use bounded temporary disk staging and do not write the library. They identify Exact/Strong duplicates against the current library and earlier batch rows; confirmed import rechecks and never overwrites or automatically merges candidates. Backups use SQLite's online backup API and restore requires physical plus exact versioned application-schema object validation, preview, explicit confirmation, a verified recovery copy, backend-authoritative cancellation boundaries, and process-interruption-safe rollback/restart recovery. The graph combines same-author, shared-tag, same-list, same-source, and manual-relation evidence, defaults to one layer and 80 nodes/200 edges, and provides deterministic layout plus a keyboard/accessibility list. A catalog-owned content revision invalidates stale projections after every graph-relevant mutation; unchanged re-entry retains the current local layout, while changed data rebuilds and discards stale asynchronous results. Canvas drag mode is fixed at gesture start so cumulative pan input is applied exactly once.

Reading entries are scoped to an explicit book identity; changing books clears the prior rows immediately, cancels the old request, and rejects late results by generation and book ID. Duplicate-candidate details use a separate read-only scope, so they cannot replace or mutate the main detail's entries. URLs accept only revalidated HTTPS with strict raw and decoded control-character checks, explicit port grammar, and a deterministic ASCII host display. Apple Books integration is limited to a saved `books.apple.com` URL, a confirmed public search, application launch, and clipboard/other-HTTPS fallbacks; it never reads or targets a private Apple Books library item. Local files are selected through `NSOpenPanel` and retained as read-only app-scoped security bookmarks without persistent absolute paths or content inspection; every bookmark is bounded to 1 MiB and every stored display name must already be canonical.

The ordinary library list now loads 200 deterministic rows at a time, discloses “已显示数量/总数量”, and offers an accessible, keyboard-operable load-more/retry action. Search, filtering, sorting, and catalog mutations restart from a consistent first page; a failed next page preserves the rows already shown. Cross-module focus and create/edit/merge refreshes preserve an explicitly requested book UUID even when it lies beyond the first page: the catalog returns the normal bounded page plus at most one primary-key-filtered target, which the UI identifies separately without loading intervening pages. A deleted or missing target clears the selection and shows “找不到请求的书籍”; a target excluded by the current query shows “所选书籍不在当前结果中” plus an accessible clear-search/filter action, including when the ordinary result list is empty. Neither case substitutes the first row or falls through to the generic empty/no-results state. The list does not silently stop at 500 or put all 10,000 rows into SwiftUI state.

An earlier Prompt 10 selection-idempotence closure built Debug and Hardened Runtime Release products, passed 197/197 unit/integration/migration/security/performance tests and 37/37 actually executed macOS UI tests, and retained three-run fixed-fictional existing-library launch, database-open, 200-row first-page, next-page, disclosed multi-page scrolling/hitch, tag-count, and Schema 1–4→5 measurements. List selection now updates local SwiftUI selection state first and applies identity side effects after that selection transaction; programmatic selection synchronizes back without a second Store write, and a generation-tagged latest value prevents an older rapid selection from winning. Repeating an unchanged UUID or nil selection publishes nothing when issue and focus are already unchanged; a matching page-out focus is retained, while only an actual non-nil focus with a different UUID is cleared. No-retry relaunch runs passed the search/filter and keyboard-selection paths 10/10 each. Parsed activities for those 20 runs and that 37/37 full-suite result contain zero “Publishing changes from within view updates” warnings. Six full-suite cases retain a separate Xcode internal QoS diagnostic; no evidence ties that tool warning to the selection bridge or production behavior. An initial eighth-closure focused command used an incomplete XCTest selector and executed zero tests, so it is not counted as evidence; the corrected focused result executed 4/4 key selection paths. Earlier closure attempts remain relevant evidence, including one 36/37 suite, two helper-assertion failures, and two zero-test automation-initialization timeouts from the preceding closure. The measured Debug launch processes only reopen an already-created temporary Schema 5 database; data generation is outside the timing window and invalid performance arguments cannot fall back to the production database. Exact UUID focus from the graph and create/edit/merge refreshes preserves an existing page-out target with one bounded filtered primary-key lookup and never substitutes an unrelated first-row book. Release Instruments launch measurement was not obtained from that execution surface; it is historical performance scope, not a GitHub source-publication blocker. These are one-host regression observations, not cross-device promises. On 2026-08-03 the supported Computer Use runtime initialized, enumerated running applications, and a fixed-fictional in-memory Debug app was started, but the native pipe closed before returning the first Book Atlas app-state/accessibility tree. That attempt produced no manual result; the later completed human gates and current `4cc20b8c…` supplements are recorded in the quality audit. Prompt 10 subsequently passed independent acceptance at `ec0b04f…`.

The 197/197 and 37/37 figures in the preceding closure history remain the
selection-idempotence baseline, not the later editor-validation result. A
partial Light-mode manual check later found that invalid Save feedback was
below the visible Form viewport. That editor-validation code closure adds a fixed summary,
field-level explanations, required-field focus, and repeated privacy-safe
accessibility announcements. Its complete non-UI suite passed 200/200, and the
direct fixed-fictional author/no-title mouse path passed 3/3 without retry.
The sealed complete UI result then executed 40/40 tests with no failure or
skip. Those automated results preserve rather than replace the manual FAIL; the
corrected Light path and every other documented human gate still required real
manual recheck at that stage. The subsequent human gate and `4cc20b8c…`
supplement evidence is recorded in `docs/QUALITY_AUDIT.md`. Prompt 10 later
passed independent acceptance; that acceptance did not publish the repository,
create a tag or GitHub Release, or upload an application.

## Product boundaries

- Native macOS application using Swift, SwiftUI, and only necessary AppKit integration.
- Offline by default, with local storage under the app's Application Support directory.
- No accounts, cloud sync, telemetry, advertising, tracking, AI recommendations, automatic metadata downloads, or plugin platform.
- No promise of opening a specific item in a user's Apple Books library until official documentation or an isolated experiment proves it.
- Examples and tests use fictional data only.

The planned Xcode project and Swift module are both `BookAtlas`, the display name is `Book Atlas`, and the bundle identifier placeholder is `com.<developer>.BookAtlas`.

## GitHub source-publication policy

Book Atlas is planned for public GitHub source code only. It will not be
submitted to the Mac App Store, and the project does not plan to use an Apple
Developer account, App Store Connect, Developer ID, distribution certificates,
provisioning profiles, Apple notarization, stapling, or Gatekeeper acceptance
for a downloadable prebuilt application. No precompiled `.app` will be
provided through GitHub Releases or another binary-distribution channel;
users must build from source with Apple's Xcode, Swift, SwiftUI, AppKit, and
system SQLite. Local ad-hoc Debug/Release builds, App Sandbox, Hardened Runtime,
and entitlement inspection remain engineering evidence, not Apple platform
distribution evidence.

The confirmed product support policy for a future public source version is the
latest macOS 26 only, with no macOS 14/15 compatibility promise or multi-version
matrix. The Xcode project still declares `MACOSX_DEPLOYMENT_TARGET = 14.0`, so
the macOS 26-only policy is not yet implemented in project configuration. A
separate GitHub source-publication preparation task must align the deployment
target and build documentation, then rerun Debug/Release, the complete non-UI
and UI suites with XCUIAutomation initialized, and necessary human checks from
a clean checkout.

Before any public action, the user must confirm the GitHub repository owner and
address, license year and copyright holder, final public version, whether a tag
is wanted, and either GitHub Private Vulnerability Reporting or another
maintained private security channel. The repository has not been made public;
no push, tag, GitHub Release, source upload, `.app` upload, or announcement has
occurred. If precompiled GitHub Release applications are considered in the
future, that requires a separate authorized release task covering Developer
ID, notarization, Gatekeeper, integrity, installation, and updates.

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
- [GitHub source publication checklist](docs/RELEASE_CHECKLIST.md)

## Repository data policy

`SampleData/` may contain reviewable fictional fixtures. `LocalData/` is reserved for private development data and is ignored except for its policy file and placeholder. Generated imports, exports, backups, cover caches, logs, database files, secrets, signing material, and security-scoped bookmarks are also ignored.

## Development environment

The verified environment is Xcode 26.6 (build 17F113) with Swift 6.3.3 on macOS 26. The current project deployment target is still macOS 14.0; the confirmed future source-publication policy is macOS 26-only, and those facts have not yet been technically aligned. Prompt 1 kept third-party dependencies out of the repository; the selected production direction is a focused internal SQLite store, specified in [ADR-0002](docs/DECISIONS/0002-direct-sqlite-persistence.md).

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

`LICENSE` is an MIT template, but its year and copyright holder remain explicit placeholders pending maintainer/legal review. Both must be user-confirmed before GitHub source publication; this statement is not legal advice.

## Screenshots

No production screenshot is committed yet. Before adding one, use only the fixed fictional fixture and complete the privacy/accessibility checks in the [release checklist](docs/RELEASE_CHECKLIST.md); do not substitute a mock image or private library screenshot.

## Working on the repository

Read [AGENTS.md](AGENTS.md), the core documents, and the active plan before modifying code. Check the Git worktree first, preserve uncommitted work, keep sample data fictional, and report only commands that were actually run.
