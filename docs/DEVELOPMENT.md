# Development

## Current application

`BookAtlas.xcodeproj` contains the `BookAtlas` macOS application scheme plus `BookAtlasTests` and `BookAtlasUITests`. It targets macOS 14.0, uses only SwiftUI and AppKit supplied by macOS, and is sandboxed. The Debug bundle identifier is the intentional placeholder `com.example.BookAtlas`; release signing, distribution identity, and notarization are not configured.

The application has one direct-SQLite persistence path behind `BookRepository` and the actor-isolated `LibraryCatalogService`. The current schema is version 5 with migration path `1 → 2 → 3 → 4 → 5`. Production opens `~/Library/Application Support/BookAtlas/book-atlas.sqlite`; unit tests and explicit UI-test launches use isolated in-memory or temporary databases. The ordinary library query is paged: the production first page is 200 rows, every filtered query returns an exact total, and subsequent 200-row pages are requested explicitly. An explicit focus request returns that same bounded page plus at most one book selected by UUID under the same filters; it does not scan preceding pages or expand the page size. SwiftUI views own presentation only and do not execute SQL, migrations, duplicate rules, merge transactions, `NSWorkspace`, `NSOpenPanel`, `NSPasteboard`, or bookmark operations.

The accepted scope is book CRUD, local query and organization, deterministic duplicate review/merge, versioned CSV import with mapping and preview, Markdown/CSV export, full SQLite backup/restore, a bounded local relationship graph, and user-initiated external reading entries. Prompt 7 passed its third independent review at baseline `b27318c741fee5b4a66e5ad99cb979177285fef5`; Prompt 8 passed its second independent review at baseline `6ae90dd50ee71f574e0b4cc1ffccfd7e4c2e71aa`; Prompt 9 passed independent review at baseline `1f7a35cda11fcafd23aacab0cb5c72e811327d0b`. Prompt 9's independent evidence is a successful Debug build, 171/171 unit/integration/migration/security/performance tests, and 26/26 UI tests. Prompt 10 quality and open-source preparation is implemented and awaits independent review. There is no network client entitlement, AI duplicate detector, automatic merge, cloud backup, directory scanner, or whole-library graph.

## Build

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bookatlas-p9-nogo2-final-build \
  build
```

The Prompt 7 acceptance baseline independently passed the Debug build, 114-test unit/integration suite, and 17-test UI suite with Xcode 26.6 (build 17F113), Swift 6.3.3, and an arm64 Mac running macOS 26.5.2 (build 25F84). Prompt 8 was formally accepted after its second independent review at baseline `6ae90dd50ee71f574e0b4cc1ffccfd7e4c2e71aa`: the independent Debug build succeeded, 146/146 unit/integration/performance tests passed, and 22/22 macOS UI tests ran in an interactive session after XCUIAutomation initialized and passed, with zero failures and zero skips. The command ad-hoc signs the Debug product for local execution; a UI count is valid only from an unlocked interactive session that successfully initializes XCUIAutomation.

Prompt 9 passed independent review at the baseline recorded above. Prompt 10 validation uses new `/tmp` build and result-bundle paths; a result is reported only when the corresponding command actually completed.

### Prompt 10 closure validation

The implementation closure completed both local build configurations:

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bookatlas-p10-nogo5-final-debug \
  build

xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bookatlas-p10-nogo5-final-release \
  build
```

Both commands reported `BUILD SUCCEEDED`. The Release product is ad-hoc
signed with Hardened Runtime for local verification; its effective
entitlements are App Sandbox, user-selected read/write, and app-scoped
bookmarks only. `get-task-allow` remains present only in Debug. This is not
distribution signing, notarization, or release evidence.

The complete final test commands were:

```sh
xcodebuild test \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bookatlas-p10-nogo5-final-tests \
  -resultBundlePath /tmp/bookatlas-p10-nogo5-final-tests.xcresult \
  -only-testing:BookAtlasTests

xcodebuild test \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bookatlas-p10-nogo5-final-ui-clean \
  -resultBundlePath /tmp/bookatlas-p10-nogo5-final-ui-clean.xcresult \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -only-testing:BookAtlasUITests
```

