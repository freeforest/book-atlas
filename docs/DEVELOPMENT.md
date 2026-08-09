# Development

## Current application

`BookAtlas.xcodeproj` contains the `BookAtlas` macOS application scheme plus
`BookAtlasTests` and `BookAtlasUITests`. V1.0.0 targets macOS 26.0 in project,
application, unit-test, and UI-test Debug/Release settings, uses only SwiftUI
and AppKit supplied by macOS, and is sandboxed. The application bundle
identifier is `io.github.freeforest.BookAtlas`, marketing version is 1.0.0,
and build number is 1. ADR-0009 supersedes the earlier macOS 14 decision; no
macOS 14/15 support or compatibility matrix is promised.

The application has one direct-SQLite persistence path behind `BookRepository` and the actor-isolated `LibraryCatalogService`. The current schema is version 5 with migration path `1 → 2 → 3 → 4 → 5`. Production opens `~/Library/Application Support/BookAtlas/book-atlas.sqlite`; unit tests and explicit UI-test launches use isolated in-memory or temporary databases. The ordinary library query is paged: the production first page is 200 rows, every filtered query returns an exact total, and subsequent 200-row pages are requested explicitly. An explicit focus request returns that same bounded page plus at most one book selected by UUID under the same filters; it does not scan preceding pages or expand the page size. SwiftUI views own presentation only and do not execute SQL, migrations, duplicate rules, merge transactions, `NSWorkspace`, `NSOpenPanel`, `NSPasteboard`, or bookmark operations.

The accepted scope is book CRUD, local query and organization, deterministic duplicate review/merge, versioned CSV import with mapping and preview, Markdown/CSV export, full SQLite backup/restore, a bounded local relationship graph, and user-initiated external reading entries. Prompt 7 passed its third independent review at baseline `b27318c741fee5b4a66e5ad99cb979177285fef5`; Prompt 8 passed its second independent review at baseline `6ae90dd50ee71f574e0b4cc1ffccfd7e4c2e71aa`; Prompt 9 passed independent review at baseline `1f7a35cda11fcafd23aacab0cb5c72e811327d0b`. Prompt 10 passed independent acceptance at documentation baseline `ec0b04f1c004ef5c897d3269e335c92034d6021e`, against verified code baseline `4cc20b8c88cb674a4f9a52d3e8de70c295169281`. Prompts 0–10 are complete; there is no automatic Prompt 11. Subsequent work is a separate GitHub source-publication preparation task. There is no network client entitlement, AI duplicate detector, automatic merge, cloud backup, directory scanner, or whole-library graph.

## GitHub source publication and platform alignment

The distribution plan is source code on GitHub only. Book Atlas will not be
submitted to the Mac App Store and will not provide a downloadable precompiled
`.app`. Apple Developer membership, App Store Connect/Review, Developer ID
Application/Installer, distribution certificates, provisioning profiles,
notarization tickets, stapling, and Gatekeeper acceptance for binary
distribution are therefore not applicable to the current plan. Local ad-hoc
Debug/Release signing, App Sandbox, Hardened Runtime, and effective-entitlement
inspection remain useful build evidence but are not Apple distribution proof.

Source builders need a compatible Xcode 26 toolchain, Swift, SwiftUI, AppKit,
and system SQLite; the production target has no third-party binary dependency.
The production `MACOSX_DEPLOYMENT_TARGET` is 26.0 throughout the project and
all three targets. Earlier macOS 14 references in historical milestones,
ADR-0003, and isolated technical-spike evidence are not current support claims.

