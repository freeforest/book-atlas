# Prompt 10 quality audit

This document records the accepted Prompt 10 implementation evidence and its
boundaries. Prompt 10 passed independent acceptance at documentation baseline
`ec0b04f1c004ef5c897d3269e335c92034d6021e`, against verified code baseline
`4cc20b8c88cb674a4f9a52d3e8de70c295169281`. This acceptance does not state
that GitHub is public, a tag or GitHub Release exists, an application was
uploaded, or Apple binary distribution occurred.

## Accepted evidence closure

The current code baseline is
`4cc20b8c88cb674a4f9a52d3e8de70c295169281` (parent
`dfe49d724fdadc203a715d7e744d0a9e91bd5ad7`). Independent review accepted this
evidence at `ec0b04f…`. Prompts 0–10 are complete, no Prompt 11 starts
automatically, and subsequent GitHub source-publication preparation is not a
new product-development stage.

The three historical graph UI failures occurred while clicking semantic graph
nodes. The zero-height object was an anonymous `AXScrollArea` within
`local-graph-page` → `graph-accessibility-panel`, with observed frames
`{{517,615.5},{732,0}}` and `{{517,623},{732,0}}`; it was not
`graph-filter-control`, whose measured height was 20 points. At a 732-point
content width, the old 760-point threshold incorrectly chose the vertical
layout, and the Canvas plus details minimum heights compressed the node list to
zero. The minimal production change lowers that threshold to 700 and gives the
node list a 120-point minimum height. It changes no relationship, weight,
filter, data, revision, Schema, migration, or persistence semantics.

The test repair reliably selects fixed fictional UUID `…0601`, verifies
`《雾港图谱中心》`, the detail view, and the exact
`show-local-graph-button`, and scrolls only `book-detail-view` when the button
is outside that viewport. It retains page/window/target/scroll-ancestor
diagnostics and uses no arbitrary sleep, coordinate click, retry-on-failure,
skip, assertion deletion, or global `scrollViews.firstMatch`.

### Current automated and build result

- Targeted graph regressions: 3/3 actually executed and passed, zero failed,
  zero skipped. An initial Xcode/CoreSimulator/test-service connection failure
  executed zero tests and is not counted; a fresh path produced the valid 3/3
  result.
- Complete UI: XCUIAutomation initialized; 41/41 actually executed and passed,
  zero failed, zero skipped. The result summary and tests tree agreed.
- Complete non-UI: 200/200 actually executed and passed, zero failed, zero
  skipped. The result summary and tests tree agreed. A preceding complete run
  produced 199 passes and one benchmark process `signal term`, with no XCTest
  assertion failure. That runner/infrastructure termination is not counted as
  a pass; the benchmark passed alone, then a fresh complete path passed
  200/200.
- Debug and Release both reported `BUILD SUCCEEDED`. The evidence paths
  `/tmp/bookatlas-p10-4cc20-debug` and
  `/tmp/bookatlas-p10-4cc20-release` are temporary run locations, not stable
  release assets.

The older 37/37 selection-idempotence suite and 40/40 editor-validation suite
remain valid stage-specific history, not the latest full UI count. Their
documented 36/37, 39/40, zero-test, helper-assertion, test-service, and Xcode
internal QoS histories remain classified separately and are not promoted to
passes.

### Current fixed-fictional manual result

The current Debug build used an in-memory store, fixed fictional library,
merge, graph, reading-entry, portability, and restore seeds, and ignored saved
window state. It did not access the production Application Support database,
select or read a real file, read private Apple Books data, open a real HTTPS
destination/browser, perform a real import or restore, or write real clipboard
content. It added no dependency, network access, or permission.

- Light: “全部书籍”, the empty “选择一本书” detail, A101 author/status/date,
  exact-result and terminal paging status, reading entry, graph filters, node
  list, selection, open-detail, and set-center actions were clear. No clipping,
  overlap, obstruction, or color-only meaning was reported.
- Dark: the corresponding Library and Graph states were clear without lost
  hierarchy, overbright elements, ambiguous selection, clipping, overlap,
  obstruction, or color-only meaning.
- Graph: default-window and Light/Dark layouts had a full nonzero relationship
  filter row, working horizontal scrolling, a usable semantic node list, and
  working open-detail/set-center actions.
