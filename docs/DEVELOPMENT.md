# Development

## Current application

`BookAtlas.xcodeproj` contains the `BookAtlas` macOS application scheme plus `BookAtlasTests` and `BookAtlasUITests`. It targets macOS 14.0, uses only SwiftUI and AppKit supplied by macOS, and is sandboxed. The Debug bundle identifier is the intentional placeholder `com.example.BookAtlas`; release signing, distribution identity, and notarization are not configured.

The application has one direct-SQLite persistence path behind `BookRepository` and the actor-isolated `LibraryCatalogService`. The current schema is version 4. Production opens `~/Library/Application Support/BookAtlas/book-atlas.sqlite`; unit tests and explicit UI-test launches use isolated in-memory or temporary databases. SwiftUI views own presentation only and do not execute SQL, migrations, duplicate rules, or merge transactions.

The current implemented scope is book CRUD, local query and organization, deterministic duplicate review/merge, versioned CSV import with mapping and preview, Markdown/CSV export, full SQLite backup/restore, and a bounded local relationship graph. Prompt 7 passed its third independent review at baseline `b27318c741fee5b4a66e5ad99cb979177285fef5`; Prompt 8 is implemented and awaiting independent review. There is no network client entitlement, external-link action, AI duplicate detector, automatic merge, cloud backup, directory scanner, or whole-library graph. Prompt 8 adds no entitlement, dependency, network, file access, or Schema change.

## Build

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bookatlas-p8-final-build-2 \
  build
```

The Prompt 7 acceptance baseline independently passed the Debug build, 114-test unit/integration suite, and 17-test UI suite with Xcode 26.6 (build 17F113), Swift 6.3.3, and an arm64 Mac running macOS 26.5.2 (build 25F84). On the same host, the final Prompt 8 evidence run produced `BUILD SUCCEEDED`, 132/132 passing unit/integration tests, and 21/21 passing UI tests, with zero failures and zero skips. The command ad-hoc signs the Debug product for local execution; the UI count comes from an unlocked interactive session that successfully initialized XCUIAutomation.

## Unit tests

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -derivedDataPath /tmp/bookatlas-p8-final-unit-2 \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:BookAtlasTests \
  -resultBundlePath /tmp/bookatlas-p8-final-unit-2.xcresult \
  test
```

The suite contains 132 unit, integration, migration, rollback, state, and performance tests. Coverage includes:

- domain validation, editor drafts, navigation, layout, and light/dark appearance smoke checks;
- schema versions 1–4, duplicate-key backfill, new-store creation, data preservation, idempotence, rollback, future-version rejection, and exact per-version backup-schema object validation;
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
- Prompt 6 Exact/Strong reuse during import against both the current library and earlier accepted rows in the same CSV, deterministic Exact/Strong batch order, organization forecasts that exclude skipped rows, execution-time revalidation, tag/list/source creation and deduplication, cancellation, injected fatal rollback, and post-execution redacted reports;
- disk-backed import staging bound to source and mapping fingerprints, 20-row and 80-issue presentation bounds with explicit truncation, stale mapping-generation suppression, parsing/confirmed-import cancellation cleanup, and an isolated 84,354,813-byte near-limit input whose measured end-to-end resident-memory growth was 1,441,792 bytes and process peak growth was 21,921,792 bytes;
- stable Markdown/CSV formats, multiline and empty values, Markdown metacharacter escaping, absolute-path omission, semantic CSV round trips, and formula guards for `=`, `+`, `-`, `@`, tab, and carriage return;
- empty/populated online backups, uncheckpointed WAL data, path-free manifests, physical plus exact application-schema validation, schema 1–4 table/index/trigger/view whitelists, index structure and restored ignored-pair-trigger semantics, every relationship/duplicate-index family, non-overwrite behavior, symlink/corrupt/missing-manifest/future/oversized rejection, old-schema restore migration, 4 GiB and capacity preflights, Cocoa out-of-space mapping, recovery copies, coordinator-confirmed cancellable staging, atomic cancellation-versus-safe-replacement arbitration, delayed-phase suppression, non-cancellable replacement state, three persistent process-interruption boundaries with startup recovery, replacement/reconnect injection, rollback, reopened writes, and controlled-work cleanup;
- fixed 1,000/5,000/10,000 portability baselines and an off-main-actor parsing responsiveness check.
- all five graph evidence families with concrete explanations, evidence merging and deduplication, deterministic weights/order, relationship filters, one/two layers, explicit node/edge/candidate limits, missing center, merged/deleted records, and intentionally separate duplicate versions;
- deterministic empty/single/multi-node layout, fixed center, bounded iteration, cancellation, stale-center rejection, re-entry, selection, dragging, re-centering, empty/error/limit state publication, and accessibility relationship reasons;
- fixed 1,000/5,000/10,000 production graph query/build/layout/first-render/interaction/re-entry/memory baselines plus a 10,000-book off-main-actor responsiveness check.

## UI tests

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -derivedDataPath /tmp/bookatlas-p8-final-ui-2 \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:BookAtlasUITests \
  -resultBundlePath /tmp/bookatlas-p8-final-ui-2.xcresult \
  test
