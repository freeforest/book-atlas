# Milestone 0 — foundation and app skeleton

This is a historical milestone record. ADR-0009 later superseded ADR-0003 for
the macOS 26-only V1.0.0 source release. References below to macOS 14,
placeholder identifiers, signing, and notarization describe the state at the
recorded Prompt 0–2 baselines, not current V1.0.0 configuration or gates.

## Goal

Create a safe repository baseline, replace uncertain technology assumptions with isolated evidence, and establish a minimal runnable macOS application without implementing library features.

## Stages

- Prompt 0: rules, privacy boundaries, core docs, ADR process, roadmap, and repository checks.
- Prompt 1: disposable experiments for persistence/migration, SwiftUI/AppKit, graph rendering, external links, sandboxed file access, deployment target, and build/test commands.
- Prompt 2: minimal `BookAtlas` Xcode project and test targets using the accepted decisions.

## Deliverables and gates

- No production dependency or database choice before Prompt 1 evidence.
- App Sandbox on and network entitlement off by default.
- Accepted ADRs for deployment target, persistence, and any adopted dependency or integration.
- Prompt 2 build and test commands run successfully on the recorded toolchain.
- No CRUD, import/export, duplicate merge, graph feature, or Apple Books promise.

## Prompt 0 verification

Check Git state, ignored private-data paths, fictional fixtures, private-path/secret patterns, document consistency, and the absence of an app build/test command. Report all real results.

## Prompt 1 completion record

### Scope and isolation

Prompt 1 created only `Experiments/TechnicalSpikes/`: a disposable Swift package and a disposable macOS app. Production targets do not depend on this directory. All fixture titles, authors, files, identifiers, and URLs are fictional. No production database, library CRUD feature, import/export feature, or network entitlement was added.

### Toolchain and deployment decision

- Xcode 26.6, build 17F113
- Swift 6.3.3
- Test host: arm64 macOS 26.5.2, build 25F84
- Accepted first-release deployment target: macOS 14.0; see ADR-0003.

### Accepted decisions

- Direct system SQLite behind a focused internal Swift boundary, with explicit integer schema versions, transactional migrations, and SQLite backup; see ADR-0002.
- SwiftUI `Canvas` for an initial graph limited to 250 visible nodes, with separate interaction and accessibility representations; see ADR-0004.
- User-initiated allowlisted HTTPS dispatch only. Apple Books local-library deep links and custom `ibooks:` behavior are unconfirmed and unsupported; see ADR-0005.
- App Sandbox with user-selected read-only files and app-scoped security-scoped bookmarks; see ADR-0006.

### Verified experiment coverage

- **SQLite:** CRUD, many-to-many author rows, unique title constraint, cascade deletion, explicit transaction rollback, isolated in-memory stores, version-1-to-2 migration, failed version-3 rollback, and backup reopening.
- **SwiftData candidate:** in-memory many-to-many relationship only. It was evaluated but not selected for production migration ownership.
- **Native UI:** disposable SwiftUI macOS app with `NavigationSplitView`, `List`, `Table`, search, toolbar, command menu, an AppKit `NSViewRepresentable`, and a sandboxed file-panel entry point. Its app and UI test targets were actually launched.
- **Graph:** asynchronous `Canvas`, hit testing, node movement, pan, 0.5×–3× zoom, selection, no-relationship state, and an accessibility-list representation. The canvas was hosted and laid out during a test.
- **External links:** Books app was located and background-launched; a public store search using the fictional term `BookAtlas Technical Spike` was handed to the system. Only the command dispatch was verified.
- **Files:** a fictional temporary file completed bookmark creation, resolution, scoped access, and post-deletion access failure. The standalone signed spike has no broad filesystem entitlement.

### Commands actually run

```sh
CLANG_MODULE_CACHE_PATH=/tmp/bookatlas-swift-module-cache swift test --package-path Experiments/TechnicalSpikes --scratch-path /tmp/bookatlas-spike-build -Xswiftc -module-cache-path -Xswiftc /tmp/bookatlas-swift-module-cache
CLANG_MODULE_CACHE_PATH=/tmp/bookatlas-swift-module-cache swift run --package-path Experiments/TechnicalSpikes --scratch-path /tmp/bookatlas-spike-build -Xswiftc -module-cache-path -Xswiftc /tmp/bookatlas-swift-module-cache SpikeBenchmark
xcodebuild -project Experiments/TechnicalSpikes/MacOSApp/BookAtlasTechnicalSpikes.xcodeproj -scheme BookAtlasTechnicalSpikes -configuration Debug -derivedDataPath /tmp/bookatlas-xcode-spike-signed-derived -destination 'platform=macOS,arch=arm64' test
xcodebuild -project Experiments/TechnicalSpikes/MacOSApp/BookAtlasTechnicalSpikes.xcodeproj -scheme BookAtlasTechnicalSpikes -configuration Debug -derivedDataPath /tmp/bookatlas-xcode-spike-standalone-derived build
xcrun xcresulttool get test-results summary --path /tmp/bookatlas-xcode-spike-signed-derived/Logs/Test/Test-BookAtlasTechnicalSpikes-2026.07.26_09-34-23-+0800.xcresult
open -gj -b com.apple.iBooksX
open -gj 'https://books.apple.com/us/search?term=BookAtlas%20Technical%20Spike'
```

