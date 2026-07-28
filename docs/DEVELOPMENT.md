# Development

## Current application

`BookAtlas.xcodeproj` contains the `BookAtlas` macOS application scheme plus `BookAtlasTests` and `BookAtlasUITests`. It targets macOS 14.0, uses only SwiftUI and AppKit supplied by macOS, and is sandboxed. The Debug bundle identifier is the intentional placeholder `com.example.BookAtlas`; release signing, distribution identity, and notarization are not configured.

The application has one direct-SQLite persistence path behind `BookRepository` and the actor-isolated `LibraryCatalogService`. The current schema is version 4. Production opens `~/Library/Application Support/BookAtlas/book-atlas.sqlite`; unit tests and explicit UI-test launches use isolated in-memory or temporary databases. SwiftUI views own presentation only and do not execute SQL, migrations, duplicate rules, or merge transactions.

The current implemented scope is book CRUD, local query and organization, deterministic duplicate review/merge, versioned CSV import with mapping and preview, Markdown/CSV export, and full SQLite backup/restore. There is no network client entitlement, external-link action, graph UI, AI duplicate detector, automatic merge, cloud backup, or directory scanner. Prompt 7 adds only the App Sandbox user-selected read/write entitlement used by explicit system file panels.

## Build

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bookatlas-p7-final-build \
  build
```

Prompt 7 is verified with Xcode 26.6 (build 17F113), Swift 6.3.3, and an arm64 Mac running macOS 26.5.2 (build 25F84). The command ad-hoc signs the Debug product for local execution.

## Unit tests

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -derivedDataPath /tmp/bookatlas-p7-final-unit \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:BookAtlasTests \
  -resultBundlePath /tmp/bookatlas-p7-final-unit.xcresult \
  test
```

The suite contains 92 unit, integration, migration, rollback, and performance tests. Coverage includes:

- domain validation, editor drafts, navigation, layout, and light/dark appearance smoke checks;
- schema versions 1–4, duplicate-key backfill, new-store creation, data preservation, idempotence, rollback, and future-version rejection;
- repository CRUD, relationships, cascades, transaction rollback, and in-memory isolation;
- title/original-title/author/ISBN search, each structured filter, documented filter composition, filter clearing, and stable created/updated/priority sorting;
- tag, collection, and source normalization, rename, deletion, membership removal, duplicate-safe and multiple associations, derived counts, transactional tag merge and rollback, filter cleanup, and organizer snapshot publication;
- deterministic 1,000-, 5,000-, and 10,000-book query baselines.
- ISBN-10/13 validation; conservative title/author normalization; Exact/Strong/Possible boundaries; version, translation, series, similar-title, and conflicting-ISBN cases;
- ignored-pair creation, lookup, persistence after reopen, suppression, identity-edit invalidation, and pair-only handling across three simultaneous candidates without duplicate creation;
- save interception, cancellation, draft-preserving existing-record viewing, keep-separate behavior, merge preview/defaults/field choices, concrete association outcomes, association union/deduplication, external-link label fill/equal/conflict cases, relation redirection/rejection, source deletion last, and full transaction rollback;
- deterministic uncapped Exact/Strong retrieval beyond 250 matches; deterministic 250-hit Possible lookup with truncation surfaced to the review state;
- an indexed 10,000-book duplicate-candidate lookup with a one-second regression ceiling on the verified host.
- streaming UTF-8/BOM CSV parsing, quotes/commas/multiline fields, malformed input, file/row/field/column limits, reordered and unknown columns, required-field errors, mapping, explicit preview limits, and preview/cancel no-write behavior;
- Prompt 6 Exact/Strong reuse during import, duplicate-row skipping, tag/list/source creation and deduplication, recoverable-row statistics, cancellation, injected fatal rollback, and redacted error reports;
- stable Markdown/CSV formats, multiline and empty values, Markdown metacharacter escaping, absolute-path omission, semantic CSV round trips, and formula guards for `=`, `+`, `-`, `@`, tab, and carriage return;
- empty/populated online backups, uncheckpointed WAL data, path-free manifests, integrity checks, non-overwrite behavior, symlink/corrupt/missing-manifest/future-version rejection, schema-3 restore migration, recovery copies, staged replacement, interruption/disk/replacement/reconnect injection, rollback, reopened writes, and temporary-work cleanup;
- fixed 1,000/5,000/10,000 portability baselines and an off-main-actor parsing responsiveness check.

