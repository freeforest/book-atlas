# Prompt 10 quality audit

This document records implementation evidence for independent review. It does
not state that Prompt 10 passed, that a stable version was released, or that
release signing/notarization occurred.

## Automated quality coverage

- The complete unit/integration suite covers CRUD, query composition,
  organization, duplicate decisions and transactional merge rollback,
  portability, strict backup/restore and interruption recovery, graph
  invalidation, HTTPS/bookmark safety, and external-reading state isolation.
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

## Manual checks not represented by automation

No complete human VoiceOver traversal, Accessibility Inspector audit, physical
pointer review, macOS 14 runtime pass, release-signed archive inspection,
notarization, Gatekeeper assessment, or screenshot review was performed in
this implementation task. These remain explicit release gates. Automated
accessibility identifiers and XCUI keyboard checks are not presented as a
substitute for those audits.

## Known release risks

- The bundle identifier is still `com.example.BookAtlas`, marketing version is
  still 0.1.0, and Release is ad-hoc signed for local verification.
- The license holder/year and private security-reporting channel are not yet
  configured.
- Verification is on one Apple M2 MacBook Air with 24 GB memory and macOS
  26.5.2; the declared macOS 14 minimum has not been exercised here.
- Backups are unencrypted, recovery copies have no automatic retention policy,
  Possible duplicate review is capped without pagination, and external
  application behavior remains outside Book Atlas's control.
