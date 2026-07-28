# ADR-0007: Deterministic duplicate resolution

- Status: Accepted
- Date: 2026-07-28
- Owners: Project maintainers

## Context

Book Atlas needs duplicate checks during manual creation and later data-cleanup workflows without sending private bibliography data elsewhere or making destructive identity decisions automatically. ISBN alone is incomplete, free-form author strings do not provide authority control, and similar titles can represent editions, translations, series installments, or unrelated works. A merge also touches every existing book relationship and must not leave partial state.

## Decision

Use local deterministic normalization and centralized transparent rules. A matching valid ISBN is `exact`; equal normalized title and ordered author text without explicit ISBN/original-title conflict is `strong`; token, original-title, publisher, year, edition, and conflicting-ISBN evidence contributes to a documented integer score for `possible`. Different valid ISBN values never produce `exact` or `strong`.

Candidate lookup first uses schema-version-4 derived-key and title-token indexes. It does not compare every pair in the library and never relies on SQLite's undeclared row order. Exact ISBN, normalized title/author, and original-title lookups have no count cap and use `book_id ASC`. Possible token lookup uses `(token, book_id)` indexes, deterministic `book_id ASC`, and a 250-row review cap; it requests one extra row and exposes truncation through the service and review state. User decisions to keep records separate store only the selected canonical pair of book UUIDs, a disposition, and a timestamp. Changes to identity-bearing fields invalidate affected decisions.

Merging always retains the chosen target UUID, requires a field-level preview and explicit confirmation, shows concrete association outcomes, unions existing associations, redirects or deduplicates relations, rejects self-relations and lossy note conflicts, and deletes the source only after every migration succeeds in one SQLite transaction. Equal links with an empty target label can fill that label; equal labels deduplicate; different nonempty labels block the merge before mutation.

## Alternatives considered

- **Automatic merge on exact ISBN:** rejected because one ISBN does not express the user's edition/record intent and deletion is destructive.
- **Black-box similarity or network metadata lookup:** rejected because results would be harder to explain and would violate the offline/privacy boundary.
- **Pairwise whole-library comparison:** rejected because creation-time work would grow quadratically and ignore existing indexes.
- **A new work/edition authority model:** deferred because Prompt 6 cannot reliably infer that structure from free-form metadata.

## Consequences

### Positive

- Every candidate exposes rule codes, readable evidence, confidence, score, and uncertainty.
- Ignore and merge behavior is local, persistent, reviewable, and transactionally testable.
- Confirmed merges project as one retained book identity for future graph data.

### Negative or tradeoffs

- Deterministic heuristics have known false-positive and false-negative boundaries.
- Author order is intentionally significant, and series/translation understanding remains limited.
- Identity edits can make a previous ignore decision stale, so the pair is deliberately reconsidered.
- A Possible token lookup can disclose that more than 250 ordered raw index hits exist; this bounds interactive work but means later Possible hits are not evaluated in that review pass.

## Privacy and security

No network, entitlement, dependency, file access, telemetry, or AI service is added. Derived keys, tokens, ignore pairs, and merge changes remain in the local database. Tests use only fixed fictional data. Errors shown by the UI do not include titles, notes, paths, SQL, or relationship payloads.

## Validation

Validation is provided by isolated normalization and rule tests, schema-version-4 migration/backfill/idempotence/failure tests, pair-specific multi-candidate ignore tests, deterministic lookups beyond 250 Exact/Strong matches, a 10,000-book indexed candidate baseline, link-label conflict and rollback tests, full application unit tests, and macOS UI coverage for candidate review, draft-preserving existing-record viewing, concrete accessible association preview, cancellation, empty state, and explicit confirmation. Exact commands and the verified environment are recorded in `docs/DEVELOPMENT.md`.
