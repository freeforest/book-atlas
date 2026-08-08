# Architecture decision records

Use an ADR for a durable choice that constrains implementation, data compatibility, privacy, security, deployment targets, dependencies, or system integrations.

## Process

1. Copy `TEMPLATE.md` to the next zero-padded number and a short kebab-case title.
2. Describe the context and real evidence, including experiments or official documentation.
3. Mark the status `Proposed`.
4. Review alternatives, consequences, privacy impact, and validation.
5. Change the status to `Accepted` only when the decision is approved. Later changes supersede rather than silently rewrite accepted history.

Keep ADRs concise. An ADR records a decision; implementation details belong in code and plans.

## Status values

- `Proposed`
- `Accepted`
- `Rejected`
- `Superseded by ADR-NNNN`

## Index

- [ADR-0001: Local-first and offline by default](0001-local-first-offline-default.md) — Accepted
- [ADR-0002: Direct SQLite persistence](0002-direct-sqlite-persistence.md) — Accepted
- [ADR-0003: macOS 14 deployment target](0003-macos-14-deployment-target.md) — Superseded by ADR-0009
- [ADR-0004: Bounded Canvas graph](0004-bounded-canvas-graph.md) — Accepted; Prompt 8 independently accepted at baseline `6ae90dd50ee71f574e0b4cc1ffccfd7e4c2e71aa`
- [ADR-0005: External links and Apple Books](0005-external-links-and-apple-books.md) — Accepted; Prompt 9 production implementation independently accepted at baseline `1f7a35cda11fcafd23aacab0cb5c72e811327d0b`
- [ADR-0006: Sandboxed file access](0006-sandboxed-file-access.md) — Accepted; Prompt 7 write destinations are extended by ADR-0008 and Prompt 9 bookmark implementation independently accepted at baseline `1f7a35cda11fcafd23aacab0cb5c72e811327d0b`
- [ADR-0007: Deterministic duplicate resolution](0007-deterministic-duplicate-resolution.md) — Accepted
- [ADR-0008: Versioned portability formats and safe database snapshots](0008-versioned-portability-formats.md) — Accepted
- [ADR-0009: macOS 26-only source release](0009-macos-26-only-source-release.md) — Accepted