- Exact small window: the real element was `书库, standard window`, role
  `AXWindow`, subrole `AXStandardWindow`, size 520×360. Library search,
  filter/sort, scrolling selection, empty/selected detail, counts, and terminal
  status were reachable. Graph filters, horizontally reachable relationship
  types, node list, selection, and actions were reachable. The editor Form,
  fields, validation summary/field errors, Save/Cancel, and discard confirmation
  were reachable. No permanent unreachable operation, clipping, overlap, or
  obstruction was reported. This check is `PASS`.

The earlier complete human gate for the purple accent, Reduce Motion, complete
pointer-free keyboard operation, and VoiceOver remains prior-build evidence;
it was not all rerun on `4cc20b8c…`. It remains distinct from the current
Light/Dark, graph, 520×360, and Inspector supplements.

### Current Accessibility Inspector results

The historical audits are retained: the old-build selected-book state produced
25 warnings, and a different old-build state later produced 16. Warning totals
vary with UI state. Those histories include the former “全部书籍” and “选择一本书”
contrast defects and separately classified system/framework warnings; they are
not deleted or rewritten by the current result.

- State A: current Debug, Light, no selected book, right side showing
  “选择一本书”. The node is `AXStaticText`, label “选择一本书”, value the
  explanatory text, identifier `library-selection-empty`, enabled. The formal
  audit reported 0 total warnings: duplicates 0, Contrast 0, Description 0,
  Action 0, Parent/Child 0, and other 0.
- State B: current Debug, fixed-fictional A101 selected with its full detail and
  reading entry. `book-detail-view` was a nonzero `AXScrollArea` measured at
  379.5×649.0. The formal audit reported 0 total warnings: duplicates 0,
  Contrast 0, Description 0, Action 0, Parent/Child 0, and other 0.

These results show that the historical warnings did not reproduce in the two
audited current states. They do not claim every page or future UI state is
permanently warning-free. No new product defect was confirmed by either audit.

### Historical native file panel limitation

With fixed-fictional A101 selected, “选择本地文件…” returned cancellation
semantics without actually displaying a macOS `NSOpenPanel`. No file was
selected or read and the library remained unchanged. The result is
`PASS WITH LIMITATION — 未实际显示原生系统文件面板`, not a native-panel pass.

The fixed-fictional adapter returned cancellation directly. No real file was
selected or read, the library remained unchanged, no browser or Apple Books
launch was observed, no real long-lived bookmark was exercised, and real
external-system behavior remains unverified. These are functional-integration
limitations, not Mac App Store or Apple binary-distribution gates.

## V1.0.0 macOS 26 source-publication verification

The clean committed verification baseline is
`71ec000c65179bdbcae08981631c9dff7df7c711`. The sole change after
`223e3ccfe12c8decd8e7a292cac2df34e27c6154` is
`BookAtlasUITests/BookAtlasUITests.swift`: it adds immediate exact-value
diagnostics after the existing author-field and Command-F inputs, without a
production-code change, retry, sleep, focus bypass, shortened string, or
weakened business assertion. Original and diagnostic author/Command-F paths
each passed 10/10 relaunch-enabled no-retry repetitions. The earlier transient
space-loss and missing-A101 failures did not reproduce, and their unique
underlying cause remains unknown rather than being attributed to the product,
macOS, focus, window activation, or an input method.

The final UI result
`/tmp/bookatlas-v1-full-ui-diagnostic-223e3cc.xcresult` was re-parsed from its
summary, tests tree, and relevant activities. XCUIAutomation initialized on
macOS 26.5.2 arm64; 41/41 tests passed, with zero failed, zero skipped, and zero
expected failures. Both historical paths are present, and the activities
actually execute `value == "Manual Acceptance Author"` and
`value == "A101"`. Six Xcode `[Internal]` QoS runtime diagnostics occur in six
other passing tests. Without a stack trace or reproducible product symptom,
they remain tool warnings and are not promoted to product defects.

Fresh Debug and Release products built successfully under separate new `/tmp`
DerivedData paths. The fresh complete non-UI bundle parsed consistently in the
summary and tests tree as 200/200 passed, zero failed, zero skipped, and zero
expected failures on macOS 26.5.2 arm64. Schema remains 5 with migration path
`1 → 2 → 3 → 4 → 5`. The build logs contain the ordinary AppIntents metadata
extraction skip because no AppIntents framework dependency exists; no
deterministic compiler or linker failure occurred.