### Results

- The final Swift package run passed 13 XCTest tests with 0 failures.
- The final signed macOS app result passed 2 tests with 0 failures: one unit test and one UI launch/accessibility test.
- The standalone app build succeeded and showed only App Sandbox, app-scoped bookmark, user-selected read-only-file, and debug task-allow entitlements.
- In a single debug run, inserting 10,000 fictional SQLite records took 0.0592855 seconds and changed resident memory by 2,686,976 bytes.
- Deterministic graph-fixture generation/hit-testing took 0.000024583 seconds for 50 nodes, 0.000027166 seconds for 100 nodes, and 0.000064541 seconds for 250 nodes. Process memory sampling reported a zero delta for each small fixture; this is not a frame-time result.

### Remaining verification and risks

- At that baseline, the app was tested only on macOS 26.5.2; macOS 14
  compatibility and release signing/notarization were unverified. The later
  source-only macOS 26 policy makes those former gates historical.
- The external-link check proves system dispatch, not a specific Books store result, custom URL scheme, or direct local-library item support.
- Bookmark lifecycle code was tested with a fictional temporary file; a later production workflow needs manual repair-flow validation with a deliberately selected non-private test fixture.
- The graph cap is an initial safety bound. Prompt 8 must measure real production rendering, gesture responsiveness, and accessibility at supported scales.
- The SQLite benchmark is a debug spike, not a production query, migration, concurrency, or backup-performance guarantee.

### Prompt 2 readiness

Prompt 1 acceptance conditions are met. Prompt 2 may now create the production `BookAtlas` Xcode project and test targets, using the ADRs above without importing or depending on the experiments.

## Prompt 2 completion record

### Scope and implementation

At the Prompt 2 baseline, `BookAtlas.xcodeproj` had three targets:
`BookAtlas`, `BookAtlasTests`, and `BookAtlasUITests`. The application display
name was `Book Atlas`, the Swift module was `BookAtlas`, the Debug bundle
identifier was the non-personal placeholder `com.example.BookAtlas`, and the
deployment target was macOS 14.0. V1.0.0 later replaces that metadata as
recorded in ADR-0009 and the current development guide.

The root app composes a lightweight value-type navigation state. A native `NavigationSplitView` exposes five independently replaceable pages: 书库, 书单, 标签, 书图, and 设置. It includes native toolbar and command-menu navigation, a nonfunctional search placeholder, semantic layout constants, and shared empty/error placeholder components. The feature pages contain no database, book data, file access, external URLs, graph algorithm, or network behavior.

The original Prompt 2 labels itself “Milestone 1,” but this repository's accepted roadmap assigns Prompt 2 to Milestone 0 and Prompt 3 to Milestone 1. This record follows the repository roadmap.

### Privacy and sandbox check

The standalone Debug build was ad-hoc signed and its entitlements contained App Sandbox and the expected Debug task-allow entitlement only. It contains no network-client entitlement, broad file entitlement, telemetry, or third-party dependency.

### Commands actually run

```sh
xcodebuild -list -project BookAtlas.xcodeproj
xcodebuild -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -derivedDataPath /tmp/bookatlas-production-derived build
xcodebuild -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -derivedDataPath /tmp/bookatlas-production-derived -destination 'platform=macOS,arch=arm64' test
xcodebuild -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -derivedDataPath /tmp/bookatlas-production-standalone-derived build
codesign -d --entitlements :- /tmp/bookatlas-production-standalone-derived/Build/Products/Debug/BookAtlas.app
xcrun xcresulttool get test-results summary --path /tmp/bookatlas-production-derived/Logs/Test/Test-BookAtlas-2026.07.26_09-50-22-+0800.xcresult
```

### Results

- Xcode identified the `BookAtlas` scheme and all three intended targets.
- The production app build succeeded and the UI test launched the signed app.
- The final result passed six tests with no failures: five unit tests and one UI smoke test.
- Unit coverage verifies the five sections, default Library selection, stable titles/identifiers, small/large host layouts, and light/dark appearance layout without crashing.
- UI coverage verifies the sidebar, all five accessibility-identified entries, matching page titles, and the navigation command menu.

### Remaining verification and risks

- At that baseline tests ran on macOS 26.5.2 only and macOS 14 behavior was
  unverified; this is historical and no longer a V1.0.0 compatibility gate.
- UI automation verifies accessible identifiers, not a full VoiceOver session, accent-color change, or user-visible Reduce Motion setting. The shell has no animations to depend on.
- At that baseline release signing, notarization, distribution identity, and a
  final bundle identifier were unconfigured. V1.0.0 is source-only and now has
  a confirmed bundle identifier; Apple binary distribution remains out of scope.

### Prompt 3 readiness

Prompt 2 acceptance conditions are met. Prompt 3 can now add the single production SQLite-backed domain and data layer behind the established application shell, without changing the accepted persistence decision.