The unit/integration/migration/security/performance command executed 190
tests: 190 passed, zero failed, zero skipped. The UI command initialized
XCUIAutomation in the interactive macOS session and executed 37 tests: 37
passed, zero failed, zero skipped. Prompt 10 adds the historical Schema 1–5
domain-data matrix, explicit Command-F search-focus state and UI coverage,
three-run database-open/first-page/tag-count and Schema 1–4→5 migration
measurements, and three-run XCUI cold-launch and sustained-scroll metrics at
1k/5k/10k. This closure additionally covers exact result counts and bounded
pagination at 501/1,001/10,000 rows, retry-safe append failures, stable page
boundaries, search/filter/sort resets, mutation consistency, and page-out UUID
identity after graph focus and create/edit/merge. A missing, deleted, or
filter-excluded explicit target clears selection and publishes a redacted
recoverable state; it never falls back to the first row. Exact raw
values, ranges, tool failures, and noise are recorded in
[`PERFORMANCE.md`](PERFORMANCE.md).

The missing/excluded state is rendered before generic empty-library and
no-results placeholders even when the bounded page contains zero rows.
`requestedBookUnavailable` shows “找不到请求的书籍”.
`outsideCurrentResults` shows “所选书籍不在当前结果中” and an independently
identified keyboard/accessibility Button that clears search and filters.
Store and real XCUI regressions cover both zero-row states, verify that no
unrelated detail appears, and verify recovery to the normal 200-row page.

The accessible result value publishes both the count and page readiness
(`可以继续加载`, `正在加载下一页`, retry, or terminal state) as one
observable state. This prevents a following Shift-Command-L from seeing the
new count before the load-more action has actually become available.

The catalog protocol requires every implementation to return an exact
`totalCount`; there is no default `offset + returnedCount` approximation.
Explicit selection requests are resolved with the first page and, only when
needed, one query-filtered primary-key lookup. The requested target is exposed
as a separate accessible “已定位书籍” row until normal pagination reaches it.
Query/focus tasks carry a request generation and verify cancellation after
each await, so a late focus, query, or page result cannot replace a newer
selection and page atomically published by the store.

Accessibility Inspector was actually launched during the earlier attempt. On
2026-08-03 a second attempt started the Debug app against an in-memory fixed
fictional seed. The supported Computer Use runtime enumerated running
applications, but its native pipe closed before the first Book Atlas app-state
or accessibility-tree response. The task execution surface therefore still could
not safely select Inspector targets, read results, drive VoiceOver, change
system accessibility/appearance settings, or inspect the desktop. No human
accessibility or visual item is reported as passed. The per-area BLOCKED record is in
[`QUALITY_AUDIT.md`](QUALITY_AUDIT.md). These are implementation results
awaiting independent review, not a Prompt 10 acceptance decision.

The storage/migration baseline is the unit test
`LibraryQueryBenchmarkTests.testPromptTenOpenInitialLoadTagCountAndHistoricalMigrationBaselines`.
The six UI performance tests are named
`testPerformanceColdLaunchWith{One,Five,Ten}ThousandBooks` and
`testPerformanceSustainedListScrollingWith{One,Five,Ten}ThousandBooks`.
Each metric uses three measured iterations. Launch data preparation is outside
the `XCTApplicationLaunchMetric` closure: a separate UI-test process creates a
fixed-fictional current Schema 5 database, closes it, and verifies its exact
1,000/5,000/10,000 count. Every measured process opens that existing file
without SQLite's create flag, runs the normal restore/version checks, and
publishes the 200-row first page plus exact total.

The performance arguments are test-only and accept an opaque canonical UUID,
not a path:

```sh
-BookAtlasPerformancePrepareLibrary <UUID> 10000
-BookAtlasPerformanceUseExistingLibrary <same UUID>
-BookAtlasPerformanceCleanupLibrary <same UUID>
```

Only `1000`, `5000`, and `10000` are accepted. The UUID deterministically
selects one child of the process temporary root; symlinks, non-regular files,
unknown artifacts, missing databases, malformed/unknown performance flags,
and uncontrolled paths fail closed. Invalid performance input never falls
back to Application Support. Cleanup removes only the validated database,
WAL/SHM/journal sidecars, and then-empty UUID directory.

Release Instruments must use the same three-phase semantics: run preparation
outside the App Launch trace, trace only the
`-BookAtlasPerformanceUseExistingLibrary` process, verify the disclosed first
page/total, then run cleanup. In this closure the preparation step ran, but
authorization for the measured desktop Instruments launch was unavailable
from the task execution surface. No Release launch value is therefore
reported; the older in-process-seeding numbers are not a substitute.

