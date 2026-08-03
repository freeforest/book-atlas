# Roadmap

The roadmap is sequential. Complete a prompt's acceptance criteria, real validation, documentation update, and risk review before beginning the next prompt. Do not combine stages. A normal Git commit after each accepted stage is recommended but never automatic.

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

- **Prompt 10:** performance and accessibility checks, privacy/security audit, release documentation, and open-source preparation.

Prompt 10 quality and open-source preparation is implemented and awaits
independent review and the documented human gates. The latest local closure
evidence is successful Debug and hardened local Release builds, 197/197
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
measured desktop trace could not be authorized from this execution surface.
Manual
VoiceOver, Accessibility Inspector, appearance/accent/small-window, and Reduce
Motion acceptance remains blocked by the current task execution environment
and is not represented as passed. No stable release, tag, distribution
signature, notarization, or upload has occurred.

The sixth closure's final-code XCUI evidence uses an explicit fixed-UUID
selection precondition and foreground/keyboard-focus arbitration for every
shared text replacement. A no-retry relaunch run passed the search path 10/10,
both zero-result paths passed 2/2, and the unique sealed full result bundle
parsed as 37/37 with no failures or skips. Earlier 36/37 and helper-assertion
failures are retained in the quality audit; this evidence does not replace the
still-blocked human gates or constitute acceptance.

The seventh closure gives `List(selection:)` local SwiftUI ownership and
applies only changed, latest-generation UUID side effects to the Store after
the List update. Search and keyboard-selection paths each passed 10/10
no-retry relaunch repetitions; parsed activities for those runs and the full
37/37 suite contain no SwiftUI view-update publication warning. Xcode internal
QoS diagnostics remain separately recorded. The supported Computer Use
runtime initialized and enumerated running applications, but its native pipe
closed before the first fixed-fictional Book Atlas app-state/AX-tree response;
there is still no manual visual or accessibility result.

The eighth closure makes Store selection fully idempotent at the remaining
focus boundary: nil focus is not rewritten to nil, matching page-out focus is
retained, and only an actual non-nil identity mismatch is cleared. Four direct
publication regressions passed within the 197/197 complete non-UI suite; the
latest 37/37 UI activity tree continues to contain zero SwiftUI view-update
publication warnings. This does not change the blocked human gates or Prompt
10 acceptance state.

A later partial Light-mode human check found that editor validation existed
only below the visible part of the long Form and gave no understandable
feedback when Save failed. The current minimal closure provides a fixed visible
summary, field-level explanations, required-field focus, and a repeatable,
privacy-safe accessibility announcement behind an injectable adapter. The
complete non-UI suite now passes 200/200 and the direct fixed-fictional
author/no-title mouse path passed 3/3 without retry. The original manual FAIL
and the sealed full UI suite passed 40/40 without failure or skip. The original
manual FAIL is preserved: the corrected Light path still requires human recheck, and Dark,
accent, both window sizes, Reduce Motion, complete keyboard, VoiceOver, and
Accessibility Inspector remain unverified. Prompt 10 is still awaiting its
manual gates and independent review.

Exit condition: the documented quality gates pass with fictional data and all limitations, licenses, privacy boundaries, and remaining risks are public and accurate.

## Required execution order

`Prompt 0 → Prompt 1 → Prompt 2 → Prompt 3 → Prompt 4 → Prompt 5 → Prompt 6 → Prompt 7 → Prompt 8 → Prompt 9 → Prompt 10`

## Cross-cutting gates

At every stage:

1. inspect Git status and preserve user work;
2. read the active plan and relevant decisions;
3. keep examples fictional and the application offline by default;
4. run the real build and relevant tests once those commands exist;
5. update documentation and state unverified behavior and risk;
6. stop on conflicts, private data, destructive-cleanup needs, or assumptions invalidated by repository facts.
