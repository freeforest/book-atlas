# Development

## Verification policy

[AGENTS.md](../AGENTS.md) defines agent authority and manual Git boundaries.
Use the current user/controller task for its exact scope, sequence, gates,
and retry budget. Commands and dated results below are references or execution
records, not instructions to rerun every check. Existing result paths must not
be overwritten; authorized new runs use fresh task-specific temporary paths.

When a task does not prescribe broader checks, use this starting point:

| Change | Relevant verification |
| --- | --- |
| Documentation or agent instructions only | Read back the edits; check instruction consistency, links, whitespace, and preservation of existing evidence. No Xcode or UI run solely for prose changes. |
| Domain, Repository, or Store behavior | Meaningful regression tests for changed rules and affected callers; an appropriate build. Use deterministic handshakes for async state. |
| SwiftUI or native interaction | Relevant model tests and a build, plus authorized targeted UI/runtime checks for the changed user contract. Model tests alone do not establish native behavior. |
| Schema, portability, dependencies, or entitlements | Relevant migration/rollback/security tests and configuration/product inspection; broader suites as required by the change and current plan. |
| Stage acceptance or release-facing work | All explicitly required full suites, builds, audits, and manual gates. Scoped checks cannot replace those gates. |

This policy does not waive an active gate or reopen an exhausted budget.
Reuse passing evidence only when its verified inputs remain applicable and
the current task permits reuse. Do not repeat passed checks without a change,
failure, or relevant unresolved concern. Do not freeze historical test counts
as proof that the current suite ran in full.

Capture real build/test exit codes separately from parser exit codes. For
test gates, reconcile the selected identities, summary, and complete test
tree, including failures, skips, and cancellations. A parseable interrupted
run remains incomplete for a full-suite gate. Keep `PASS`, `PARTIAL`, `FAIL`,
`UNTESTED`, `NOT VERIFIED`, `PENDING`, and `BLOCKED` scoped to what they describe.

UI automation needs an available interactive Mac session; respect the task's
user-confirmation requirement. Do not compete for its keyboard, mouse, focus,
or test resources. A passing probe does not establish the cause of an older
failure. Observe the required stop rule and preserve failed-run evidence.

Git checks, history review, and publication are performed by the user.
Attribute supplied results and leave missing evidence pending. Non-Git file
checks can verify this task's edits, not the full tracked/staged change set.
Evidence needed only for local review should stay outside public materials;
use relative references or redacted placeholders in repository reports.

## Current application

`BookAtlas.xcodeproj` contains the `BookAtlas` macOS application scheme plus
`BookAtlasTests` and `BookAtlasUITests`. V1.0.0 targets macOS 26.0 in project,
application, unit-test, and UI-test Debug/Release settings, uses only SwiftUI
and AppKit supplied by macOS, and is sandboxed. The application bundle
identifier is `io.github.freeforest.BookAtlas`, marketing version is 1.0.0,
and build number is 1. ADR-0009 supersedes the earlier macOS 14 decision; no
macOS 14/15 support or compatibility matrix is promised.

The application has one direct-SQLite persistence path behind `BookRepository` and the actor-isolated `LibraryCatalogService`. The current schema is version 5 with migration path `1 → 2 → 3 → 4 → 5`. Production opens `~/Library/Application Support/BookAtlas/book-atlas.sqlite`; unit tests and explicit UI-test launches use isolated in-memory or temporary databases. The ordinary library query is paged: the production first page is 200 rows, every filtered query returns an exact total, and subsequent 200-row pages are requested explicitly. An explicit focus request returns that same bounded page plus at most one book selected by UUID under the same filters; it does not scan preceding pages or expand the page size. SwiftUI views own presentation only and do not execute SQL, migrations, duplicate rules, merge transactions, `NSWorkspace`, `NSOpenPanel`, `NSPasteboard`, or bookmark operations.