## Unit tests

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -derivedDataPath /tmp/bookatlas-p9-nogo2-final-unit \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:BookAtlasTests \
  -resultBundlePath /tmp/bookatlas-p9-nogo2-final-unit.xcresult \
  test
```

The independently accepted Prompt 9 run executed all 171 unit, integration, migration, rollback, security, state, and performance tests: 171 passed, zero failed, and zero skipped. Coverage includes:

- domain validation, editor drafts, navigation, layout, and light/dark appearance smoke checks;
- schema versions 1–5, duplicate-key backfill, local-file-reference migration, new-store creation, data preservation, idempotence, rollback, future-version rejection, and exact per-version backup-schema object validation;
- repository book/web-link/local-file CRUD, relationships, cascades, transaction rollback, and in-memory isolation;
- title/original-title/author/ISBN search, each structured filter, documented filter composition, filter clearing, and stable created/updated/priority sorting;
- tag, collection, and source normalization, rename, deletion, membership removal, duplicate-safe and multiple associations, derived counts, transactional tag merge and rollback, filter cleanup, and organizer snapshot publication;
- deterministic 1,000-, 5,000-, and 10,000-book query baselines;
- exact-total paging at 501, 1,001, and 10,000 rows; stable first/next/last
  pages without duplicate or missing IDs; reset after search/filter/sort;
  and delete/merge consistency;
- three-run Schema 5 database-open/version checks, default 200-row first loads,
  grouped 32-tag usage counts, and formal Schema 1/2/3/4→5 migration
  measurements at 1,000/5,000/10,000 fixed fictional books;
- ISBN-10/13 validation; conservative title/author normalization; Exact/Strong/Possible boundaries; version, translation, series, similar-title, and conflicting-ISBN cases;
- ignored-pair creation, lookup, persistence after reopen, suppression, identity-edit invalidation, and pair-only handling across three simultaneous candidates without duplicate creation;
- save interception, cancellation, draft-preserving existing-record viewing, keep-separate behavior, merge preview/defaults/field choices, concrete association outcomes, association union/deduplication, external-link label fill/equal/conflict cases, local-file-reference preservation, relation redirection/rejection, source deletion last, and full transaction rollback;
- deterministic uncapped Exact/Strong retrieval beyond 250 matches; deterministic 250-hit Possible lookup with truncation surfaced to the review state;
- an indexed 10,000-book duplicate-candidate lookup with a one-second regression ceiling on the verified host.
- streaming UTF-8/BOM CSV parsing, quotes/commas/multiline fields, malformed input, file/row/field/column limits, reordered and unknown columns, required-field errors, mapping, explicit preview limits, and preview/cancel no-write behavior;
- Prompt 6 Exact/Strong reuse during import against both the current library and earlier accepted rows in the same CSV, deterministic Exact/Strong batch order, organization forecasts that exclude skipped rows, execution-time revalidation, tag/list/source creation and deduplication, cancellation, injected fatal rollback, and post-execution redacted reports;
- disk-backed import staging bound to source and mapping fingerprints, 20-row and 80-issue presentation bounds with explicit truncation, stale mapping-generation suppression, parsing/confirmed-import cancellation cleanup, and an isolated 84,354,813-byte near-limit input whose measured end-to-end resident-memory growth was 1,441,792 bytes and process peak growth was 21,921,792 bytes;
- stable Markdown/CSV formats, multiline and empty values, Markdown metacharacter escaping, absolute-path omission, semantic CSV round trips, and formula guards for `=`, `+`, `-`, `@`, tab, and carriage return;
- empty/populated online backups, uncheckpointed WAL data, path-free manifests, physical plus exact application-schema validation, schema 1–5 table/index/trigger/view whitelists, index structure and restored ignored-pair-trigger semantics, every relationship/duplicate-index/local-file family, non-overwrite behavior, symlink/corrupt/missing-manifest/future/oversized rejection, old-schema restore migration through 5, 4 GiB and capacity preflights, Cocoa out-of-space mapping, recovery copies, coordinator-confirmed cancellable staging, atomic cancellation-versus-safe-replacement arbitration, delayed-phase suppression, non-cancellable replacement state, three persistent process-interruption boundaries with startup recovery, replacement/reconnect injection, rollback, reopened writes, and controlled-work cleanup;
- fixed 1,000/5,000/10,000 portability baselines and an off-main-actor parsing responsiveness check.
- all five graph evidence families with concrete explanations, evidence merging and deduplication, deterministic weights/order, relationship filters, one/two layers, explicit node/edge/candidate limits, missing center, merged/deleted records, and intentionally separate duplicate versions;
- deterministic empty/single/multi-node layout, fixed center, bounded iteration, cancellation, stale-center rejection, re-entry, selection, dragging, re-centering, empty/error/limit state publication, and accessibility relationship reasons;
- production Canvas interaction-state regressions for 10/20/30 cumulative pan input, fixed pan-versus-node drag mode, zoom/pan inverse coordinates, new gesture origins, cancellation/end cleanup, and viewport reset;
- catalog-owned graph-content revision integration across identity edits, tag/list/source/manual evidence add/remove, neighbor and center deletion, retained/source merge identities, CSV import, database restore, changed-data re-entry, unchanged-data layout retention, and stale slow-build suppression;
- fixed 1,000/5,000/10,000 production graph query/build/layout/first-render/interaction/re-entry/memory baselines plus a 10,000-book off-main-actor responsiveness check.
- strict HTTPS acceptance/rejection, the 2,048-byte bound, raw and percent-decoded C0/DEL controls, credentials, malformed percent encoding, empty/nondigit/signed/zero/over-range ports, accepted ports 1/443/65535, deterministic ASCII-host display, HTTP/custom-scheme rejection, IDN/punycode rejection, validation before save/open/generated search dispatch, legal Unicode/percent encoding, and no automatic dispatch;
- Apple Books supported/unavailable/unsupported/unverified capability states and deterministic saved-store/search/launch/copy/other-HTTPS fallback using spies only;
- book-scoped reading-entry snapshots, synchronous clearing on A→B selection, cancellation/generation/book-ID late-result arbitration, catalog-unavailable completion, stale-row mutation/open rejection, an Exact fixed-fixture candidate, separate read-only duplicate-candidate state, and unchanged main-detail state after return;
- web-link CRUD/uniqueness/cascade, local-file selection cancellation, opaque bookmark persistence, 1 MiB boundary and oversized create/update rejection, canonical display-name validation, stale refresh, move/missing/corrupt/revoked repair, re-selection/removal, balanced scoped access, merge migration/rollback, pre-BLOB oversized-backup rejection, streamed near-limit multi-row validation, backup/restore preservation, and CSV/Markdown exclusion.

## UI tests

The second-review Escape race was requested as ten relaunch-enabled repetitions:

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bookatlas-p9-nogo2-targeted-10 \
  -only-testing:BookAtlasUITests/BookAtlasUITests/testViewingExistingDuplicateReturnsToUnchangedDraft \
  -test-iterations 10 \
  -test-repetition-relaunch-enabled YES \
  -resultBundlePath /tmp/bookatlas-p9-nogo2-targeted-10.xcresult \
  test
```

