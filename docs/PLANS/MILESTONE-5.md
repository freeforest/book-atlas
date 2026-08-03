# Milestone 5 — release quality

## Goal

Verify release quality and prepare an accurate, privacy-conscious open-source repository.

## Stage

- Prompt 10: regression and performance checks, accessibility review, privacy/security audit, packaging documentation, license/dependency inventory, contributor guidance, and known limitations.

Prompt 10 implementation is complete and awaits independent review. It is not
a release, tag, signed distribution, notarization, upload, or acceptance.
Local closure evidence is successful Debug and hardened local Release builds,
197/197 unit/integration/migration/security/performance tests, and 37/37 UI
tests with XCUIAutomation initialized. The fixed-fictional performance record
now separates test-data preparation from three-run existing-library launch,
database open, 200-row first-page load, next-page load, disclosed multi-page
scrolling/hitch, tag-count, and Schema 1–4→5 migration measurements. The
ordinary list discloses exact result counts and appends bounded 200-row pages
through an accessible keyboard action; it no longer silently truncates at
500. Graph focus and create/edit/merge refreshes preserve an explicit UUID
beyond the first page with a bounded first-page-plus-one lookup; missing or
excluded targets clear selection instead of selecting an unrelated first
row. Release Instruments existing-library launch remains unverified because
the measured desktop trace could not be authorized from this execution
surface. The
required human VoiceOver/Accessibility Inspector and appearance/accent/
small-window/Reduce Motion audit could not be controlled from the current task
execution surface and remains an explicit unverified release gate.

The fifth closure also makes the precise missing/excluded selection issue win
over generic empty/no-results placeholders when a bounded query returns zero
rows. The excluded state includes an accessible clear-query action, and both
paths have Store plus real XCUI regressions without changing the 200-row page
or 1,000-row repository hard limit. A second manual-audit attempt on
2026-08-03 initialized the supported Computer Use runtime, enumerated running
applications, and started only a fixed-fictional in-memory Debug app, but the
native pipe closed before returning the first Book Atlas desktop or AX tree;
all human gates remain blocked rather than inferred from automation.

The sixth closure removes two XCUI assumptions without changing production
search or selection behavior: the combined search/filter test explicitly
selects and verifies the fixed A101 UUID before excluding it, and the shared
input helper requires post-click keyboard focus after app activation (with one
bounded reactivate/reclick fallback). Its final no-retry evidence is 10/10
relaunch-enabled search repetitions, 2/2 targeted zero-result cases, 190/190
non-UI tests, and a uniquely sealed full UI result parsed as 37/37 with zero
failures or skips. One earlier full attempt was 36/37 and two helper revisions
failed on non-authoritative SwiftUI `TextEditor` AX attributes; those attempts
remain documented in the quality audit. Manual gates and independent review
remain outstanding.

The seventh closure replaces the `List(selection:)` binding's synchronous
multi-property Store mutation with a local SwiftUI selection bridge. Store-to-
list synchronization is one-way and idempotent; list-to-Store changes carry a
monotonic generation and apply only the latest identity after the List update.
The Store itself emits no change for an already-selected UUID and preserves a
valid off-page focused book. No-retry relaunch runs passed both the search and
keyboard-selection cases 10/10. Parsed activities for all 20 repetitions and
the complete 37/37 UI bundle contain zero SwiftUI view-update publication
warnings. Six complete-suite tests still contain an independent Xcode internal
QoS diagnostic; it is recorded separately and is not represented as a product
finding. The final non-UI suite passed 193/193.

The eighth closure removes the last Store-side no-op publication. A nil
`focusedBook` is no longer assigned nil when an ordinary in-page UUID is
reselected; a matching page-out focus is preserved, while an actual non-nil
mismatch is still cleared for a different UUID or nil selection. Direct
`objectWillChange` regressions cover all four boundaries. The latest complete
non-UI suite passed 197/197, and the complete 37/37 UI activity tree still
contains zero SwiftUI view-update publication warnings. The six Xcode internal
QoS diagnostics remain separately classified.

A subsequent partial Light-mode human check found one blocking editor issue:
invalid Save left its only message below the current Form viewport and supplied
no understandable repeated-focus feedback. The current code closure adds a
fixed visible summary, inline field errors, deterministic invalid-field focus,
and an injectable privacy-safe accessibility announcement for every invalid
submission. Its complete non-UI result is 200/200 and its direct fictional
author/no-title mouse path passed 3/3 without retries. These automated results
and the sealed complete UI suite passed 40/40 without failure or skip. These
automated results do not close the manual gate: the corrected Light flow and all Dark, accent,
window-size, Reduce Motion, complete keyboard, VoiceOver, and Inspector paths
still require real human execution and independent review.

## Gates

- Build and full test suite pass on the documented supported toolchain.
- Privacy scan, entitlement review, migration/backup recovery checks, and fictional-data audit pass.
- Performance results state hardware, dataset, method, and limitations.
- Public documentation does not expose personal contact details, data, paths, signing material, or unsupported capability claims.

## Deliverables

- full Debug/Release and regression evidence, including Schema 1→5;
- repeatable fixed-fictional 1k/5k/10k measurements with environment and noise
  disclosure;
- automated light/dark, small-window, keyboard, accessibility-tree, bounded
  graph, and main-actor responsiveness checks, plus a detailed BLOCKED record
  for every manual accessibility/visual path not performed;
- privacy, security, logging, entitlement, dependency/license, and repository
  artifact audits;
- license placeholder, contribution/conduct/security entry points, issue and
  pull-request templates, fictional fixture/generator, known limitations, and
  a stable-release checklist.

## Release blockers that remain external to implementation

- replace the placeholder bundle identifier, version decision, license year
  and holder;
- configure a monitored non-personal private security-reporting channel;
- manually exercise Light/Dark, a non-default accent, 520×360 and normal
  windows, VoiceOver, Accessibility Inspector, Reduce Motion, the complete
  keyboard path, and macOS 14;
- run three authorized Release Instruments launches against each
  pre-generated 1k/5k/10k Schema 5 library and record the same exact-count
  verification used by Debug;
- configure release signing, archive verification, notarization, Gatekeeper
  validation, screenshots, release notes, tag, and upload.