The accepted scope is book CRUD, local query and organization, deterministic duplicate review/merge, versioned CSV import with mapping and preview, Markdown/CSV export, full SQLite backup/restore, a bounded local relationship graph, and user-initiated external reading entries. Prompt 7 passed its third independent review at baseline `b27318c741fee5b4a66e5ad99cb979177285fef5`; Prompt 8 passed its second independent review at baseline `6ae90dd50ee71f574e0b4cc1ffccfd7e4c2e71aa`; Prompt 9 passed independent review at baseline `1f7a35cda11fcafd23aacab0cb5c72e811327d0b`. Prompt 10 passed independent acceptance at documentation baseline `ec0b04f1c004ef5c897d3269e335c92034d6021e`, against verified code baseline `4cc20b8c88cb674a4f9a52d3e8de70c295169281`. Prompts 0–10 are complete; Prompt 11A was later explicitly authorized, but its local implementation is `BLOCKED — WAITING FOR CONTROLLER REVIEW` and is not accepted. Prompt 11B is not authorized. There is no network client entitlement, AI duplicate detector, automatic merge, cloud backup, directory scanner, or whole-library graph.

## Prompt 11A local implementation

`ManualRelationStore` is separate from `LibraryStore` and binds every relation
snapshot, target search, create, and delete operation to one `bookID`. It clears
old rows synchronously on a book switch, cancels the old task, and rejects late
publication unless both generation and book identity still match. Target search
reuses `LibraryQuery`, exact totals, and explicit paging while excluding the
source. Counterpart navigation uses the existing UUID focus path and filtered-
out recovery flow. `LibraryCatalogService` remains the only presentation-facing
route to repository relation queries and mutations; successful create/delete
advances the existing graph-content revision.

Creation cancellation means **提交前可取消；提交处理中不可取消**. The Store,
not only the save button, rejects repeated saves, cancellation, reopening,
target search/selection, and draft edits while awaiting the submitted write.
The editor's disabled controls and interactive dismissal share `isSaving`;
sheet binding writes still pass through the guarded Store cancellation entry.
The existing cancel shortcut remains the only Escape owner; no monitor was
added. A local creation generation fences both the write result and the
post-save refresh, including a new draft for the same book. Failure restores
editing and cancellation without discarding the draft. An unknown write error,
view disappearance, or cancellation of the calling Task is not proof of rollback.

The pre-repair 10/10 new tests, 10/10 related regressions, Debug, 209/209 non-UI,
and 3/3 targeted UI are historical evidence, not validation of the repaired
code. On 2026-09-05, `Prompt 11A-SAVE-LIFECYCLE-01` added eight deterministic
in-memory continuation-handshake regressions. Before the production fix, four
selected tests reproduced the bugs: 4 executed, 0 passed, 4 failed, 0 skipped,
xcodebuild exit 65. This expected red run is not a passing gate. After the fix,
Store tests passed 12/12 and the complete `BookAtlasTests` passed 217/217, both
with zero failed/skipped and xcodebuild exit 0. Summary and complete test-tree
parsing agreed. The subsequent single Debug build exited 0 and its parsed
build result was `succeeded`. No verification rerun was needed.

The existing full-UI-36 bundle is parseable: 44 total, 31 passed, 13 failed,
0 skipped. The first failure reports a lost application connection; the next
12 report UI-testing authorization errors. This chronological sequence does
not prove a shared root cause or a revoked system permission. Its original
test-process exit code is `UNKNOWN`; the current summary/tests parser exits
are both 0. Retry-37 is a **可解析的中断运行，完整门禁未完成**: 5 total, 1 passed,
4 failed, 0 skipped, including one `Testing was canceled`. Its historical
test-process exit was 73; the current summary/tests parser exits are 0.
The earlier result-packaging warning does not make the bundle unparseable now.
Exact-value assertions recorded `Manual AcceptanceAuthor` instead of
`Manual Acceptance Author`, and `A01` instead of `A101`; both tests already had
post-input exact-value checks. The collection-row assertion and cancellation
are separate observations. Input-event, focus, application, authorization,
and test-host causes remain `UNKNOWN`, not a single established infrastructure
diagnosis.

