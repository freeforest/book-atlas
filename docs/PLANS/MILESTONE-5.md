# Milestone 5 — release quality

## Goal

Verify release quality and prepare an accurate, privacy-conscious open-source repository.

## Stage

- Prompt 10: regression and performance checks, accessibility review, privacy/security audit, packaging documentation, license/dependency inventory, contributor guidance, and known limitations.

Prompt 10 passed independent acceptance at documentation baseline
`ec0b04f1c004ef5c897d3269e335c92034d6021e`; its verified code baseline is
`4cc20b8c88cb674a4f9a52d3e8de70c295169281`. Prompts 0–10 are complete and no
Prompt 11 begins automatically. The valid final evidence is 3/3 targeted
historical graph regressions, 41/41 full
UI tests after XCUIAutomation initialization, 200/200 full non-UI tests, and
successful Debug and local Hardened Runtime Release builds, with zero failed
or skipped tests. A zero-test Xcode/CoreSimulator/test-service attempt and a
199-pass run with one benchmark `signal term` remain non-passing
runner/infrastructure history.

The graph repair is limited to changing the horizontal threshold from 760 to
700, adding a 120-point node-list minimum height, and establishing a reliable
fixed-fictional center/detail/button test precondition with scoped diagnostics.
No graph semantics, Schema, migration, or persistence changed. Current-build
Light/Dark, default-window graph, and exact 520×360 manual checks passed.
Inspector formal audits returned zero warnings separately for the unselected
Library state and selected fixed-fictional A101 detail state, without making a
whole-application permanent-zero claim. Prior purple-accent, Reduce Motion,
complete pointer-free keyboard, and VoiceOver evidence is retained as a prior
human gate, not a complete `4cc20b8c…` rerun. At that Prompt 10 baseline, the
native file path remained `PASS WITH LIMITATION` because an actual
`NSOpenPanel` was not displayed.

This acceptance closes Milestone 5 development. It did not publish GitHub,
push, create a tag or GitHub Release, upload source or an `.app`, or perform
Apple binary distribution. Real external-system behavior and the state-specific
Inspector/native-panel limitations remained as documented evidence boundaries
at that baseline. The later V1.0.0 check below supersedes only the narrow
real-panel display/cancel limitation.

The confirmed follow-on strategy is GitHub source code only. It excludes Mac
App Store, Apple Developer membership, App Store Connect/Review, Developer ID,
distribution certificates and provisioning profiles, notarization, stapling,
Gatekeeper binary acceptance, and precompiled `.app` downloads. These are not
pending gates for the current source-only strategy. Local ad-hoc builds, App
Sandbox, Hardened Runtime, and entitlement checks remain local evidence.

The source-publication preparation task aligned V1.0.0 to macOS 26.0, version
1.0.0/build 1, and bundle identifier `io.github.freeforest.BookAtlas`. It
remains separate from Milestone 5 and is not Prompt 11. On clean committed
baseline `71ec000c…`, final UI re-parsed as 41/41 passed after XCUIAutomation
initialized; fresh Debug/Release builds succeeded; fresh complete non-UI
re-parsed as 200/200 passed; actual product metadata and entitlements matched
the source-only policy; the real `NSOpenPanel` appeared and was safely
cancelled against a two-book fixed-fictional in-memory library; and final
privacy/artifact scans found no private data or release product. All valid test
results had zero failures and skips. This local evidence now awaits independent
review and a later clean post-commit verification.

In a separate follow-on publication task on 2026-08-10, the confirmed
repository `freeforest/book-atlas` became Public after complete history and
online-surface checks. Public access was independently confirmed without an
administrator login. GitHub Private Vulnerability Reporting is enabled and the
public Security page exposes **Report a vulnerability**; the administrator's
**New draft security advisory** control is the role-specific maintainer view.
This follow-on work is not Prompt 11 and does not rewrite the Prompt 10 state
above. The intended first tag and GitHub Release remain `v1.0.0` and
`Book Atlas v1.0.0`, source-only, with no uploaded application binary. A
separate private conduct-reporting channel remains unconfigured and is not
replaced by PVR. Remaining Git/GitHub writes are user-operated.

Earlier closure history is retained below. One earlier local closure had
successful Debug and hardened local Release builds, 197/197
unit/integration/migration/security/performance tests, and 37/37 UI
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
surface. At that stage, the required human VoiceOver/Accessibility Inspector
and appearance/accent/small-window/Reduce Motion audit could not be controlled
from the task execution surface and remained unverified.

The fifth closure also makes the precise missing/excluded selection issue win
over generic empty/no-results placeholders when a bounded query returns zero
rows. The excluded state includes an accessible clear-query action, and both
paths have Store plus real XCUI regressions without changing the 200-row page
or 1,000-row repository hard limit. A second manual-audit attempt on
2026-08-03 initialized the supported Computer Use runtime, enumerated running
applications, and started only a fixed-fictional in-memory Debug app, but the
native pipe closed before returning the first Book Atlas desktop or AX tree;
that attempt kept all human gates blocked rather than inferring them from
automation.