Actual Debug and Release products both report version 1.0.0, build 1, bundle
identifier `io.github.freeforest.BookAtlas`, and minimum macOS 26.0. Debug is
arm64 and ad-hoc signed with App Sandbox, user-selected read/write,
app-scoped bookmarks, and Debug-only `get-task-allow`. Release contains arm64
and x86_64 slices, both with minimum macOS 26.0, and is ad-hoc signed with
Hardened Runtime plus only App Sandbox, user-selected read/write, and
app-scoped bookmarks. Neither has a network-client, Apple Events, automation,
or Downloads entitlement, Team ID, Developer ID, distribution certificate, or
provisioning profile. Local ad-hoc signing is not distribution signing.

The final Debug app used an in-memory store, two fixed-fictional A101 records,
fixed-fictional reading entries, and the explicit system-file-panel QA switch.
Only file selection/bookmark services used their production system adapters.
The human observer saw a real macOS `NSOpenPanel` and cancelled it immediately,
without browsing, selecting, or reading any file. The app remained stable, the
library count stayed at two, no local-file record appeared, and the app showed
“已取消选择；书库未更改。” The current narrow result is
`PASS — 真实 NSOpenPanel 已显示并安全取消`. It supersedes the current limitation
for display-and-cancel only while retaining the earlier `PASS WITH LIMITATION`
as history; real file selection, bookmark creation/resolution, browser, Apple
Books, and other external-system behavior remain unverified.

Tracked/untracked artifact and tracked-text scans found no private database,
WAL/SHM/journal, backup, bookmark BLOB, real reading list/note, current-user
absolute path, private URL, secret, API credential, DerivedData, `.xcresult`,
`.app`, `.dmg`, `.pkg`, binary application archive, certificate, private key,
provisioning profile, or signing material. `LocalData/.gitkeep` is empty;
samples and the generator are fixed fictional and use `example.invalid`.
Production has no telemetry, advertising, tracking, crash upload, network
client entitlement, third-party binary dependency, or new permission. A
read-only process check could not read the process table because the system
monitoring service was unavailable, so no claim of “no residual process” is
made; the user reported the test window closed.

## GitHub source-publication boundary

The confirmed publication strategy is GitHub source code only, built by users
with Apple's Xcode, Swift, SwiftUI, AppKit, and system SQLite. It excludes Mac
App Store submission, precompiled `.app` downloads, Apple Developer membership,
App Store Connect/Review, Developer ID Application/Installer, distribution
certificates and profiles, Apple notarization, stapling, and Gatekeeper
acceptance for a distributed binary. Those items are not pending gates under
the current strategy. Local ad-hoc builds, App Sandbox, Hardened Runtime, and
entitlement inspection remain accepted local evidence only.

V1.0.0 supports macOS 26 only, without macOS 14/15 compatibility promises or a
multi-version matrix. The production project, application, unit tests, and UI
tests declare deployment target 26.0; ADR-0009 supersedes the historical macOS
14 decision. The fresh Debug, Release, complete non-UI, complete UI with actual
XCUIAutomation initialization, fixed-fictional data, actual-product metadata,
entitlement, real-panel cancel, and repository/privacy checks are recorded
above for `71ec000c…`.

The confirmed repository is `freeforest/book-atlas` and became Public on
2026-08-10. The confirmed copyright is `2026 FreeForest`; version 1.0.0, tag
`v1.0.0`, Release title `Book Atlas v1.0.0`, and bundle identifier
`io.github.freeforest.BookAtlas` are fixed. Public access and PVR are closed
online gates as detailed below. The separate private conduct-reporting channel
is configured as detailed below, and its documentation was committed and
pushed at `fb0c073fc9fad7a0846d78bc560c213ff5fcc8df`, closing that policy
gate. The confirmed release date is 2026-08-10, and the changelog and release
notes are finalized for that date. On 2026-08-10, the final independent pre-tag
review passed on clean baseline
`0009ec83cc192d4b2f0e67a4cc7efd4e3e25bc81`; it found no P0, P1, or P2 product,
test, privacy, security, or publication-material issue. At the time of that
review, no tag, Release, source attachment, application-binary upload, or formal
V1.0.0 announcement existed. The subsequent source-only publication is recorded
below. Repository operations require explicit repository-owner authorization,
and authentication challenges remain owner-only. If a
precompiled GitHub Release
application is considered later, Developer ID, notarization, Gatekeeper,
signing, integrity, installation, and update policy must be reopened in a new
authorized task.