No new UI test, Release build, permission reset, or manual interface operation
was authorized or performed in this narrow repair. Runtime busy-state/Escape/
dismissal checks and Release remain `UNTESTED`; final configuration/privacy
audits remain `NOT VERIFIED`; the complete UI gate remains `BLOCKED`.
All Git/GitHub operations, including read-only commands and `.git` access, are
now manual user actions. Prior status/diff-check claims are **执行来源待确认**,
not confirmed `USER-PROVIDED`; they were not rerun by the executor.
See [Milestone 6](PLANS/MILESTONE-6.md) for exact commands, temporary result
paths, structured counts, timestamped UI evidence, and remaining user checks.
窄修复完成，等待主控复核；Prompt 11A 仍 `BLOCKED`。

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

## 2026-09-05 — Prompt 11A finite acceptance recovery evidence

This is an append-only execution record, not a new acceptance or permission to rerun. Prompt 11A remains **BLOCKED**. Production, tests, helpers, configuration and system settings were not edited. Only this document and MILESTONE-6 received appended facts. Git/GitHub and final pending-change review remain owner-operated; no git/gh command or `.git` access was performed.

`$EVIDENCE_DIR` below substitutes the dedicated fresh temporary directory retained in the local handoff. Exact machine-local commands, logs, source manifests, raw JSON and process exit records are retained there in `AUDIT-EVIDENCE.md`; do not copy private absolute paths into repository documentation. Every batch had its own new DerivedData and xcresult. These commands were each invoked once, not as retries:

```sh
xcodebuild build -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath "$EVIDENCE_DIR/release-dd" -resultBundlePath "$EVIDENCE_DIR/release.xcresult"
xcodebuild test -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -derivedDataPath "$EVIDENCE_DIR/U1-dd" -resultBundlePath "$EVIDENCE_DIR/U1.xcresult" -only-testing:BookAtlasUITests/BookAtlasUITests/testAuthorOnlyMouseSaveShowsVisibleTitleErrorAndPreservesDraft -only-testing:BookAtlasUITests/BookAtlasUITests/testCommandFFocusesLibrarySearchFromAnotherSection -only-testing:BookAtlasUITests/BookAtlasUITests/testCreateCollectionAndSourceWithKeyboardNavigation
xcodebuild test -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -derivedDataPath "$EVIDENCE_DIR/U2-dd" -resultBundlePath "$EVIDENCE_DIR/U2.xcresult" -only-testing:BookAtlasUITests/BookAtlasUITests/testManualRelationEmptyStateKeyboardCancellationAndEscapeOwnership -only-testing:BookAtlasUITests/BookAtlasUITests/testManualRelationFilteredCounterpartUsesExactFocusAndClearFlow -only-testing:BookAtlasUITests/BookAtlasUITests/testManualRelationKeyboardCreateNavigateConfirmedDeleteAndGraphRefresh
xcodebuild test -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -derivedDataPath "$EVIDENCE_DIR/U3-dd" -resultBundlePath "$EVIDENCE_DIR/U3.xcresult" -only-testing:BookAtlasUITests/BookAtlasUITests/testPerformanceSustainedListScrollingWithTenThousandBooks -only-testing:BookAtlasUITests/BookAtlasUITests/testSeededLibraryExposesStatusAndCombinedRowMetadata
```

The actual zsh invocations used `set -o pipefail`, piped both output streams to the matching retained log, and captured `$pipestatus[1]` immediately after the pipeline into a batch-specific variable. Each original xcodebuild process exited **0**. Parser exit codes were recorded independently:

