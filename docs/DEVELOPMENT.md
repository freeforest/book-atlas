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

The Prompt 7 Debug build and 107-test unit/integration suite are verified with Xcode 26.6 (build 17F113), Swift 6.3.3, and an arm64 Mac running macOS 26.5.2 (build 25F84). The command ad-hoc signs the Debug product for local execution. The final 17-test UI rerun remains pending because XCTest cannot initialize XCUIAutomation while the interactive macOS session is locked; two attempts produced zero executed UI test cases and the system-level `LocalAuthentication` error “System authentication is running.”

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

The suite contains 107 unit, integration, migration, rollback, state, and performance tests. Coverage includes:

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
- Prompt 6 Exact/Strong reuse during import against both the current library and earlier accepted rows in the same CSV, deterministic Exact/Strong batch order, organization forecasts that exclude skipped rows, execution-time revalidation, tag/list/source creation and deduplication, cancellation, injected fatal rollback, and post-execution redacted reports;
- disk-backed import staging bound to source and mapping fingerprints, 20-row and 80-issue presentation bounds with explicit truncation, stale mapping-generation suppression, parsing/confirmed-import cancellation cleanup, and an isolated 84,354,813-byte near-limit input whose measured end-to-end resident-memory growth was 1,441,792 bytes and process peak growth was 21,921,792 bytes;
- stable Markdown/CSV formats, multiline and empty values, Markdown metacharacter escaping, absolute-path omission, semantic CSV round trips, and formula guards for `=`, `+`, `-`, `@`, tab, and carriage return;
- empty/populated online backups, uncheckpointed WAL data, path-free manifests, physical plus application-schema validation, every relationship/duplicate-index family, non-overwrite behavior, symlink/corrupt/missing-manifest/future/oversized rejection, schema-3 restore migration, 4 GiB and capacity preflights, Cocoa out-of-space mapping, recovery copies, cancellable staging, non-cancellable replacement state, three persistent process-interruption boundaries with startup recovery, replacement/reconnect injection, rollback, reopened writes, and controlled-work cleanup;
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

The suite contains 17 macOS UI tests. It retains all Prompt 5/6 paths and adds local import-preview counts, mapping, concrete fictional sample accessibility, restore replacement warning, explicit confirmation controls, an accessible inspection-progress panel with Escape cancellation, and an accessible safe-replacement state whose Cancel control is disabled and which ignores Escape. UI tests opt into an in-memory store and fixed fictional test-only launch seeds; they do not open a real file panel or user file. The complete suite must be rerun from an unlocked interactive session before independent re-review.

## Query baseline

`LibraryQueryBenchmarkTests` generates fixed fictional records in a fresh in-memory store for each size and records query construction, bulk tag association, search, multi-filter, and sort durations separately. On the environment above, the recorded Prompt 5 evidence for 1,000/5,000/10,000 books was approximately 1.0/2.2/4.1 ms for search and 9.5/27.4/28.1 ms for the priority-sorted multi-filter query. These are environment-specific evidence, not pass/fail thresholds or performance promises.

`DuplicateDetectionTests.testIndexedCandidateLookupRemainsBoundedAtTenThousandBooks` creates 10,000 fixed fictional records in one in-memory transaction, then performs an indexed Exact lookup. The final NO-GO closure full-suite run recorded `DUPLICATE_CANDIDATE_10000_SECONDS=0.180154` and enforces a one-second regression ceiling on the verified host. Exact and Strong indexed queries are uncapped and order by book UUID. Possible title-token lookup orders by book UUID, evaluates at most the first 250 raw index hits, requests a 251st row to detect truncation, and exposes that state in the review UI. The threshold is a local guard against accidental full-library/pairwise comparison, not a cross-device performance promise.

## Portability baseline

`PortabilityPerformanceTests` creates fresh temporary schema-4 databases and fixed fictional ASCII records for each size. The recorded Prompt 7 final full-suite run on the environment above was:

| Books | CSV parse | Preview | Import | Markdown | CSV export | Backup | Restore | End-to-end resident-memory growth |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1,000 | 0.0016 s | 0.7036 s | 0.6796 s | 0.0388 s | 0.0102 s | 0.6968 s | 1.2890 s | 0 B |
| 5,000 | 0.0080 s | 3.5270 s | 3.4803 s | 0.1927 s | 0.0517 s | 3.5032 s | 6.4669 s | 13,746,176 B |
| 10,000 | 0.0163 s | 7.1103 s | 7.0352 s | 0.3835 s | 0.1037 s | 7.0731 s | 13.1140 s | 56,164,352 B |

These are local observations, not product promises. CSV parsing is measured through the production streaming URL entry point. Preview includes streaming to disk staging plus Exact/Strong evaluation against the formal library and the isolated earlier-batch index; confirmed import streams that staging and revalidates. The broader capped Possible rule remains available through manual duplicate review. The responsiveness test performs a 10,000-row streaming parse in a detached task while a main-actor expectation completes within one second.

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
- CSV import is capped at 100 MiB, 100,000 rows, 1 MiB per field, and 128 columns; only 20 sample rows and 80 issue details are retained for presentation, with both limits disclosed. Same-batch or existing Exact/Strong rows are skipped and reported but do not become persistent ordinary-review candidates because no book is created. CSV cannot carry external links or manual relations; full-fidelity transfer requires a backup.
- Backup format 1 is capped at 4 GiB and uses a 16 MiB free-space safety reserve. Capacity values are filesystem estimates; a later real write error is still handled and reported.
- Backups are intentionally unencrypted and recovery copies are retained until the user manages them through the app container; no automatic retention policy is implemented.
- Prompt 7 does not add graph UI or external-link actions and does not begin Prompt 8.
