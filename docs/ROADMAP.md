# Roadmap

The development roadmap was sequential and is now complete through Prompt 10.
No Prompt 11 starts automatically. Subsequent GitHub source-publication
preparation is an operational/publication task, not a new product-development
stage. Git commits and all external publication actions remain explicit user
decisions, never automatic.

## Milestones

### Milestone 0 — foundation and technical confidence

- **Prompt 0:** repository audit, rules, privacy boundaries, documentation, ADR mechanism, and plans.
- **Prompt 1:** completed isolated technical experiments for persistence, migration, macOS UI, graph rendering, external links, file authorization, and build/test commands; see the Milestone 0 plan and ADR-0002 through ADR-0006.
- **Prompt 2:** completed minimal runnable sandboxed macOS application skeleton with native navigation, placeholders, unit tests, and UI smoke coverage; see the Milestone 0 plan.

Exit condition: the toolchain and deployment target are documented, key technology choices have evidence-backed ADRs, and a minimal app builds and tests reproducibly.

### Milestone 1 — dependable library core

- **Prompt 3:** domain model, one versioned local persistence implementation, migrations, repositories/use cases, and tests.

Exit condition: fictional library data can be stored and queried through tested domain boundaries without a production UI.

### Milestone 2 — usable catalog

- **Prompt 4:** completed book CRUD and the foundational macOS library interface.
- **Prompt 5:** completed and independently accepted search, filtering, sorting, tags, lists, sources, and book memberships.

Exit condition: a user can safely manage, search, filter, sort, and organize fictional test records with validation, deterministic query behavior, and accessibility basics.

### Milestone 3 — data hygiene

- **Prompt 6:** independently accepted explainable duplicate detection and user-confirmed transactional merging.

Exit condition: duplicate candidates can be explained, reviewed, ignored, or merged without automatic destructive decisions.

### Milestone 4 — portability and exploration

- **Prompt 7:** independently accepted at baseline `b27318c741fee5b4a66e5ad99cb979177285fef5` with bounded staged import, export, exact versioned application-schema-validated backup, backend-authoritative restore cancellation, and interruption-safe restore.
- **Prompt 8:** independently accepted after its second review at baseline `6ae90dd50ee71f574e0b4cc1ffccfd7e4c2e71aa`; the independent Debug build, 146/146 unit/integration/performance tests, and 22/22 UI tests passed without failures or skips.
- **Prompt 9:** independently accepted at baseline `1f7a35cda11fcafd23aacab0cb5c72e811327d0b`; the independent Debug build, 171/171 unit/integration/migration/security/performance tests, and 26/26 UI tests passed without failures or skips.

Exit condition: data is portable and recoverable, relationship exploration does not compromise the core model, and integrations degrade safely.

### Milestone 5 — release quality and open-source readiness

- **Prompt 10:** completed and independently accepted performance and accessibility checks, privacy/security audit, release documentation, and open-source preparation.

Prompt 10 passed independent acceptance at documentation baseline
`ec0b04f1c004ef5c897d3269e335c92034d6021e`; its verified code baseline is
`4cc20b8c88cb674a4f9a52d3e8de70c295169281`. Prompts 0–10 are complete.
The three formerly failing graph UI cases passed 3/3, the complete UI suite
initialized XCUIAutomation and passed 41/41, the complete non-UI suite passed
200/200, and Debug/Release builds both succeeded, with zero failed or skipped
tests in the valid final bundles. A zero-test service-connection attempt and a
199-pass plus benchmark `signal term` run remain infrastructure-failure
history and are not counted as passes.

The graph closure lowers only the horizontal-layout threshold from 760 to 700,
adds a 120-point node-list minimum height, and strengthens the fixed-fictional
center/detail/button test precondition and diagnostics. It does not change
graph data, relationships, weights, revision, Schema, migrations, or
persistence. Current-build Light/Dark and graph review passed; a real AXWindow
measurement and operation pass closed the exact 520×360 check. Accessibility
Inspector formal audits returned zero warnings separately for the unselected
Library state and selected fixed-fictional A101 detail state, without claiming
permanent whole-application zero warnings. Prior purple-accent, Reduce Motion,
complete pointer-free keyboard, and VoiceOver evidence was retained and not
misrepresented as fully rerun on `4cc20b8c…`. At that Prompt 10 baseline, the
native file action remained `PASS WITH LIMITATION` because no actual
`NSOpenPanel` appeared.