The confirmed repository is `freeforest/book-atlas`, which became Public on
2026-08-10 after complete reachable-history and online public-surface checks.
Both a logged-in view and an independent public non-administrator view
confirmed Public access. GitHub Private Vulnerability Reporting is enabled,
and the external view confirmed **Report a vulnerability**; the administrator
view's **New draft security advisory** is the expected role-specific surface.
The confirmed copyright line is `2026 FreeForest`; the intended version,
still-uncreated tag, and still-uncreated Release are 1.0.0, `v1.0.0`, and
`Book Atlas v1.0.0`. Every remaining Git/GitHub write remains a manual user
action. The separate private conduct-reporting channel is configured, with
[`CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md) as the authoritative contact
source. The user confirmed control of the dedicated project channel and
authorized its publication; no test message was sent. PVR remains limited to
security vulnerabilities and is not represented as a conduct channel. A
future decision to ship a precompiled `.app`
through GitHub Releases would require a new release task covering Developer ID,
notarization, Gatekeeper, signing, download integrity, installation, and update
strategy.

For the V1.0.0 native-panel safety check, the explicit
`-BookAtlasUseSystemFilePanel` launch argument may be combined with
`-BookAtlasUseInMemoryStore` and fixed fictional seeds. It replaces only the
test file selector/bookmark pair with the production `NSOpenPanel` and bookmark
services; browser, Apple Books, and clipboard adapters remain fictional/no-op.
Ordinary UI tests do not use this argument. The reviewer must cancel the panel
without selecting a file.

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

### Accepted Prompt 10 evidence at `4cc20b8c…`

The current baseline is commit
`4cc20b8c88cb674a4f9a52d3e8de70c295169281`, whose parent is
`dfe49d724fdadc203a715d7e744d0a9e91bd5ad7`. The formerly failing graph UI
cases clicked semantic graph nodes while an anonymous `AXScrollArea` inside
`local-graph-page` → `graph-accessibility-panel` had been compressed to zero
height (`{{517,615.5},{732,0}}` and `{{517,623},{732,0}}`). That object was not
`graph-filter-control`; the filter control's measured height was 20 points.

At a 732-point content width, the previous 760-point threshold selected the
vertical graph layout. The Canvas and detail-panel minimum heights then
compressed the semantic node list to zero height. The production correction
changes only the horizontal-layout threshold from 760 to 700 and gives the
node list a 120-point minimum height. It does not change relationships,
weights, filters, data, graph revision, Schema, migration, or persistence
semantics.

The UI-test precondition now selects the fixed fictional center UUID ending in
`0601`, verifies the title `《雾港图谱中心》`, verifies the detail page and exact
`show-local-graph-button`, and scrolls only inside `book-detail-view` when the
button is genuinely outside that viewport. Failures retain page, window,
target, filter, node-list, and scroll-ancestor diagnostics. The repair uses no
arbitrary sleep, coordinate click, retry-on-failure, skipped test, deleted
assertion, or application-wide `scrollViews.firstMatch`.

The final V2 evidence was:

- three targeted historical graph failures: 3/3 actually executed and passed,
  zero failed, zero skipped. An earlier command exited before test execution
  because the Xcode/CoreSimulator/test-service connection failed and executed
  zero tests; it is not counted. A fresh infrastructure path produced the 3/3
  result;
- complete UI: XCUIAutomation initialized and 41/41 executed tests passed,
  zero failed, zero skipped; `xcresulttool` summary and tests tree agreed;
- complete non-UI: 200/200 executed tests passed, zero failed, zero skipped,
  with summary and tests tree agreement. One earlier full run produced 199
  passes and one benchmark process `signal term`, with no XCTest assertion
  failure; that runner/infrastructure termination is not counted as a pass.
  The terminated benchmark passed alone, then a fresh complete path passed
  200/200;
- Debug and Release both reported `BUILD SUCCEEDED`. The evidence products were
  the Debug app under `/tmp/bookatlas-p10-4cc20-debug` and Release DerivedData
  under `/tmp/bookatlas-p10-4cc20-release`; these are ephemeral run paths, not
  permanent distributable assets.

Manual evidence used the Debug app with an in-memory store and all fixed
fictional UI seeds, plus `-ApplePersistenceIgnoreState YES`. It did not open
the production Application Support database, select or read a real file, read
private Apple Books data, open a real HTTPS destination/browser, perform a
real import or restore, or write real clipboard content. It added no
dependency, network access, or permission.

Current-build Light and Dark reviews found the library empty and selected
states, A101 metadata, exact-result/terminal paging status, reading entry,
graph filters, semantic node list, current selection, open-detail action, and
set-center action clear and operable without clipping, overlap, obstruction,
or color-only meaning. The graph worked at the default window and at an exact
520×360 `AXWindow`/`AXStandardWindow`; at 520×360 the library, graph, and
scrolling editor retained reachable operations and visible validation. The
window-size check is `PASS`.

Accessibility Inspector formal audits were rerun separately on the current
Debug build. State A was Light, no selected book, and the
`library-selection-empty` static text “选择一本书”; every category and the total
were zero warnings. State B selected fixed-fictional A101 with reading entries;
`book-detail-view` was a nonzero 379.5×649.0 `AXScrollArea`, and every audit
category and the total were also zero. These two state-specific results show
that the historical findings did not reproduce there; they do not establish a
permanent whole-application zero-warning result. The earlier 25-warning and
16-warning audits, including the old “全部书籍” and “选择一本书” contrast
findings and the separately classified system/framework warnings, remain in
the audit history.

The Prompt 10 native-file action remains historical `PASS WITH LIMITATION`:
clicking “选择本地文件…” on fixed-fictional A101 returned cancellation semantics
without displaying an actual macOS `NSOpenPanel`; no file was selected or read
and the library did not change. The later V1.0.0 verification below supersedes
that limitation for the narrow display-and-cancel path without rewriting the
earlier observation.

### V1.0.0 macOS 26 source-publication verification

The clean committed baseline is
`71ec000c65179bdbcae08981631c9dff7df7c711`. Relative to
`223e3ccfe12c8decd8e7a292cac2df34e27c6154`, it changes only
`BookAtlasUITests/BookAtlasUITests.swift`, adding immediate exact-value
diagnostics after the existing author-field and Command-F keyboard inputs. It
does not change production code or weaken the focus, multiword input, A101 row,
or B202 exclusion assertions. Both original paths and both diagnostic paths
passed 10/10 relaunch-enabled, no-retry repetitions. The final full bundle
`/tmp/bookatlas-v1-full-ui-diagnostic-223e3cc.xcresult` parsed as 41/41 passed,
zero failed, zero skipped, zero expected failures on macOS 26.5.2 arm64 after
XCUIAutomation initialized. Its activity tree executed both
`value == "Manual Acceptance Author"` and `value == "A101"`. The historical
transient failures did not reproduce; no product defect or unique system,
focus, window, or input-method root cause was established. Six Xcode
`[Internal]` QoS runtime diagnostics occur in six other passing cases without a
stack trace or reproducible product symptom and remain tool-warning evidence,
not product failures.

Fresh local products were built under `/tmp/bookatlas-v1-final-debug` and
`/tmp/bookatlas-v1-final-release`; Debug and Release both succeeded. The fresh
non-UI bundle `/tmp/bookatlas-v1-final-nonui.xcresult` parsed consistently in
summary and tests tree as 200/200 passed, zero failed, zero skipped, zero
expected failures on macOS 26.5.2 arm64. Schema remains 5 and the migration
path remains `1 → 2 → 3 → 4 → 5`. The builds reported only the ordinary
AppIntents metadata-extraction skip because the app has no AppIntents framework
dependency; no deterministic compilation failure occurred.

Both actual products report version 1.0.0, build 1, bundle identifier
`io.github.freeforest.BookAtlas`, and minimum macOS 26.0. Debug is arm64 and
ad-hoc signed with App Sandbox, user-selected read/write, app-scoped bookmarks,
and Debug-only `get-task-allow`. Release contains x86_64 and arm64 slices, both
with minimum macOS 26.0, and is ad-hoc signed with Hardened Runtime plus only
App Sandbox, user-selected read/write, and app-scoped bookmarks. Neither product
contains a network-client, Apple Events, automation, or Downloads entitlement,
Team ID, Developer ID, distribution certificate, or provisioning profile.
This is local build evidence, not distribution signing.

The final Debug app was launched with an in-memory store, fixed fictional books
and reading entries, and the explicit system-file-panel QA switch. Only the
file selector and bookmark service used their production system adapters; the
other external integrations remained fictional/no-op. A human observer saw the
real macOS `NSOpenPanel` and cancelled it immediately without browsing,
selecting, or reading a file. The app remained stable, the fixed-fictional
library remained at two books, no local-file record was added, and the visible
result was “已取消选择；书库未更改。” This narrow check is
`PASS — 真实 NSOpenPanel 已显示并安全取消`; it does not validate a selected real
file, bookmark creation, long-lived bookmark resolution, browser launch, or
Apple Books behavior.

The final repository scan covered tracked and untracked names, tracked text,
samples, the generator, metadata, entitlements, `.gitignore`, and public
documents. It found no private data, current-user absolute path, secret,
database/WAL/SHM/journal, backup, bookmark BLOB, DerivedData, `.xcresult`, app
or installer archive, certificate, private key, provisioning profile, or
signing material. The only production dependency is system SQLite; the
technical-spike Swift package and historical macOS 14/placeholder identifiers
remain explicitly historical, not V1.0.0 production settings.

A browser and Apple Books were not actually launched, a real file was not
selected or read, and real long-lived bookmark behavior remains unverified.
These are integration limitations, not Apple-store distribution gates.
Distribution signing, notarization, and Gatekeeper binary distribution are not
applicable to the current source-only plan.

### Earlier Prompt 10 closure validation

The implementation closure completed both local build configurations:

```sh
xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bookatlas-p10-nogo8-debug \
  build

xcodebuild \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bookatlas-p10-nogo8-release \
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
  -derivedDataPath /tmp/bookatlas-p10-nogo8-tests \
  -resultBundlePath /tmp/bookatlas-p10-nogo8-tests.xcresult \
  -only-testing:BookAtlasTests

xcodebuild test \
  -project BookAtlas.xcodeproj \
  -scheme BookAtlas \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bookatlas-p10-nogo8-final-ui \
  -resultBundlePath /tmp/bookatlas-p10-nogo8-final-ui.xcresult \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -only-testing:BookAtlasUITests
```

The unit/integration/migration/security/performance command executed 197
tests: 197 passed, zero failed, zero skipped. The UI command initialized
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

### Editor validation-feedback closure

A later Light-mode manual check reproduced a real editor defect: Command-S on
an empty draft, or mouse Save with a fictional author and no title, kept the
sheet open but left the only validation text below the visible part of the
long form. That observation remains a manual FAIL history item; it is not
rewritten as an automated pass.

The editor now renders one fixed summary above the scrolling Form and an
inline explanation beside the affected title, author, publication-date, or
priority control. Required-field failures move keyboard focus to the invalid
field. Every invalid save requests a high-priority AppKit accessibility
announcement through a small injectable adapter, including repeated saves of
the same unchanged invalid draft. Announcements contain stable error language,
never draft values. Correcting the affected field clears that error, while
unrelated edits do not. The Save button and Command-S call the same save path.

The final-code non-UI bundle at
`/tmp/bookatlas-p10-validation-final-tests-v2.xcresult` executed 200/200 tests
with no failure or skip. New tests cover every validation error's resolution
rule, repeated announcement delivery, privacy-safe wording, and stale-error
clearing. Real XCUI regressions check that summary and field-error frames
intersect the current editor and window, required focus is real, draft text
remains, and no book or duplicate-review state is created. The direct
author-only/no-title mouse path passed a no-retry three-run command 3/3. The
sealed full UI bundle at
`/tmp/bookatlas-p10-validation-final-ui-v3.xcresult` executed 40/40 tests with
no failure or skip. Its complete activity scan contains zero SwiftUI
view-update publication warnings; six Xcode-internal QoS diagnostics remain
separately classified. An earlier 39/40 full run failed before duplicate review
because the test helper scrolled the application's first ScrollView instead of
the current editor Form. Scoping that helper to the editor preserved the note
assertion, passed the focused path 1/1, and the final full run passed the same
path. No timeout, XCTest retry, or reduced assertion was used.

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

Historically, Accessibility Inspector was launched during an earlier attempt. On
2026-08-03 a second attempt initialized the supported Computer Use runtime,
enumerated running applications, and started the Debug app against an in-memory
fixed fictional seed. Its native pipe closed before the first Book Atlas app-
state or accessibility-tree response. That task execution surface therefore could
not safely select Inspector targets, read results, drive VoiceOver, change
system accessibility/appearance settings, or inspect the desktop. That attempt
reported no human accessibility or visual item as passed. Its per-area BLOCKED
record remains in [`QUALITY_AUDIT.md`](QUALITY_AUDIT.md); later completed human
evidence and the current `4cc20b8c…` Inspector state A/B results are recorded
separately. Those attempts did not constitute acceptance at the time; Prompt 10
subsequently passed independent acceptance at `ec0b04f…`.

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

If Release Instruments is used for future local performance work, it must use
the same three-phase semantics: run preparation outside the App Launch trace,
trace only the
`-BookAtlasPerformanceUseExistingLibrary` process, verify the disclosed first
page/total, then run cleanup. In this closure the preparation step ran, but
authorization for the measured desktop Instruments launch was unavailable
from the task execution surface. No Release launch value is therefore
reported; the older in-process-seeding numbers are not a substitute. This
historical missing measurement is not a GitHub source-publication blocker.

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

That earlier Prompt 10 performance closure retained 27 pre-performance UI regressions,
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

The seventh closure binds `List(selection:)` to a local
`LibraryListSelectionState` instead of synchronously mutating several Store
publications in the List transaction. A monotonic generation identifies the
latest list-side identity, programmatic Store selection synchronizes back
without feedback, and repeated UUID selection is idempotent. The Store no
longer publishes unchanged selection state or clears a matching off-page
focused book.

The eighth closure removes the remaining Store-side no-op publication:
`selectBook` clears `focusedBook` only when a non-nil focus has an identity
different from the requested selection. Re-selecting an ordinary in-page UUID
with nil focus/issue, re-selecting nil from an empty selection, and selecting a
matching page-out focus publish no state. Selecting a different UUID or nil
still clears an existing mismatched focus. Four focused regressions subscribe
to `objectWillChange` and verify these boundaries directly.

The final-code search and keyboard-selection results each contain ten
relaunch-enabled, no-retry passed repetitions. The unique complete result
bundle parsed through both `xcresulttool` summary and tests tree as 37 passed,
zero failed, zero skipped; that closure's complete non-UI result parsed as 197/197.
Activities for all 20 focused repetitions and all 37 complete-suite cases
contain zero SwiftUI view-update publication warnings. The keyboard 10-run
bundle retains ten Xcode internal QoS diagnostics and the complete bundle has
six; they are classified separately because the activities do not identify
production selection code as their source. Earlier evidence is not discarded:
the first full run was 36/37,
and that failure plus one focused duplicate-draft rerun failed at temporary
helper assertions which treated SwiftUI `TextEditor`'s unreliable
`hittable`/`enabled` AX
attributes as input authority even though later click/focus/type steps worked.
Post-click keyboard focus is the final authority. Two seventh-closure focused
attempts also produced zero-test bundles when XCUIAutomation timed out while
enabling automation; a subsequent focused run executed and passed 2/2. These
are retained as infrastructure failures.

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
- Runtime validation covers one Apple-silicon host on macOS 26.5.2. The project
  now declares macOS 26.0 throughout; no macOS 14/15 compatibility claim or
  matrix is planned. Historical macOS 14 evidence is not a V1.0.0 support claim.
- Automated accessibility identifiers, appearance/small-window hosted checks,
  and keyboard paths are covered. A prior human gate covered the non-default
  purple accent, Reduce Motion, complete pointer-free keyboard use, and
  VoiceOver; those items were not all rerun on `4cc20b8c…`. The current build
  adds Light/Dark, graph, exact 520×360, and Inspector state A/B evidence.
  Inspector coverage remains state-specific. The Prompt 10 native panel result
  remains historical `PASS WITH LIMITATION`; the later V1.0.0 fixed-fictional
  system-adapter check displayed and safely cancelled a real `NSOpenPanel`
  without selecting or reading a file. Real selection and long-lived bookmark
  behavior remain unverified.
- Debug existing-library launch/page/scroll measurements are recorded; the
  equivalent Release Instruments launch was not obtained. It is not a blocker
  for source-only publication.
- Apple Developer membership, App Store distribution, Developer ID,
  distribution signing, notarization, stapling, and Gatekeeper binary
  acceptance are not applicable to the current source-only strategy. The
  V1.0.0 bundle identifier and version metadata are resolved as documented
  above.
- Duplicate heuristics intentionally do not understand every contributor order, edition, translation, or series convention; every candidate remains user-reviewed.
- A truncated Possible lookup does not yet provide pagination; the UI states that only the first 250 deterministic raw token hits were evaluated. Exact and Strong candidates are not truncated.
- CSV import is capped at 100 MiB, 100,000 rows, 1 MiB per field, and 128 columns; only 20 sample rows and 80 issue details are retained for presentation, with both limits disclosed. Same-batch or existing Exact/Strong rows are skipped and reported but do not become persistent ordinary-review candidates because no book is created. CSV cannot carry external links or manual relations; full-fidelity transfer requires a backup.
- Backup format 1 is capped at 4 GiB and uses a 16 MiB free-space safety reserve. Capacity values are filesystem estimates; a later real write error is still handled and reported.
- Backups are intentionally unencrypted and recovery copies are retained until the user manages them through the app container; no automatic retention policy is implemented.
- The graph defaults to one layer and 80 nodes/200 edges, allows a second layer, and has hard caps of 250/500. It does not provide clustering, saved layouts, a global graph, arbitrary graph queries, or cross-library relationships.
- Prompt 9 passed independent review at baseline `1f7a35cda11fcafd23aacab0cb5c72e811327d0b`. Automated tests prove adapter calls and state transitions, not that an external application will accept or render a particular URL or file on every Mac.
- No supported API was established for an exact item in a user's private Apple Books library. `ibooks:` remains unverified, private-library targeting remains unsupported, public search may disclose its term after confirmation, and Unicode/IDN hosts are deliberately rejected.
- Long-lived local references can become stale, missing, corrupt, revoked, or exceed the documented 1 MiB per-record limit and require user re-selection. The app stores bounded opaque bookmark bytes in Schema 5 and full backups but omits them, local display names and paths, and private URLs from CSV/Markdown.