Two repetitions were polluted by unrelated external applications taking keyboard
focus: one lost focus while filling the author field and one was interrupted
before the second Escape. They are infrastructure incidents, not product-code
failures, and the command must not be described as 10/10. The other eight
repetitions passed. The subsequent independent complete UI suite initialized
XCUIAutomation and passed 26/26 with zero failures and zero skips.

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -derivedDataPath /tmp/bookatlas-p9-nogo2-final-ui \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:BookAtlasUITests \
  -resultBundlePath /tmp/bookatlas-p9-nogo2-final-ui.xcresult \
  test
```

The independent interactive run initialized XCUIAutomation and executed all 26 macOS UI tests: 26 passed, zero failed, and zero skipped. It retains all Prompt 5/6/7/8 paths and covers reading-entry empty state, HTTPS add/edit/delete and no-op open dispatch, host-only status/accessibility without path disclosure, HTTP/dangerous-scheme rejection, Apple Books limitation/confirmation/copy controls, local-file cancellation, invalid-bookmark repair/removal, separate read-only duplicate-candidate entries followed by an unchanged main detail, keyboard defaults, and the single-owner nested Escape path. UI tests opt into an in-memory store, fixed fictional test-only launch seeds, and no-op system adapters; they do not open a real file panel, external application, pasteboard, user file, or real database.

The latest Prompt 10 closure retains those 27 pre-performance UI regressions,
adds the keyboard/accessibility pagination regression and the graph-to-library
page-out identity regression, and adds two zero-row precise-selection-state
regressions,
and adds six fixed-fictional performance cases: three
`XCTApplicationLaunchMetric` cases and three real-list round-trip scroll cases
using `XCTClockMetric`, `XCTCPUMetric`, `XCTMemoryMetric`, and the macOS 26
`XCTHitchMetric`. The complete run initialized XCUIAutomation and passed
37/37. The launch test creates its fixed-fictional Schema 5 database in a
separate, untimed process and measures only reopening that existing controlled
temporary database and displaying the first 200 of the verified total. The
scroll cases separately time first-page startup, loading the next page, and
four sustained scroll events after loading a disclosed number of pages/rows.
The full raw result is documented in [`PERFORMANCE.md`](PERFORMANCE.md).

The pagination identity closure additionally exercises a 501-book graph-to-
library transition through the production `focusBook` path. Accessibility
assertions require the requested off-page UUID and title, the separate focused
row, and the unchanged exact count; an unrelated first-page detail is
explicitly rejected. State tests cover missing and filtered-out targets,
off-page create/edit/merge selection, and slow-old/fast-new request
arbitration.

The sixth NO-GO closure changed only the UI-test precondition and shared text
input arbitration. `testSearchCombinesWithStatusFilterAndCanBeCleared`
explicitly clicks the fixed A101 UUID row and verifies its detail title before
and after applying the status filter; it no longer relies on an implicit first
row selection. All calls to `replaceText` now supply their application. The
helper activates it, waits for foreground/window/element existence, clicks,
requires `hasKeyboardFocus`, and permits exactly one bounded
reactivate/reclick before failing. It does not sleep, loop, or request XCTest
retry-on-failure.

The final-code search result contains ten relaunch-enabled, no-retry passed
repetitions. The two precise zero-result UI tests passed 2/2. The unique sealed
complete result bundle parsed through both `xcresulttool` summary and tests
tree as 37 passed, zero failed, zero skipped; the complete non-UI result parsed
as 190/190. Earlier evidence is not discarded: the first full run was 36/37,
and that failure plus one focused duplicate-draft rerun failed at temporary
helper assertions which treated SwiftUI `TextEditor`'s unreliable
`hittable`/`enabled` AX
attributes as input authority even though later click/focus/type steps worked.
Post-click keyboard focus is the final authority. The result trees also retain
non-failing SwiftUI view-update and QoS runtime warnings; this closure does not
claim those diagnostics are resolved.

## Query baseline

`LibraryQueryBenchmarkTests` generates fixed fictional records in a fresh in-memory store for each size and records query construction, bulk tag association, search, multi-filter, and sort durations separately. On the environment above, the recorded Prompt 5 evidence for 1,000/5,000/10,000 books was approximately 1.0/2.2/4.1 ms for search and 9.5/27.4/28.1 ms for the priority-sorted multi-filter query. These are environment-specific evidence, not pass/fail thresholds or performance promises.

`DuplicateDetectionTests.testIndexedCandidateLookupRemainsBoundedAtTenThousandBooks` creates 10,000 fixed fictional records in one in-memory transaction, then performs an indexed Exact lookup. The second NO-GO closure full-suite run recorded `DUPLICATE_CANDIDATE_10000_SECONDS=0.178801` and enforces a one-second regression ceiling on the verified host. Exact and Strong indexed queries are uncapped and order by book UUID. Possible title-token lookup orders by book UUID, evaluates at most the first 250 raw index hits, requests a 251st row to detect truncation, and exposes that state in the review UI. The threshold is a local guard against accidental full-library/pairwise comparison, not a cross-device performance promise.

## Portability baseline

`PortabilityPerformanceTests` creates fresh temporary current-schema databases and fixed fictional ASCII records for each size. The recorded Prompt 7 final full-suite run on the environment above was:

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
| 1,000 | 0.0461 s | 0.0012 s | 0.0769 s | 0.0808 s | 0.0008 s | 0.6146 s | 12,468,224 B |
| 5,000 | 0.0460 s | 0.0010 s | 0.0759 s | 0.0476 s | 0.0011 s | 0.6063 s | 12,222,464 B |
| 10,000 | 0.0471 s | 0.0010 s | 0.0752 s | 0.0450 s | 0.0008 s | 0.6187 s | 17,399,808 B |

All three projections reached the deliberate 80-node/79-edge bounded result from a same-author fixture and disclosed candidate truncation. A separate 10,000-book test completed the projection outside the main actor while a main-actor expectation completed within one second. These measurements are local regression evidence, not frame-rate or cross-device promises.

## Graph freshness contract

`LibraryCatalogService` owns a monotonic, process-local `GraphContentRevision` and publishes it through an `AsyncStream`. Successful book create/update/delete, keep-separate creation, confirmed merge, tag/list/source association changes, tag create/rename/delete/merge, list create/rename/delete, source create/rename/delete, manual-relation add/delete, confirmed CSV import, and database restore/reconnection advance the revision. Duplicate-candidate reads and ignored-pair decisions do not advance it because they do not change graph nodes or evidence.

`GraphStore` records the revision embedded in each `GraphScene`. On entry it reads the current revision: if it matches and a valid scene is already loaded, selection and view-local layout are retained; otherwise the old scene, layout, status, and error are cleared and rebuilt. A published change cancels current work, increments the generation, and prevents late older-revision results from publishing. If the former center was deleted, was the source of a merge, or is absent after restore, the store clears the center and displays the explicit missing-center state. Restore never keeps pre-restore graph nodes or layout.

`GraphCanvasInteractionState` fixes its mode once per gesture. Panning captures the starting translation and always applies `start + current cumulative translation`; node dragging inverse-transforms the current pointer using the unchanged viewport scale and translation. Gesture end/cancellation and viewport reset return the interaction to idle.

## Known limitations

- Keep `BookAtlas/App/` responsible for composition and lightweight navigation only.
- Keep persistence, migration, and catalog rules out of SwiftUI views.
- Keep App Sandbox enabled and add no network client entitlement unless an accepted ADR and privacy review require it.
- Preserve `Experiments/TechnicalSpikes/` as evidence only; production code must not import it.
- Runtime validation currently covers one Apple-silicon host on macOS 26.5.2; the macOS 14.0 minimum runtime has not been exercised in this closure.
- Automated accessibility identifiers, appearance/small-window hosted checks,
  and keyboard paths are covered. The requested Prompt 10 human
  VoiceOver/Accessibility Inspector traversal, non-default accent, Reduce
  Motion, and direct 520×360 visual review were blocked by the current task
  execution surface and remain unverified release gates.
- Debug existing-library launch/page/scroll measurements are recorded, but the
  equivalent Release Instruments launch could not be authorized and remains
  an unverified release gate; no old in-process-seeding number is used.
- Release signing, notarization, and a final non-placeholder bundle identifier remain unconfigured.
- Duplicate heuristics intentionally do not understand every contributor order, edition, translation, or series convention; every candidate remains user-reviewed.
- A truncated Possible lookup does not yet provide pagination; the UI states that only the first 250 deterministic raw token hits were evaluated. Exact and Strong candidates are not truncated.
- CSV import is capped at 100 MiB, 100,000 rows, 1 MiB per field, and 128 columns; only 20 sample rows and 80 issue details are retained for presentation, with both limits disclosed. Same-batch or existing Exact/Strong rows are skipped and reported but do not become persistent ordinary-review candidates because no book is created. CSV cannot carry external links or manual relations; full-fidelity transfer requires a backup.
- Backup format 1 is capped at 4 GiB and uses a 16 MiB free-space safety reserve. Capacity values are filesystem estimates; a later real write error is still handled and reported.
- Backups are intentionally unencrypted and recovery copies are retained until the user manages them through the app container; no automatic retention policy is implemented.
- The graph defaults to one layer and 80 nodes/200 edges, allows a second layer, and has hard caps of 250/500. It does not provide clustering, saved layouts, a global graph, arbitrary graph queries, or cross-library relationships.
- Prompt 9 passed independent review at baseline `1f7a35cda11fcafd23aacab0cb5c72e811327d0b`. Automated tests prove adapter calls and state transitions, not that an external application will accept or render a particular URL or file on every Mac.
- No supported API was established for an exact item in a user's private Apple Books library. `ibooks:` remains unverified, private-library targeting remains unsupported, public search may disclose its term after confirmation, and Unicode/IDN hosts are deliberately rejected.
- Long-lived local references can become stale, missing, corrupt, revoked, or exceed the documented 1 MiB per-record limit and require user re-selection. The app stores bounded opaque bookmark bytes in Schema 5 and full backups but omits them, local display names and paths, and private URLs from CSV/Markdown.
