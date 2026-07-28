# Development

## Current application

`BookAtlas.xcodeproj` contains the `BookAtlas` macOS application scheme plus `BookAtlasTests` and `BookAtlasUITests`. It targets macOS 14.0, uses only SwiftUI and AppKit supplied by macOS, and is sandboxed. The Debug bundle identifier is the intentional placeholder `com.example.BookAtlas`; release signing, distribution identity, and notarization are not configured.

The application has one direct-SQLite persistence path behind `BookRepository` and the actor-isolated `LibraryCatalogService`. The current schema is version 4. Production opens `~/Library/Application Support/BookAtlas/book-atlas.sqlite`; unit tests and explicit UI-test launches use isolated in-memory or temporary databases. SwiftUI views own presentation only and do not execute SQL, migrations, duplicate rules, or merge transactions.

The current implemented scope is book CRUD, local query and organization, deterministic explainable duplicate review, persistent keep-separate decisions, and explicitly confirmed field-level merging. There is no network client entitlement, external-link action, import/export, backup/restore, graph UI, AI duplicate detector, or automatic merge.

## Build

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -derivedDataPath /tmp/bookatlas-prompt6-build \
  build
```

The Prompt 6 closure is verified with Xcode 26.6 (build 17F113), Swift 6.3.3, and an arm64 Mac running macOS 26.5.2 (build 25F84). The command ad-hoc signs the Debug product for local execution.

## Unit tests

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -derivedDataPath /tmp/bookatlas-prompt6-unit \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:BookAtlasTests \
  test
```

The suite contains 61 unit and integration tests. Coverage includes:

- domain validation, editor drafts, navigation, layout, and light/dark appearance smoke checks;
- schema versions 1–4, duplicate-key backfill, new-store creation, data preservation, idempotence, rollback, and future-version rejection;
- repository CRUD, relationships, cascades, transaction rollback, and in-memory isolation;
- title/original-title/author/ISBN search, each structured filter, documented filter composition, filter clearing, and stable created/updated/priority sorting;
- tag, collection, and source normalization, rename, deletion, membership removal, duplicate-safe and multiple associations, derived counts, transactional tag merge and rollback, filter cleanup, and organizer snapshot publication;
- deterministic 1,000-, 5,000-, and 10,000-book query baselines.
- ISBN-10/13 validation; conservative title/author normalization; Exact/Strong/Possible boundaries; version, translation, series, similar-title, and conflicting-ISBN cases;
- ignored-pair creation, lookup, persistence after reopen, suppression, and identity-edit invalidation;
- save interception, cancellation, keep-separate behavior, merge preview/defaults/field choices, association union/deduplication, relation redirection/rejection, source deletion last, and full transaction rollback;
- an indexed 10,000-book duplicate-candidate lookup with a one-second regression ceiling on the verified host.

## UI tests

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -derivedDataPath /tmp/bookatlas-prompt6-ui \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:BookAtlasUITests \
  test
```

The suite contains 11 macOS UI tests. It covers the Prompt 5 paths plus duplicate save interception, readable evidence/uncertainty, Escape cancellation without saving, merge preview, explicit destructive confirmation, retained-record result, manual-cleanup empty state, and keyboard dismissal. UI tests opt into an in-memory store, and tests needing pre-existing books use a fixed fictional seed through a test-only launch argument.

## Query baseline

`LibraryQueryBenchmarkTests` generates fixed fictional records in a fresh in-memory store for each size and records query construction, bulk tag association, search, multi-filter, and sort durations separately. On the environment above, the recorded Prompt 5 evidence for 1,000/5,000/10,000 books was approximately 1.0/2.2/4.1 ms for search and 9.5/27.4/28.1 ms for the priority-sorted multi-filter query. These are environment-specific evidence, not pass/fail thresholds or performance promises.

`DuplicateDetectionTests.testIndexedCandidateLookupRemainsBoundedAtTenThousandBooks` creates 10,000 fixed fictional records in one in-memory transaction, then performs an indexed Exact lookup. The final Prompt 6 full-suite run recorded `DUPLICATE_CANDIDATE_10000_SECONDS=0.179273` and enforces a one-second regression ceiling on the verified host. The threshold is a local guard against accidental full-library/pairwise comparison, not a cross-device performance promise.

## Known limitations

- Keep `BookAtlas/App/` responsible for composition and lightweight navigation only.
- Keep persistence, migration, and catalog rules out of SwiftUI views.
- Keep App Sandbox enabled and add no network client entitlement unless an accepted ADR and privacy review require it.
- Preserve `Experiments/TechnicalSpikes/` as evidence only; production code must not import it.
- Runtime validation currently covers one Apple-silicon host on macOS 26.5.2; the macOS 14.0 minimum runtime has not been exercised in this closure.
- Automated accessibility identifiers and keyboard paths are covered, but a complete manual VoiceOver audit is not part of Prompt 6 closure.
- Release signing, notarization, and a final non-placeholder bundle identifier remain unconfigured.
- Duplicate heuristics intentionally do not understand every contributor order, edition, translation, or series convention; every candidate remains user-reviewed.
- Prompt 6 does not add an import integration or graph UI. A successful merge leaves one persisted book ID for future graph projection, while explicitly retained records remain separate.
