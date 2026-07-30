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
independent review. The latest local closure evidence is successful Debug and
hardened local Release builds, 174/174 unit/integration/migration/security/
performance tests, and 33/33 actually executed UI tests. Three-run
fixed-fictional evidence now covers app launch, database open, first-page load,
list scrolling/hitches, tag usage counts, and Schema 1–4→5 migration. Manual
VoiceOver, Accessibility Inspector, appearance/accent/small-window, and Reduce
Motion acceptance remains blocked by the current task execution environment
and is not represented as passed. No stable release, tag, distribution
signature, notarization, or upload has occurred.

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