```sh
xcrun xcresulttool get build-results --path "$EVIDENCE_DIR/release.xcresult" --compact
# Executed separately for each of U1, U2 and U3:
xcrun xcresulttool get test-results summary --path "$EVIDENCE_DIR/<batch>.xcresult" --compact
xcrun xcresulttool get test-results tests --path "$EVIDENCE_DIR/<batch>.xcresult" --compact
```

All seven parser invocations exited 0. Release structured status succeeded, errorCount/warningCount/analyzerWarningCount all 0; raw log separately contains the skipped AppIntents metadata extraction warning. U1 was 3 executed / 3 passed / 0 failed / 0 skipped, U2 3/3/0/0, U3 2/2/0/0. Complete test trees matched exactly the selectors above. No interruption, skipped test, repeated batch or full UI run occurred.

Release product: `<EVIDENCE_DIR>/release-dd/Build/Products/Release/BookAtlas.app`. Its executable contains x86_64 and arm64; destination and host were arm64. Intel hardware execution remains NOT VERIFIED. Environment: macOS 26.5.2 (25F84), Xcode 26.6 (17F113), Swift 6.3.3, macOS SDK 26.5. Release is local adhoc signing, not archive/distribution. Both executable slices expose exactly sandbox, user-selected read/write and app-scope bookmark entitlements; strict all-architecture signature verification exited 0. Version/build are 1.0.0/1.

The 63-file production/test/configuration checksum manifest remained identical before and after Release and all UI batches: SHA-256 `bb3bdbc69e5aea8c2da59f029d12e6f83a51baccd1c1b9e2a2ab3b3e4f2df82d`. No new full non-UI run was made; the controller-provided 217/217 decision is not presented as a new run.

U3 selected activity queries for each exact test ID also exited 0. At UTC+08, sustained scrolling started 16:57:30.759 and its Tear Down activity began 17:03:10.168; the ordinary seeded test started 17:03:11.073 and performed its book-row StaticText lookup at 17:03:18.369. Thus ordinary AX access occurred after the scrolling test in this run. This does not claim one continuously surviving app process, smoothness acceptance, or a repaired historical XCUI root cause. Existing workload and three measurement iterations were unchanged.

User explicitly confirmed the unlocked local session, no competing UI automation and no manual input/application switching during testing. Read-only pre-batch observations were Codex/ABC (U1), Codex/SCIM.ITABC (U2), Codex/ABC (U3). No input method or permissions were changed by the executor; the reason for differing checkpoints is UNKNOWN. Checkpoints are not continuous monitoring and cannot explain old failures.

Current read-only audit verified Schema 5 with migrations 1–5, CSV `bookatlas-csv/1` with 16 fields and no manual relations, backup format 1 with existing four-field manifest, no production Swift package references, SQLite/system-only linking and no Release network entitlement. Known active-network/logging symbols did not match production source; inspected NSWorkspace paths are user-initiated reading-entry dispatch, not automatic fetching. Historical byte equality, immutable tag state and complete pending-change scope were NOT VERIFIED without owner-provided Git evidence.

Project metadata inventory excluded `.git`: 194 entries, no symlinks or database/backup/log/certificate/key/result-bundle/application artifact candidates. Four `.DS_Store` files and an experimental `.build` cache skeleton/lock remain nondelivery metadata candidates; their contents were not read or deleted. Ignore rules alone cannot establish their pending-commit exclusion. Known text/fictional-fixture scanning found no actual credential or machine-specific home path in that scope; this is not an absolute privacy guarantee. Final scope and Git checks remain PENDING with the owner; prior status/diff-check execution source remains unconfirmed.

Remaining UNTESTED: in-flight save busy-state UI, Escape/sheet dismissal during the write, and real mouse/keyboard manual QA. Full UI acceptance remains BLOCKED and needs separate controller authorization. Existing U2 cancellation coverage does not replace busy-save coverage. Historical connection loss, subsequent authorization errors, missing input characters and cancellation retain separately UNKNOWN root causes; three passing probes must not be aggregated into full-suite acceptance. Stop here; no Prompt 11B authorization.