The accepted evidence preserves the state boundaries above and does not claim
whole-application permanent-zero Inspector results or a passed real
`NSOpenPanel`. Earlier accent, Reduce Motion, pointer-free keyboard, and
VoiceOver evidence was not fully rerun on `4cc20b8c…`. The later V1.0.0
fixed-fictional system-adapter check displayed and safely cancelled the real
panel without browsing, selecting, or reading a file; that result does not
rewrite the historical Prompt 10 limitation or validate long-lived bookmarks.

Book Atlas will be published, if separately authorized, as GitHub source code
only. The plan excludes Mac App Store, Apple Developer membership, App Store
Connect/Review, Developer ID, distribution certificates/profiles, notarization,
stapling, Gatekeeper acceptance for a downloadable binary, and precompiled
`.app` distribution. These Apple binary-distribution items are not outstanding
gates for the current plan. Local ad-hoc Debug/Release, App Sandbox, Hardened
Runtime, and entitlement inspection remain build evidence only.

V1.0.0 local source-publication preparation evidence is collected. The production
project and all three targets declare macOS 26.0; the app metadata is version
1.0.0, build 1, bundle identifier `io.github.freeforest.BookAtlas`. The
confirmed repository `freeforest/book-atlas` became Public on 2026-08-10 after
history and online-surface checks, the MIT copyright is `2026 FreeForest`, and
the intended first tag/Release remain `v1.0.0` and `Book Atlas v1.0.0`. No
macOS 14/15 compatibility promise or matrix is made.

