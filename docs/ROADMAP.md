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

- **Prompt 4:** book CRUD and the foundational macOS library interface.

Exit condition: a user can safely create, inspect, edit, and delete fictional test records with validation and accessibility basics.

### Milestone 3 — organization and data hygiene

- **Prompt 5:** search, filtering, sorting, tags, lists, and sources.
- **Prompt 6:** explainable duplicate detection and user-confirmed transactional merging.

Exit condition: a growing library can be organized and cleaned without automatic destructive decisions.

### Milestone 4 — portability and exploration

- **Prompt 7:** import, export, backup, and restore.
- **Prompt 8:** bounded local relationship graph.
- **Prompt 9:** only the Apple Books and external-link behaviors proven by experiments.

Exit condition: data is portable and recoverable, relationship exploration does not compromise the core model, and integrations degrade safely.

### Milestone 5 — release quality and open-source readiness

- **Prompt 10:** performance and accessibility checks, privacy/security audit, release documentation, and open-source preparation.

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