```

The suite contains 21 macOS UI tests. It retains all Prompt 5/6/7 paths and adds detail-to-graph navigation, concrete five-family relationship accessibility, node selection and return to detail, one/two-layer switching, relation filtering, keyboard list selection, re-centering, reset, independently isolated empty/limit states, and disclosed-limit accessibility. UI tests opt into an in-memory store and fixed fictional test-only launch seeds; they do not open a real file panel, user file, or real database.

## Query baseline

`LibraryQueryBenchmarkTests` generates fixed fictional records in a fresh in-memory store for each size and records query construction, bulk tag association, search, multi-filter, and sort durations separately. On the environment above, the recorded Prompt 5 evidence for 1,000/5,000/10,000 books was approximately 1.0/2.2/4.1 ms for search and 9.5/27.4/28.1 ms for the priority-sorted multi-filter query. These are environment-specific evidence, not pass/fail thresholds or performance promises.

`DuplicateDetectionTests.testIndexedCandidateLookupRemainsBoundedAtTenThousandBooks` creates 10,000 fixed fictional records in one in-memory transaction, then performs an indexed Exact lookup. The second NO-GO closure full-suite run recorded `DUPLICATE_CANDIDATE_10000_SECONDS=0.178801` and enforces a one-second regression ceiling on the verified host. Exact and Strong indexed queries are uncapped and order by book UUID. Possible title-token lookup orders by book UUID, evaluates at most the first 250 raw index hits, requests a 251st row to detect truncation, and exposes that state in the review UI. The threshold is a local guard against accidental full-library/pairwise comparison, not a cross-device performance promise.

## Portability baseline

`PortabilityPerformanceTests` creates fresh temporary schema-4 databases and fixed fictional ASCII records for each size. The recorded Prompt 7 final full-suite run on the environment above was:

| Books | CSV parse | Preview | Import | Markdown | CSV export | Backup | Restore | End-to-end resident-memory growth |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1,000 | 0.0017 s | 0.6931 s | 0.6665 s | 0.0384 s | 0.0103 s | 0.7014 s | 1.2995 s | 0 B |
| 5,000 | 0.0079 s | 3.4584 s | 3.4661 s | 0.1912 s | 0.0520 s | 3.5073 s | 6.4677 s | 13,713,408 B |
| 10,000 | 0.0163 s | 6.9620 s | 6.8423 s | 0.3824 s | 0.1049 s | 7.0508 s | 13.0453 s | 56,098,816 B |

These are local observations, not product promises. CSV parsing is measured through the production streaming URL entry point. Preview includes streaming to disk staging plus Exact/Strong evaluation against the formal library and the isolated earlier-batch index; confirmed import streams that staging and revalidates. The broader capped Possible rule remains available through manual duplicate review. The responsiveness test performs a 10,000-row streaming parse in a detached task while a main-actor expectation completes within one second.

## Graph baseline

`GraphPerformanceTests` creates fresh in-memory Schema-4 stores with fixed fictional records. Each projection uses the production indexed repository, builder, deterministic layout, `GraphStore`, and `LocalGraphView`; first render is measured through an `NSHostingView`, interaction performs 100 production state updates, re-entry rebuilds five times, and current resident memory is sampled with `task_info`. The Prompt 8 targeted performance run on the environment above recorded:

| Books | Query | Projection | Layout | First render | 100 interactions | 5 re-entries | Resident-memory growth |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1,000 | 0.0464 s | 0.0012 s | 0.0672 s | 0.0568 s | 0.0008 s | 0.5683 s | 10,829,824 B |
| 5,000 | 0.0455 s | 0.0010 s | 0.0660 s | 0.0382 s | 0.0008 s | 0.5695 s | 12,238,848 B |
| 10,000 | 0.0467 s | 0.0010 s | 0.0751 s | 0.0385 s | 0.0008 s | 0.5923 s | 17,760,256 B |

All three projections reached the deliberate 80-node/79-edge bounded result from a same-author fixture and disclosed candidate truncation. A separate 10,000-book test completed the projection outside the main actor while a main-actor expectation completed within one second. These measurements are local regression evidence, not frame-rate or cross-device promises.

## Known limitations

- Keep `BookAtlas/App/` responsible for composition and lightweight navigation only.
- Keep persistence, migration, and catalog rules out of SwiftUI views.
- Keep App Sandbox enabled and add no network client entitlement unless an accepted ADR and privacy review require it.
- Preserve `Experiments/TechnicalSpikes/` as evidence only; production code must not import it.
- Runtime validation currently covers one Apple-silicon host on macOS 26.5.2; the macOS 14.0 minimum runtime has not been exercised in this closure.
- Automated accessibility identifiers and keyboard paths are covered, but a complete manual VoiceOver audit is not part of Prompt 8.
- Release signing, notarization, and a final non-placeholder bundle identifier remain unconfigured.
- Duplicate heuristics intentionally do not understand every contributor order, edition, translation, or series convention; every candidate remains user-reviewed.
- A truncated Possible lookup does not yet provide pagination; the UI states that only the first 250 deterministic raw token hits were evaluated. Exact and Strong candidates are not truncated.
- CSV import is capped at 100 MiB, 100,000 rows, 1 MiB per field, and 128 columns; only 20 sample rows and 80 issue details are retained for presentation, with both limits disclosed. Same-batch or existing Exact/Strong rows are skipped and reported but do not become persistent ordinary-review candidates because no book is created. CSV cannot carry external links or manual relations; full-fidelity transfer requires a backup.
- Backup format 1 is capped at 4 GiB and uses a 16 MiB free-space safety reserve. Capacity values are filesystem estimates; a later real write error is still handled and reported.
- Backups are intentionally unencrypted and recovery copies are retained until the user manages them through the app container; no automatic retention policy is implemented.
- The graph defaults to one layer and 80 nodes/200 edges, allows a second layer, and has hard caps of 250/500. It does not provide clustering, saved layouts, a global graph, arbitrary graph queries, or cross-library relationships.
- Prompt 8 does not add external-link actions. Prompt 9 has not started.