On clean committed baseline `71ec000c…`, the final UI result re-parsed as 41/41
passed after XCUIAutomation initialized; fresh Debug/Release builds succeeded;
the fresh complete non-UI result re-parsed as 200/200 passed; actual products
matched version 1.0.0/build 1, `io.github.freeforest.BookAtlas`, and minimum
macOS 26.0; the real `NSOpenPanel` display/cancel check passed; and final
repository/privacy scans found no private data or release artifact. All valid
test results had zero failures and skips. Public access was confirmed from both
logged-in and independent public non-administrator views. GitHub Private
Vulnerability Reporting is enabled, and the public Security page exposes
**Report a vulnerability**; the administrator's **New draft security
advisory** is a role-specific view. A separate private conduct-reporting
channel is now configured, with [`CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md)
as the authoritative contact source; PVR remains limited to security
vulnerabilities. The Public/PVR status documents have been user-committed and
pushed, and the conduct-channel documentation was likewise committed and
pushed at `fb0c073fc9fad7a0846d78bc560c213ff5fcc8df`; that gate is closed.
The release materials are finalized for the confirmed 2026-08-10 date. The
final independent pre-tag review passed on clean baseline
`0009ec83cc192d4b2f0e67a4cc7efd4e3e25bc81`, with no P0, P1, or P2 finding.
Remaining release operations require explicit repository-owner authorization;
authentication challenges remain owner-only. No tag, GitHub Release,
application upload, or formal V1.0.0 announcement has occurred, and no source
attachment has been uploaded.

Earlier Prompt 10 closure history remains relevant. One earlier local closure
had successful Debug and hardened local Release builds, 197/197
unit/integration/migration/security/performance tests, and 37/37 actually
executed UI tests. The ordinary library
now exposes exact result counts and bounded 200-row pagination rather than
silently stopping at 500. Explicit UUID focus from the graph and mutation
refreshes use a bounded first-page-plus-one lookup, preserve the requested
identity beyond page one, and never substitute the first row when a target is
missing or excluded. The precise missing/excluded state remains visible when
the ordinary result page has zero rows, and an excluded target has an
accessible query-reset recovery action instead of a generic no-results page.
Three-run fixed-fictional evidence covers reopening
pre-generated Schema 5 libraries, database open, first/next-page load,
disclosed multi-page list scrolling/hitches, tag usage counts, and Schema
1–4→5 migration; data generation is outside the measured launch window.
Release Instruments existing-library launch remains unverified because the
measured desktop trace could not be authorized from that execution surface.
At that stage, manual VoiceOver, Accessibility Inspector,
appearance/accent/small-window, and Reduce Motion evidence was blocked and was
not represented as passed. No stable release, tag, distribution signature,
notarization, or upload occurred.

The sixth closure's final-code XCUI evidence uses an explicit fixed-UUID
selection precondition and foreground/keyboard-focus arbitration for every
shared text replacement. A no-retry relaunch run passed the search path 10/10,
both zero-result paths passed 2/2, and the unique sealed full result bundle
parsed as 37/37 with no failures or skips. Earlier 36/37 and helper-assertion
failures are retained in the quality audit; that evidence did not replace the
then-blocked human gates or constitute acceptance.

The seventh closure gave `List(selection:)` local SwiftUI ownership and
applies only changed, latest-generation UUID side effects to the Store after
the List update. Search and keyboard-selection paths each passed 10/10
no-retry relaunch repetitions; parsed activities for those runs and the full
37/37 suite contain no SwiftUI view-update publication warning. Xcode internal
QoS diagnostics remain separately recorded. At that stage the supported Computer Use
runtime initialized and enumerated running applications, but its native pipe
closed before the first fixed-fictional Book Atlas app-state/AX-tree response;
that attempt produced no manual visual or accessibility result.

The eighth closure made Store selection fully idempotent at the remaining
focus boundary: nil focus is not rewritten to nil, matching page-out focus is
retained, and only an actual non-nil identity mismatch is cleared. Four direct
publication regressions passed within the 197/197 complete non-UI suite; that
closure's 37/37 UI activity tree contained zero SwiftUI view-update
publication warnings. That automated closure did not by itself change the
then-blocked human gates or Prompt 10 acceptance state; the later independent
review accepted the final evidence at `ec0b04f…`.

A later partial Light-mode human check found that editor validation existed
only below the visible part of the long Form and gave no understandable
feedback when Save failed. That minimal closure provided a fixed visible
summary, field-level explanations, required-field focus, and a repeatable,
privacy-safe accessibility announcement behind an injectable adapter. The
complete non-UI suite passed 200/200 and the direct fixed-fictional
author/no-title mouse path passed 3/3 without retry. The original manual FAIL
remained recorded, and the sealed full UI suite passed 40/40 without failure
or skip. At that stage the corrected Light path, Dark,
accent, both window sizes, Reduce Motion, complete keyboard, VoiceOver, and
Accessibility Inspector still required human evidence; the later completed
gate and current-build supplements are summarized above. Prompt 10 subsequently
passed independent acceptance.

Exit condition: achieved by the accepted Prompt 10 evidence. GitHub source
publication remains a separate, user-authorized preparation and publication
workflow.

## Required execution order

Completed: `Prompt 0 → Prompt 1 → Prompt 2 → Prompt 3 → Prompt 4 → Prompt 5 → Prompt 6 → Prompt 7 → Prompt 8 → Prompt 9 → Prompt 10`

The source-release sequence through baseline `0009ec83…` has finalized the
2026-08-10 release materials and completed the final independent clean-baseline
review. The remaining tag and GitHub Release operations require explicit
repository-owner authorization, while authentication challenges remain
owner-only. This publication sequence is not Prompt 11 and does not by itself
mean that V1.0.0 has been formally released.

## Cross-cutting gates

At every stage:

1. inspect Git status and preserve user work;
2. read the active plan and relevant decisions;
3. keep examples fictional and the application offline by default;
4. run the real build and relevant tests once those commands exist;
5. update documentation and state unverified behavior and risk;
6. stop on conflicts, private data, destructive-cleanup needs, or assumptions invalidated by repository facts.