## 2026-09-05 — BUSY-UI-AND-FULL-GATE-01: BLOCKED at stage 1

The authorized local test-support changes are retained in LibraryStore.swift (optional relation-store injection, guarded launch switch, Debug-only non-writing asynchronous fixture), BookDetailView.swift (saving indicator identifier only), LibraryStoreTests.swift (four new test declarations), and BookAtlasUITests.swift (one busy-state test and optional launch flag). ManualRelationStore.swift and its existing 12 tests were not changed. Original 44 UI identities remain; source now declares 45. No original assertion or performance workload was reduced. No UI execution occurred.

The first directed run completed with **44 executed / 43 passed / 1 failed / 0 skipped**, original xcodebuild exit **65**. The full summary and tree each parsed with exit **0**. LibraryStoreTests: 32 executed, 31 passed, 1 failed; ManualRelationStoreTests: 12/12 passed. The failing identity was `LibraryStoreTests/testSuspendedRelationSwitchAllowsOnlyExplicitMemoryFixture()`: databaseUnavailable rather than content, nil rather than the fixed source identity, and idle rather than loaded relation state.

Current Debug configuration does not define the Swift `DEBUG` compilation condition. Actual SwiftDriver invocations for app and unit tests contain no `-D DEBUG`. Consequently the new `#if DEBUG` fixture and its handshake test were excluded; the valid launch switch was rejected by the non-Debug branch. Four unit-test declarations were added but only three were compiled/discovered. The excluded handshake is **UNTESTED**, not passed or skipped. A Debug configuration name alone does not define that condition.

Satisfying the explicitly required `#if DEBUG` boundary requires controller authorization to establish the Debug compilation condition for the app and relevant tests while leaving Release undefined. Project settings are outside this task's allowed files. No project edit, command-line macro override, correction retry or later gate was attempted. This is a scope/configuration prerequisite blocker, not evidence that the previously repaired save semantics failed.

Exact local commands and paths are retained in `<EVIDENCE_DIR>/EVIDENCE.md`. The once-executed command, with the machine-local temporary root replaced by a reusable placeholder:

```sh
set -o pipefail
xcodebuild test -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -derivedDataPath "$EVIDENCE_DIR/targeted-dd" -resultBundlePath "$EVIDENCE_DIR/targeted.xcresult" -only-testing:BookAtlasTests/ManualRelationStoreTests -only-testing:BookAtlasTests/LibraryStoreTests > "$EVIDENCE_DIR/targeted.log" 2>&1
bookatlas_exit=$?
printf '%s\n' "$bookatlas_exit" > "$EVIDENCE_DIR/targeted-exit.txt"
exit "$bookatlas_exit"
```

The summary and full tree were parsed separately, without rerunning tests:

```sh
xcrun xcresulttool get test-results summary --path "$EVIDENCE_DIR/targeted.xcresult" --compact
xcrun xcresulttool get test-results tests --path "$EVIDENCE_DIR/targeted.xcresult" --compact
```

Before/after SHA-256 inventories cover 63 production/test/configuration files. Only the four authorized source/test files differ; the post-test manifest SHA-256 is `5c7b60de79a478abf60b263745e077d659bfea9cb1cca62f50d25d4f20f8d723`. No source edit followed the test. This is not a successful stage-2 freeze or a complete pending-change audit.

Complete non-UI, four-test relation UI, full UI, Release and incremental product audit were **not executed because stage 1 failed and needs scope expansion**; these are not skipped test counts. Busy UI and the excluded actor remain UNTESTED. Test compilation provides Debug evidence only for actually compiled code. Prior Release/non-UI evidence does not directly cover the new changes. Historical UI causes remain separately UNKNOWN and were not rediagnosed. Human mouse/keyboard acceptance, owner Git and final pending-delivery review remain outstanding. No git/gh, `.git` access, cleanup, system-setting change or publication occurred. Prompt 11A remains BLOCKED; stop for controller review, with no Prompt 11B work.

