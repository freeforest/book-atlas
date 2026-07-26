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
- [ADR-0003: macOS 14 deployment target](0003-macos-14-deployment-target.md) — Accepted
- [ADR-0004: Bounded Canvas graph](0004-bounded-canvas-graph.md) — Accepted
- [ADR-0005: External links and Apple Books](0005-external-links-and-apple-books.md) — Accepted
- [ADR-0006: Sandboxed file access](0006-sandboxed-file-access.md) — Accepted
