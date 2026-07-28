# Development

## Current application

`BookAtlas.xcodeproj` contains the `BookAtlas` macOS application scheme plus `BookAtlasTests` and `BookAtlasUITests`. It targets macOS 14.0, uses only SwiftUI and AppKit supplied by macOS, and is sandboxed. The Debug bundle identifier is the intentional placeholder `com.example.BookAtlas`; release signing, distribution identity, and notarization are not configured.

The application has one direct-SQLite persistence path behind `BookRepository` and the actor-isolated `LibraryCatalogService`. The current schema is version 3. Production opens `~/Library/Application Support/BookAtlas/book-atlas.sqlite`; unit tests and explicit UI-test launches use isolated in-memory databases. SwiftUI views own presentation only and do not execute SQL or migrations.

The current implemented scope is book CRUD, unified local search, structured filtering, stable sorting, and management of tags, collections, recommendation sources, and their book memberships. There is no network client entitlement, external-link action, import/export, backup/restore, graph implementation, or duplicate-book workflow.

## Build

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -derivedDataPath /tmp/bookatlas-prompt5-build \
  build
```

The Prompt 5 closure was verified with Xcode 26.6 (build 17F113), Swift 6.3.3, and an arm64 Mac running macOS 26.5.2 (build 25F84). The command ad-hoc signs the Debug product for local execution.

## Unit tests

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -derivedDataPath /tmp/bookatlas-prompt5-unit \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:BookAtlasTests \
  test
```

The suite contains 41 unit and integration tests. Coverage includes:

- domain validation, editor drafts, navigation, layout, and light/dark appearance smoke checks;
- schema versions 1–3, data-preserving migration, idempotence, rollback, and future-version rejection;
- repository CRUD, relationships, cascades, transaction rollback, and in-memory isolation;
- title/original-title/author/ISBN search, each structured filter, documented filter composition, filter clearing, and stable created/updated/priority sorting;
- tag, collection, and source normalization, rename, deletion, membership removal, duplicate-safe and multiple associations, derived counts, transactional tag merge and rollback, filter cleanup, and organizer snapshot publication;
- deterministic 1,000-, 5,000-, and 10,000-book query baselines.

## UI tests

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -derivedDataPath /tmp/bookatlas-prompt5-ui \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:BookAtlasUITests \
  test
```

The suite contains 9 macOS UI tests. It covers navigation and empty/error states; validation; create/edit/cancel/save/delete behavior; keyboard commands and list selection; combined search, status filtering, no-result and clear-filter states, and sort access; tag creation, rename, confirmed merge, and merge result; and collection/source creation. UI tests opt into an in-memory store, and tests needing pre-existing books opt into a fixed fictional seed through a test-only launch argument.

## Query baseline

`LibraryQueryBenchmarkTests` generates fixed fictional records in a fresh in-memory store for each size and records query construction, bulk tag association, search, multi-filter, and sort durations separately. On the environment above, the recorded Prompt 5 evidence for 1,000/5,000/10,000 books was approximately 1.0/2.2/4.1 ms for search and 9.5/27.4/28.1 ms for the priority-sorted multi-filter query. These are environment-specific evidence, not pass/fail thresholds or performance promises.

## Known limitations

- Keep `BookAtlas/App/` responsible for composition and lightweight navigation only.
- Keep persistence, migration, and catalog rules out of SwiftUI views.
- Keep App Sandbox enabled and add no network client entitlement unless an accepted ADR and privacy review require it.
- Preserve `Experiments/TechnicalSpikes/` as evidence only; production code must not import it.
- Runtime validation currently covers one Apple-silicon host on macOS 26.5.2; the macOS 14.0 minimum runtime has not been exercised in this closure.
- Automated accessibility identifiers and keyboard paths are covered, but a complete manual VoiceOver audit is not part of Prompt 5 closure.
- Release signing, notarization, and a final non-placeholder bundle identifier remain unconfigured.
- Prompt 6 duplicate detection, ignored candidates, book merge, merge migration, and duplicate review UI are not implemented.