## 2026-09-05 — DEBUG-CONDITION-AND-GATE-CONTINUE-01: BLOCKED

Only project-level Debug `BA0000000000000000000401` gained `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) DEBUG";`. Byte comparison confirmed the single insertion; `plutil -lint BookAtlas.xcodeproj/project.pbxproj` exited 0. All 63 baseline files matched the preceding after manifest before editing. Existing DEBUG branches were limited to known suspended-save support. No source, test, assertion, target-level setting, Release, scheme, optimization, signature, entitlement or version change occurred.

Before and after modification, these read-only commands each exited 0 (four invocations total), retaining complete JSON/logs:

```sh
xcodebuild -showBuildSettings -json -project BookAtlas.xcodeproj -alltargets -configuration Debug
xcodebuild -showBuildSettings -json -project BookAtlas.xcodeproj -alltargets -configuration Release
```

Parsed comparison: all three unique Debug targets inherit DEBUG and only that setting changed. All Release settings remained equal without DEBUG. Actual directed-test SwiftDriver commands for BookAtlas, BookAtlasTests and BookAtlasUITests contain **`-DDEBUG`**, equivalent to `-D DEBUG`; no command-line/environment macro injection was used.

The remaining correction retry was consumed by this single invocation. `$EVIDENCE_DIR` represents the fresh temporary root; exact local commands and paths are retained in the handoff `EVIDENCE.md`:

```sh
xcodebuild test -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -derivedDataPath "$EVIDENCE_DIR/targeted-dd" -resultBundlePath "$EVIDENCE_DIR/targeted.xcresult" -only-testing:BookAtlasTests/ManualRelationStoreTests -only-testing:BookAtlasTests/LibraryStoreTests > "$EVIDENCE_DIR/targeted.log" 2>&1
bookatlas_exit=$?
printf '%s\n' "$bookatlas_exit" > "$EVIDENCE_DIR/targeted-exit.txt"
exit "$bookatlas_exit"
```

Original exit **65**; complete run **45 executed / 44 passed / 1 failed / 0 skipped**. LibraryStoreTests 32/33; ManualRelationStoreTests 12/12. All four new tests were discovered and executed: default temporary database/real relation access passed; invalid switch combinations passed; suspended access handshake/release/cancellation passed; explicit-memory fixture failed solely at line 44, relation state idle instead of content.

Summary and full test tree each parsed with exit **0**, separately from the test process:

```sh
xcrun xcresulttool get test-results summary --path "$EVIDENCE_DIR/targeted.xcresult" --compact
xcrun xcresulttool get test-results tests --path "$EVIDENCE_DIR/targeted.xcresult" --compact
```

Failure identity: `LibraryStoreTests/testSuspendedRelationSwitchAllowsOnlyExplicitMemoryFixture()`. Read-only diagnosis: BookDetailView's `.task(id:)` triggers relationship loading, but this test constructs the Store and waits for existing tasks without mounting the view or explicitly calling relation load. Its loaded-state assertion therefore lacks a lifecycle precondition. Application content, selected fictional identity and no-production-path assertions no longer fail. This is not evidence that DEBUG remains absent or that production save semantics have a new defect. No further source/test correction or rerun was performed.

The tested 63-file manifest SHA-256 is `d523ef061aadcb6ba69df83f3021fbf4415467b9aa164ed609b479b33362abbc`, rechecked unchanged after testing. No successful stage-2 freeze occurred. Full non-UI, four-test UI, full UI, Release and incremental product audit were **not executed because the directed prerequisite failed**, not counted as skipped tests. Old failure evidence and exit 65 remain unchanged. No UI confirmation was reused or UI test launched.