### V1.0.0 GitHub source release — 2026-08-10

The annotated tag `v1.0.0` was created and pushed with tag object
`b79a2bbaa325896e22d7362c2116180cf27fd7b7`; its peeled commit is exactly
`991d932a5fafe0d9821b46ec5e779cd6c9849171`. A draft Release was first created
and checked before publication. Its tag and title were `v1.0.0` and
`Book Atlas v1.0.0`, it was not a prerelease, its body matched
`docs/RELEASE_NOTES-1.0.0.md`, and its custom asset list was empty.

The draft was then published as Latest at
<https://github.com/freeforest/book-atlas/releases/tag/v1.0.0>. GitHub reported
`publishedAt = 2026-08-09T18:52:41Z`, corresponding to 2026-08-10 02:52:41
UTC+08:00. Post-publication CLI and public-page checks confirmed `isDraft =
false`, `isPrerelease = false`, the exact Release Notes body, zero custom assets,
and only GitHub-generated Source code (zip) and Source code (tar.gz) archives.
The repository remained Public, default branch `main` was unchanged, and the
public Security page continued to expose **Report a vulnerability**. No custom
source archive, application binary, Discussion, or other attachment was added.

This publication evidence does not expand the accepted product evidence. The
real `NSOpenPanel` result still covers display and safe cancellation only;
Inspector zero-warning evidence still covers only states A and B; the earlier
transient UI failures still have no proven unique root cause; and no cross-device
or binary-distribution claim is made.

### Public and PVR online gate — 2026-08-10

Before the visibility change, a complete scan covered all reachable commits,
trees, and blobs plus the GitHub online public surface. The repository history
contained two distinct non-GitHub-noreply commit email identities; the user
explicitly authorized both for publication, and their values are not repeated
in this audit. The online repository had 35 commits, 0 tags, no Actions
workflow/run/log/artifact, 0 Issues, 0 Pull requests, Discussions disabled,
Wiki disabled or empty, no published or draft Release, and no Package. No
online attachment or private-content risk was identified.

The repository changed from Private to Public while remaining
`freeforest/book-atlas` with default branch `main`. The logged-in page displayed
Public, and independent access without an administrator login confirmed that
the repository home page was publicly readable. Private Vulnerability
Reporting was enabled; its settings page displayed **Disable private
vulnerability reporting**, and the public Security page displayed **Report a
vulnerability** linked to the private reporting flow. The administrator's
**New draft security advisory** control is the role-specific maintainer view,
not evidence that external reporting failed. No test report or draft advisory
was created, and no other repository or security setting was changed. Local
HEAD remained `bea61ca27669b1314f8e2c672ac334ebdf875967`, `main` remained 0/0
with `origin/main`, and no tag was created during the online operation.

### Private conduct-reporting gate — 2026-08-10

