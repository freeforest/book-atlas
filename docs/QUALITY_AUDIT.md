# Prompt 10 quality audit

This document records implementation evidence for independent review. It does
not state that Prompt 10 passed, that a stable version was released, or that
release signing/notarization occurred.

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
  `.xcresult`. The release checklist requires a tracked-file scan before any
  distribution.
- The local Release configuration enables Hardened Runtime and disables
  Xcode's base-entitlement injection. Inspection of the built product found
  only App Sandbox, user-selected read/write, and app-scoped bookmarks; it did
  not contain `get-task-allow`, network, Apple Events, automation, Downloads,
  or broad filesystem access. The product is still ad-hoc signed and is not a
  distribution archive.

## Dependency and license inventory

The production Xcode target has no Swift package or third-party binary
dependency. It uses SwiftUI, AppKit, Foundation, UniformTypeIdentifiers, and
the system SQLite library (`-lsqlite3`). The isolated technical-spike Swift
package also declares no external package. Apple SDK components are governed
by their platform terms and are not vendored into this repository.

`LICENSE` is an MIT template with `[YEAR] [COPYRIGHT HOLDER]` deliberately
unresolved. A maintainer must supply accurate values after appropriate review;
this statement is not legal advice.

## Manual accessibility and visual audit

### Attempted environment

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

Accordingly, no item below is marked PASS. Automated identifiers, hosted-view
smoke tests, and XCUI keyboard paths are supporting evidence only and are not
substituted for a human result.

| Required manual check | Intended path/evidence | Actual result |
| --- | --- | --- |
| Light and Dark appearance | Compare sidebar, list, details, forms, previews, graph, reading entries, errors, focus, contrast, truncation, and color independence in both appearances | **BLOCKED — not manually executed** |
| Non-default system accent | Change to a non-default accent and inspect selection, buttons, focus, graph state, and contrast | **BLOCKED — not manually executed** |
| 520×360 and normal window | Operate search, filters, sort, status, forms, previews, graph alternative list, and reading entries at both sizes | **BLOCKED — not manually executed** |
| Reduce Motion | Enable the system setting and complete every primary flow without loss of state or action | **BLOCKED — not manually executed** |
| VoiceOver traversal | Record focus order plus spoken label, value, state, and actions for every coverage area below | **BLOCKED — VoiceOver was not driven** |
| Accessibility Inspector | Select every coverage area, run the official audit, and record unlabeled/duplicate/focus/contrast/hit-target findings | **BLOCKED — Inspector launched, but no target/audit could be controlled or read** |
| Full keyboard flow | Complete navigation, search/filter/sort, CRUD, organization, duplicate, portability, graph, and reading-entry flows without pointer use | **BLOCKED as a manual audit**; automated XCUI keyboard regressions passed separately |

The unresolved VoiceOver/Inspector coverage is:

- sidebar and menu bar;
- book list, search, filters, and sorting;
- book detail, editor, and form validation errors;
- tag, list, and source management;
- duplicate candidates, candidate detail, and merge preview;
- CSV import preview;
- backup and restore confirmation;
- graph semantic nodes and relationship list;
- HTTPS, Apple Books fallback, and local-file reading entries.

The following named checks therefore also remain unresolved: the stable spoken
name of the Command-F `NSSearchField`; search/filter/status compression and
operability at 520×360; non-color graph center/selection/relation/error
semantics; and completion of all flows with Reduce Motion enabled. There is no
manual record of spoken labels, values, states, actions, focus order, lost
focus, truncation, overlap, low contrast, or color-only meaning.

This is an environment blocker for the requested manual acceptance evidence,
not evidence of either a product pass or product failure. A reviewer with
direct control of an unlocked test Mac must execute the checklist above using
only fixed fictional data before stable-release acceptance.

### Other manual checks not represented by automation

No physical pointer review, macOS 14 runtime pass, release-signed archive
inspection, notarization, Gatekeeper assessment, or screenshot review was
performed in this task. These remain explicit release gates.

## Known release risks

- The bundle identifier is still `com.example.BookAtlas`, marketing version is
  still 0.1.0, and Release is ad-hoc signed for local verification.
- The license holder/year and private security-reporting channel are not yet
  configured.
- Verification is on one Apple M2 MacBook Air with 24 GB memory and macOS
  26.5.2; the declared macOS 14 minimum has not been exercised here.
- Debug XCUIAutomation produced existing-library launch, page-load, and
  scrolling/hitch metrics. A Release Instruments run using the same
  pre-generated-library protocol could not be authorized through the current
  execution surface after its unmeasured preparation step; therefore no
  Release launch or scrolling number is reported in this closure. Earlier
  launch numbers that included in-process test-data generation are explicitly
  superseded and are not treated as an existing-library launch baseline.
- Backups are unencrypted, recovery copies have no automatic retention policy,
  Possible duplicate review is capped without pagination, and external
  application behavior remains outside Book Atlas's control.