Prompt 11A remains BLOCKED. Busy native UI is UNTESTED; new Release compilation/fixture exclusion and actual product entitlements are NOT VERIFIED despite verified static Release settings. Intel execution is NOT VERIFIED. Human QA, owner Git and full pending-delivery review remain PENDING. Historical UI causes remain separately UNKNOWN and were not rediagnosed. Only MILESTONE-6 and this document received appended evidence beyond the one project setting. No git/gh, `.git` access, cleanup, system adjustment, archive or publication. Stop for controller review; no Prompt 11B.

## 2026-09-05 — TEST-LIFECYCLE-AND-GATE-CONTINUE-01: non-UI complete, UI confirmation pending

Only `testSuspendedRelationSwitchAllowsOnlyExplicitMemoryFixture` changed: async throws, safely unwrap the selected source ID, explicitly load relations and await pending work, then assert currentBookID and the original content state. All prior assertions remain. This supplies the detail-owned prerequisite in a unit test; it does not execute SwiftUI's lifecycle. No other code, test method, helper or configuration changed.

Both authorized non-UI gates ran once in unique DerivedData/result paths. In the following actual-command record, `$EVIDENCE_DIR` substitutes the new dedicated temporary directory whose exact local path is in the handoff:

```sh
xcodebuild test -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -derivedDataPath "$EVIDENCE_DIR/targeted-dd" -resultBundlePath "$EVIDENCE_DIR/targeted.xcresult" -only-testing:BookAtlasTests/ManualRelationStoreTests -only-testing:BookAtlasTests/LibraryStoreTests > "$EVIDENCE_DIR/targeted.log" 2>&1
xcodebuild test -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -derivedDataPath "$EVIDENCE_DIR/nonui-dd" -resultBundlePath "$EVIDENCE_DIR/nonui.xcresult" -only-testing:BookAtlasTests > "$EVIDENCE_DIR/nonui.log" 2>&1
```

These were separate command sessions, each immediately capturing `$?` in `bookatlas_exit`, recording it in its own `<batch>-exit.txt` and exiting with that value. Both original xcodebuild exits were **0**. For each result bundle, summary and full tests-tree parsers separately exited **0**:

```sh
xcrun xcresulttool get test-results summary --path "$EVIDENCE_DIR/<batch>.xcresult" --compact
xcrun xcresulttool get test-results tests --path "$EVIDENCE_DIR/<batch>.xcresult" --compact
```

Directed: **45 executed / 45 passed / 0 failed / 0 skipped**, LibraryStoreTests 33 plus ManualRelationStoreTests 12. All four new identities, including the handshake, were executed. Full non-UI: **221/221 passed, 0 failed, 0 skipped**. Complete tree names exactly matched source identity lists for both gates. Debug test compilation is the build evidence; all three actual SwiftDriver target commands show -DDEBUG. No extra independent Debug build or single-case trial was run.

After directed success, 63 source/test/configuration files were frozen with manifest SHA-256 `36f3e76d74b2049f97674c23598e459093f3688a3e34dbea997add5a5f02b2ab`. Recheck after complete non-UI matched 63/63. Only the authorized test method differs from this round's incoming baseline. Original 44 UI identities remain among the current 45 source identities.

No fresh interactive-session confirmation has yet been received for this round. Execution therefore pauses **before** the four relation UI cases; no old confirmation is reused. Targeted UI, full UI, Release and incremental product audit are not executed (not skipped tests); their conditional budgets remain unused. Before continuing, obtain confirmation and verify the frozen files remain identical. Busy native UI remains UNTESTED; new Release executable exclusion, architectures/signatures are NOT VERIFIED. Intel hardware runtime remains NOT VERIFIED. Human QA, manual Git and complete pending-change scope remain PENDING; prior UI causes remain separately UNKNOWN. Prompt 11A stays BLOCKED, with no Prompt 11B work. No git/gh, `.git` access, cleanup, system settings changes, archive or publication.