The user selected an existing dedicated project email channel for private Code
of Conduct, harassment, and community-safety reports. The user confirmed
control of the address, authorized its public inclusion in the repository, and
accepted the exposure and spam risk. The authoritative address appears only in
[`CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md) and is not duplicated in this
audit. No test message was requested or sent.

This channel is separate from GitHub Private Vulnerability Reporting. Conduct
and community-safety reports use the dedicated conduct channel; security
vulnerabilities continue to use the private flow documented in `SECURITY.md`.
The channel configuration closes the conduct-reporting policy gate, but it
does not create a tag, GitHub Release, announcement, or V1.0.0 release decision.

## Automated quality coverage

- The complete unit/integration suite covers CRUD, query composition,
  organization, duplicate decisions and transactional merge rollback,
  portability, strict backup/restore and interruption recovery, graph
  invalidation, HTTPS/bookmark safety, and external-reading state isolation.
- The ordinary library list now fetches a deterministic 200-row first page,
  exposes the exact filtered total, and keeps a bounded presentation array.
  “加载更多” and Shift-Command-L append one page; search, filter, sort, and
  mutation refreshes restart from the first page. Failure retains the rows
  already shown and exposes a retry action. The status “已显示 N 本，共 T 本”
  and its page-readiness value are published atomically to keyboard and
  accessibility clients, so rows after 500 are no longer silently hidden and
  a following keyboard command cannot race a still-disabled control.
- Explicit UUID focus from the graph and after create/edit/merge is identity
  preserving across page boundaries. The catalog returns the normal first
  page plus at most one query-filtered UUID match; the detail and a separate
  accessible “已定位书籍” row remain bound to that identity. Missing, deleted,
  or excluded targets clear selection and show a redacted recoverable state
  instead of substituting another book. Cancellation plus request-generation
  checks reject late focus/query/page results.
- The same identity failure state now has presentation priority even when the
  ordinary page contains zero books. A missing requested UUID renders the
  specific redacted unavailable state; a query-excluded UUID renders the
  distinct outside-current-results state and a keyboard/accessibility clear
  action. Neither can be hidden by the generic empty-library or no-results
  placeholders, and neither selects an unrelated row.
- `List(selection:)` is bound to local SwiftUI state rather than directly to
  three `@Published` Store properties. A generation-tagged bridge applies the
  latest changed UUID to the Store after the List selection update and mirrors
  programmatic Store selection back without feedback. Re-selecting the same
  UUID is a no-op and preserves a valid off-page focused detail.
- The historical migration matrix starts from every formal Schema 1–5
  definition, migrates to Schema 5 twice, and checks the data families
  available at that source version: books/notes, tags, lists/descriptions,
  sources/details, external links, manual relations, duplicate keys, ignored
  pairs, and local-file bookmark records.
- `AppNavigationTests` hosts the real shell at 520×360 and 1280×800 and under
  Aqua and Dark Aqua appearances. Production uses system fonts, semantic
  foreground styles, and system accent color. The graph also conveys center
  and selection through shape/text and an accessibility list rather than
  color alone.
- The production UI has no continuous or decorative animation calls. Reduce
  Motion therefore removes no information and has no alternate timing path to
  test. Canvas interaction is direct input state, not animated motion.
- Keyboard coverage includes navigation, list selection, creation/save/cancel,
  delete confirmation, import cancellation, restore cancellation boundaries,
  duplicate-review nested Escape, and Command-F search focus. Graph content has
  a semantic keyboard/accessibility list parallel to Canvas.
- Every UI test launches an in-memory library with fixed fictional seeds and
  fake/no-op external integrations. It never opens a real file picker,
  browser, Apple Books item, pasteboard, user database, or user file.
- The search/status-filter regression explicitly selects the fixed A101 UUID,
  verifies that detail identity before and after filtering, and only then
  excludes it with a zero-result query. The shared XCUI text-input helper
  activates the application, waits for its window and the target element,
  clicks, and requires `hasKeyboardFocus` before replacing text. It allows one
  bounded reactivate/reclick fallback; it has no sleeps, loops, or XCTest retry.
  A no-retry, relaunch-enabled result bundle contains ten passed repetitions.
- Existing-library launch measurements are the sole exception to the
  in-memory rule and remain isolated: an unmeasured test process creates a
  fixed-fictional Schema 5 database in a UUID-named child of the process
  temporary directory; measured processes can only reopen that exact regular
  file without SQLite create fallback. Unknown arguments, unsupported sizes,
  symlinks, non-regular files, unexpected artifacts, and missing databases
  fail closed rather than resolving the production Application Support path.
  The test closes the database and removes its database/WAL/SHM/journal files
  and controlled directory on every normal completion path.

## Error recovery

Regression tests cover unavailable/open failures, validation without draft
loss, failed writes/deletes, merge conflict and rollback, malformed/oversized
imports, confirmed-import cancellation and rollback, disk-full mapping,
corrupt/future/symlink backups, recovery copies, failed replacement/reconnect,
three process-interruption boundaries, missing/corrupt/revoked bookmarks,
unsafe URLs, graph cancellation, missing centers, and stale asynchronous
results. Errors expose stable categories and recovery actions instead of
private payloads.

## Privacy, security, and logging

- Production source contains no telemetry, advertising, analytics, crash
  upload, network client, `URLSession`, WebView, Shell, Process, AppleScript, or
  private Apple Books data access.
- There are no production `print`, `NSLog`, `os_log`, or `Logger` call sites.
  Consequently no private payload is emitted by an application logging path.
  Performance printouts exist only in fixed-fictional tests.
- External dispatch and file selection remain explicit user actions behind
  focused adapters. URL validation, bookmark size/canonical-name checks,
  security-scope balancing, CSV formula protection, parser bounds, symlink
  rejection, and transactional restore/merge guarantees remain unchanged.
- The repository ignore policy covers databases and sidecars,
  `.bookatlasbackup`, bookmarks, signing material, `DerivedData`, and
  `.xcresult`. The tracked-file and complete reachable-history scans were
  completed before the repository became Public on 2026-08-10.
- The local Release configuration enables Hardened Runtime and disables
  Xcode's base-entitlement injection. Inspection of the built product found
  only App Sandbox, user-selected read/write, and app-scoped bookmarks; it did
  not contain `get-task-allow`, network, Apple Events, automation, Downloads,
  or broad filesystem access. The product is ad-hoc signed local evidence, not
  a distribution archive; no distribution archive is planned under the current
  source-only strategy.

## Dependency and license inventory

The production Xcode target has no Swift package or third-party binary
dependency. It uses SwiftUI, AppKit, Foundation, UniformTypeIdentifiers, and
the system SQLite library (`-lsqlite3`). The isolated technical-spike Swift
package also declares no external package. Apple SDK components are governed
by their platform terms and are not vendored into this repository.

`LICENSE` is MIT with the user-authorized copyright line
`Copyright (c) 2026 FreeForest`. This statement is not legal advice.

## Manual accessibility and visual audit history

### Historical attempted environment

- Date: 2026-07-30
- Hardware: Apple M2 MacBook Air, 24 GB memory
- Session: logged-in interactive console session, macOS 26.5.2 (25F84)
- Build/data: local Debug build and fixed fictional in-memory seeds only
- Appearance before the attempt: Light, default accent color, Reduce Motion
  off

Accessibility Inspector was launched from the installed Xcode 26.6 bundle and
its `axAuditService` process was observed. That launch also appeared to
XCUIAutomation as the frontmost `com.apple.AccessibilityInspector` window.
The task execution surface, however, did not provide a trusted desktop-control
bridge capable of selecting Inspector targets, reading its results, driving
VoiceOver, changing appearance/accessibility settings, or inspecting the
screen without exposing unrelated private desktop content. The attempted
computer-control bridge rejected initialization because it was not running in
its trusted runtime. The Inspector process launched for this attempt was then
closed so it could not contaminate automated UI results.

A second attempt was made on 2026-08-03. The supported Computer Use runtime
successfully initialized and enumerated running applications, then the local
Debug product was started with the explicit in-memory store and fixed
fictional UI seed. The production database path was never opened. Its native
pipe closed before returning the first Book Atlas app-state/accessibility-tree
response. Because no Book Atlas desktop or AX state could be read, the attempt
did not change
appearance, accent, window size, Reduce Motion, VoiceOver, or Inspector
settings and did not claim any manual result. The fictional app process was
then terminated.

At the time of those two attempts, no required gate was marked PASS.
Automated identifiers, hosted-view smoke tests, and XCUI keyboard paths were
supporting evidence only. Subsequent human gates and the current-build
supplements are recorded below; the failed attempts remain historical facts.

| Required manual check | Intended path/evidence | Actual result |
| --- | --- | --- |
| Light and Dark appearance | Compare sidebar, list, details, forms, previews, graph, reading entries, errors, focus, contrast, truncation, and color independence in both appearances | **PASS for the completed human gate plus current supplement** — the original Light editor-validation FAIL remains below, its corrected path was subsequently rechecked, and current `4cc20b8c…` Library/Graph Light and Dark states passed without reported clipping, overlap, obstruction, or color-only meaning. |
| Non-default system accent | Change to a non-default accent and inspect selection, buttons, focus, graph state, and contrast | **PASS on the prior human gate** — purple accent evidence is retained; it was not rerun across every `4cc20b8c…` state. |
| 520×360 and normal window | Operate search, filters, sort, status, forms, previews, graph alternative list, and reading entries at both sizes | **PASS** — current AXWindow evidence confirmed exactly 520×360 and the Library, Graph, and editor operations listed above remained reachable. |
| Reduce Motion | Enable the system setting and complete every primary flow without loss of state or action | **PASS on the prior human gate** — not rerun across every `4cc20b8c…` state. |
| VoiceOver traversal | Record focus order plus spoken label, value, state, and actions for every coverage area below | **PASS on the prior human gate** — retained as prior-build evidence, not represented as a complete rerun on `4cc20b8c…`. |
| Accessibility Inspector | Select coverage areas, run the official audit, and record unlabeled/duplicate/focus/contrast/hit-target findings | **PASS for current states A and B only** — each formal audit reported 0 warnings; this is not a whole-application permanent-zero claim. |
| Full keyboard flow | Complete navigation, search/filter/sort, CRUD, organization, duplicate, portability, graph, and reading-entry flows without pointer use | **PASS on the prior human gate** — not represented as a complete rerun on `4cc20b8c…`; automated XCUI evidence remains separate. |

The coverage inventory used by the human VoiceOver/Inspector work is:

- sidebar and menu bar;
- book list, search, filters, and sorting;
- book detail, editor, and form validation errors;
- tag, list, and source management;
- duplicate candidates, candidate detail, and merge preview;
- CSV import preview;
- backup and restore confirmation;
- graph semantic nodes and relationship list;
- HTTPS, Apple Books fallback, and local-file reading entries.

The original environment blocker applied to the two historical attempts, not
to the later completed human evidence. Current Inspector evidence is still
limited to states A and B, prior accent/Reduce Motion/keyboard/VoiceOver results
were not all repeated on `4cc20b8c…`, and independent review must preserve
those evidence boundaries after acceptance and in any future public claims.

### Manual editor-validation finding and code closure

On the fixed-fictional in-memory Debug app, a human reviewer opened a new-book
sheet in Light mode, pressed Command-S on an empty draft, then entered the
fictional author “人工验收作者” while leaving the title blank and clicked Save.
The sheet remained open, but the current viewport showed no error text, state
change, or perceptible focus response. The cause was a single validation label
after the note editor at the bottom of the long scrolling Form; assigning an
already-focused title field did not provide additional feedback.

The implementation closure moves the summary outside the scrolling Form,
adds inline field explanations, moves focus to a missing title or author, and
posts a privacy-safe accessibility announcement for every invalid submission,
even when the error enum is unchanged. Automated UI evidence verified visible
frame intersection, exact error semantics, draft preservation, no database
write, and shared mouse/Command-S behavior. The original manual FAIL remains
part of the history; it was subsequently rechecked within the completed human
gate. The current-build Light/Dark, exact-window, graph, and Inspector
supplements and the prior-build accent/Reduce Motion/keyboard/VoiceOver
boundary are recorded above.

The final closure bundles executed 200/200 non-UI tests and 40/40 complete UI
tests with no failure or skip. The direct fixed-fictional author/no-title mouse
path also passed 3/3 without XCTest retry. The complete UI activity tree has
zero SwiftUI view-update publication warnings; six Xcode-internal QoS
diagnostics are recorded separately. A preceding 39/40 UI attempt failed in a
generic test scroll helper before duplicate review began: it targeted the first
application ScrollView rather than the editor Form. The helper was scoped to
the editor without reducing the note-preservation assertion, the focused path
passed 1/1, and the final full suite passed it. Those results were automation
evidence and did not themselves constitute the later manual VoiceOver or visual
recheck.

### Seventh-closure XCUI evidence and limitations

The final UI result bundle at
`/tmp/bookatlas-p10-nogo7-final-ui.xcresult` was parsed with both
`xcresulttool` summary and tests-tree commands: 37 tests passed, zero failed,
and zero skipped. The complete final-code non-UI suite passed 193/193. The
search/filter and keyboard-selection cases each passed ten relaunch-enabled
repetitions with no retry-on-failure setting; the three key selection paths
also passed 3/3.

Failure history is retained rather than replaced by the final green run. The
first complete run in this closure executed all 37 tests and produced 36
passes plus one failure in the nested duplicate-draft test. That full failure
and one subsequent focused rerun failed only at helper assertions that treated
SwiftUI `TextEditor`'s `hittable`, then `enabled`, AX attributes as authoritative;
both logs showed the control could subsequently be clicked, focused, and
typed into. After the helper switched to post-click keyboard focus as the
authority, that focused test passed and the final full suite passed 37/37.
These were test-helper assertion failures, not a search-result assertion,
product-state failure, or observed external-window interruption.

Two initial focused attempts produced sealed zero-test bundles because
XCUIAutomation timed out while enabling automation mode. They are retained as
infrastructure failures, not counted as product passes or test failures. A
third focused run executed both selection cases and passed 2/2.

The first final-code non-UI attempt likewise executed no test case because the
sandbox denied `testmanagerd.control` helper communication. Its failed bundle
is retained. A new path outside that restriction executed all 193 tests and
passed without failure or skip.

Parsed activities for all ten search repetitions, all ten keyboard-selection
repetitions, and all 37 final-suite cases contain zero occurrences of
“Publishing changes from within view updates is not allowed”. The keyboard
10-run bundle contains ten Xcode `[Internal] Thread running …` QoS diagnostics,
and the complete suite contains six such diagnostics in six cases. Those are
tracked separately from the resolved SwiftUI warning; the activities provide
no evidence that they originate in the production selection code.

### Eighth-closure selection idempotence evidence

The Store now clears a focused page-out book only when that focus is non-nil
and its UUID differs from the requested selection. Four new state regressions
observe `objectWillChange`: repeated ordinary in-page UUID and repeated empty
nil selection emit zero publications; matching focused identity is retained
without publication; and a different UUID or nil clears an existing focus.
The complete non-UI result bundle parsed as 197 passed, zero failed, and zero
skipped. The complete UI result bundle parsed as 37 passed, zero failed, and
zero skipped. Its 37 activity trees contain zero SwiftUI view-update
publication warnings. Six Xcode internal QoS diagnostics remain in six tests
and are tracked separately from product behavior.

An initial focused UI command used an incomplete XCTest selector and executed
zero tests despite `xcodebuild` reporting success. It is retained as a
non-evidence command error; the corrected focused result executed 4/4 key
selection paths, and the unique complete bundle executed all 37 tests.

### Remaining evidence boundaries after local V1.0.0 verification

Current physical-pointer visual checks and the real-panel display/cancel pass
are recorded above. Real file selection and bookmark creation/resolution, real
browser/Apple Books behavior, and whole-application Inspector coverage remain
evidence limitations. A distribution-signed archive, notarization, Gatekeeper
binary assessment, and macOS 14 runtime matrix are not applicable to the
confirmed source-only/macOS 26 policy. The production project and products are
aligned to minimum macOS 26.0; historical technical-spike macOS 14 settings are
not production support claims.

## GitHub source-publication risks and gates

- Project and actual Debug/Release products agree on bundle identifier
  `io.github.freeforest.BookAtlas`, marketing version 1.0.0, build 1, and
  minimum macOS 26.0.
- `LICENSE` now contains the user-confirmed `2026 FreeForest` line.
- GitHub Private Vulnerability Reporting is enabled, and the public
  non-administrator Security view exposes **Report a vulnerability**. A public
  Issue is not a private vulnerability channel.
- `CODE_OF_CONDUCT.md` now publishes the user-authorized dedicated project
  conduct-reporting channel. The user confirmed control and the private-review
  purpose; the address is not repeated in this audit, and no test message was
  sent. PVR remains limited to security vulnerabilities and is not represented
  as a conduct channel.
- Verification is on one Apple M2 MacBook Air with 24 GB memory and macOS
  26.5.2. V1.0.0 is macOS 26-only; the local verification is complete on that
  host. A clean committed `bea61ca…` baseline was verified before the Public
  transition; cross-device coverage remains outside this evidence.
- Debug XCUIAutomation produced existing-library launch, page-load, and
  scrolling/hitch metrics. A Release Instruments run using the same
  pre-generated-library protocol could not be authorized through the current
  execution surface after its unmeasured preparation step; therefore no
  Release launch or scrolling number is reported in this closure. Earlier
  launch numbers that included in-process test-data generation are explicitly
  superseded and are not treated as an existing-library launch baseline. This
  is not a source-publication blocker.
- Backups are unencrypted, recovery copies have no automatic retention policy,
  Possible duplicate review is capped without pagination, and external
  application behavior remains outside Book Atlas's control.