The sixth closure removes two XCUI assumptions without changing production
search or selection behavior: the combined search/filter test explicitly
selects and verifies the fixed A101 UUID before excluding it, and the shared
input helper requires post-click keyboard focus after app activation (with one
bounded reactivate/reclick fallback). Its final no-retry evidence is 10/10
relaunch-enabled search repetitions, 2/2 targeted zero-result cases, 190/190
non-UI tests, and a uniquely sealed full UI result parsed as 37/37 with zero
failures or skips. One earlier full attempt was 36/37 and two helper revisions
failed on non-authoritative SwiftUI `TextEditor` AX attributes; those attempts
remain documented in the quality audit. At that stage, manual gates and
independent review remained outstanding.

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
`objectWillChange` regressions cover all four boundaries. That closure's complete
non-UI suite passed 197/197, and the complete 37/37 UI activity tree still
contains zero SwiftUI view-update publication warnings. The six Xcode internal
QoS diagnostics remain separately classified.

A subsequent partial Light-mode human check found one blocking editor issue:
invalid Save left its only message below the current Form viewport and supplied
no understandable repeated-focus feedback. That code closure added a
fixed visible summary, inline field errors, deterministic invalid-field focus,
and an injectable privacy-safe accessibility announcement for every invalid
submission. Its complete non-UI result is 200/200 and its direct fictional
author/no-title mouse path passed 3/3 without retries. These automated results
and the sealed complete UI suite passed 40/40 without failure or skip. Those
automated results did not themselves close the manual gate: at that stage the
corrected Light flow, Dark, accent, window-size, Reduce Motion, complete
keyboard, VoiceOver, and Inspector paths still required human execution. The
later human gate and current-build supplements are summarized above; the final
evidence was subsequently accepted at `ec0b04f…`.

## Accepted Prompt 10 gates

- Build and full test suite pass on the documented supported toolchain.
- Privacy scan, entitlement review, migration/backup recovery checks, and fictional-data audit pass.
- Performance results state hardware, dataset, method, and limitations.
- Public documentation does not expose personal contact details, data, paths, signing material, or unsupported capability claims.

Independent acceptance confirms these Prompt 10 gates at the baselines above.
It does not replace the separate GitHub source-publication checklist.

## Deliverables

- full Debug/Release and regression evidence, including Schema 1→5;
- repeatable fixed-fictional 1k/5k/10k measurements with environment and noise
  disclosure;
- automated light/dark, small-window, keyboard, accessibility-tree, bounded
  graph, and main-actor responsiveness checks, plus accurate completed,
  state-limited, prior-build, and still-unverified manual evidence boundaries;
- privacy, security, logging, entitlement, dependency/license, and repository
  artifact audits;
- license placeholder, contribution/conduct/security entry points, issue and
  pull-request templates, fictional fixture/generator, known limitations, and
  a GitHub source-publication checklist.

## GitHub source-publication gates

- repository identity `freeforest/book-atlas`, version 1.0.0, tag `v1.0.0`,
  Release title `Book Atlas v1.0.0`, and source-only scope are confirmed;
- `LICENSE` is resolved to the user-authorized `2026 FreeForest` line;
- the repository became Public on 2026-08-10 after a clean committed-baseline,
  complete reachable-history, and online-surface review; two historical
  non-GitHub-noreply commit email identities were explicitly authorized by the
  user without publishing their values in the documentation;
- GitHub Private Vulnerability Reporting is enabled and independently verified
  from the public non-administrator **Report a vulnerability** entry; public
  Issues are not a private vulnerability channel;
- the project/docs are aligned to macOS 26-only; fresh Debug/Release, complete
  non-UI, complete UI with XCUIAutomation initialized, fixed-fictional data,
  actual-product inspection, real native-panel display/cancel verification,
  and repository/privacy scans are recorded for `71ec000c…`; the clean
  post-commit `bea61ca…` baseline was verified before Public conversion;
- README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, Issue/PR templates,
  fictional samples/generator, roadmap, known limitations, and final
  bundle/version metadata have been reviewed; the separate private
  conduct-reporting channel remains an explicit publication gate;
- tracked-file scans found no database, WAL/SHM, backup, bookmark, DerivedData,
  `.xcresult`, certificate, key, signing material, or private path;
- explicit user authorization covered the completed Public/PVR operations;
  push of this status update, tag, GitHub Release, upload, and announcement
  remain separate user actions.

Apple Developer, App Store, Developer ID, distribution signing, notarization,
stapling, and Gatekeeper binary distribution are not applicable to the current
source-only plan. If a downloadable precompiled `.app` is considered later,
those questions must be reopened in a separate authorized release task along
with integrity, installation, and update strategy.