## UI tests

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -derivedDataPath /tmp/bookatlas-p7-final-ui \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:BookAtlasUITests \
  -resultBundlePath /tmp/bookatlas-p7-final-ui.xcresult \
  test
```

The suite contains 15 macOS UI tests. It retains all Prompt 5/6 paths and adds local import-preview counts, mapping, concrete fictional sample accessibility, restore replacement warning, explicit confirmation controls, and Escape cancellation. UI tests opt into an in-memory store and fixed fictional test-only launch seeds; they do not open a real file panel or user file.

## Query baseline

`LibraryQueryBenchmarkTests` generates fixed fictional records in a fresh in-memory store for each size and records query construction, bulk tag association, search, multi-filter, and sort durations separately. On the environment above, the recorded Prompt 5 evidence for 1,000/5,000/10,000 books was approximately 1.0/2.2/4.1 ms for search and 9.5/27.4/28.1 ms for the priority-sorted multi-filter query. These are environment-specific evidence, not pass/fail thresholds or performance promises.

`DuplicateDetectionTests.testIndexedCandidateLookupRemainsBoundedAtTenThousandBooks` creates 10,000 fixed fictional records in one in-memory transaction, then performs an indexed Exact lookup. The final NO-GO closure full-suite run recorded `DUPLICATE_CANDIDATE_10000_SECONDS=0.192052` and enforces a one-second regression ceiling on the verified host. Exact and Strong indexed queries are uncapped and order by book UUID. Possible title-token lookup orders by book UUID, evaluates at most the first 250 raw index hits, requests a 251st row to detect truncation, and exposes that state in the review UI. The threshold is a local guard against accidental full-library/pairwise comparison, not a cross-device performance promise.

## Portability baseline

`PortabilityPerformanceTests` creates fresh temporary schema-4 databases and fixed fictional ASCII records for each size. The recorded Prompt 7 focused run on the environment above was:

| Books | CSV parse | Preview | Import | Markdown | CSV export | Backup | Restore | Peak-memory growth |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1,000 | 0.0016 s | 0.0755 s | 0.6147 s | 0.0396 s | 0.0103 s | 0.2943 s | 0.0570 s | 14,729,216 B |
| 5,000 | 0.0081 s | 0.3822 s | 3.1173 s | 0.1941 s | 0.0520 s | 1.4921 s | 0.3300 s | 36,732,928 B |
| 10,000 | 0.0161 s | 0.7725 s | 6.3536 s | 0.3840 s | 0.1035 s | 2.9828 s | 0.7625 s | 45,006,848 B |

These are local observations, not product promises. Preview and confirmed import use the same uncapped Exact/Strong indexed rules as ordinary create-save interception; the broader capped Possible rule remains available through manual duplicate review. The responsiveness test performs a 10,000-row parse in a detached task while a main-actor expectation completes within one second.

## Known limitations

- Keep `BookAtlas/App/` responsible for composition and lightweight navigation only.
- Keep persistence, migration, and catalog rules out of SwiftUI views.
- Keep App Sandbox enabled and add no network client entitlement unless an accepted ADR and privacy review require it.
- Preserve `Experiments/TechnicalSpikes/` as evidence only; production code must not import it.
- Runtime validation currently covers one Apple-silicon host on macOS 26.5.2; the macOS 14.0 minimum runtime has not been exercised in this closure.
- Automated accessibility identifiers and keyboard paths are covered, but a complete manual VoiceOver audit is not part of Prompt 7.
- Release signing, notarization, and a final non-placeholder bundle identifier remain unconfigured.
- Duplicate heuristics intentionally do not understand every contributor order, edition, translation, or series convention; every candidate remains user-reviewed.
- A truncated Possible lookup does not yet provide pagination; the UI states that only the first 250 deterministic raw token hits were evaluated. Exact and Strong candidates are not truncated.
- CSV import is capped at 100 MiB, 100,000 rows, 1 MiB per field, and 128 columns; only 20 sample rows are rendered, with the limit disclosed. CSV cannot carry external links or manual relations; full-fidelity transfer requires a backup.
- Backups are intentionally unencrypted and recovery copies are retained until the user manages them through the app container; no automatic retention policy is implemented.
- Prompt 7 does not add graph UI or external-link actions and does not begin Prompt 8.
