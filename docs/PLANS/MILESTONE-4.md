# Milestone 4 — portability and exploration

## Goal

Give the user control of data portability, add bounded relationship exploration, and adopt only verified external-link behavior.

## Stages

- Prompt 7: independently accepted at baseline `b27318c741fee5b4a66e5ad99cb979177285fef5` — bounded staged import, explicit export, exact versioned application-schema-validated backup, backend-authoritative cancellation, and interruption-safe restore.
- Prompt 8: first independent review completed; Canvas-pan and graph-freshness closure fixes are implemented and awaiting independent re-review.
- Prompt 9: not started; Prompt 1 contains feasibility evidence only.

## Gates

- Untrusted files are validated before transactions touch the live store.
- Restore cannot silently overwrite the live library and failures preserve the prior state.
- The graph is not a second source of truth and has practical size limits.
- External links validate schemes, require user action, and degrade visibly when unsupported.

## Prompt 7 implementation record

- `bookatlas-csv/1` supports streaming UTF-8/BOM parsing into bounded disk staging, user mapping generations, a 20-row/80-issue presentation bound, existing-library and same-batch Prompt 6 duplicate reuse, organization forecasts/deduplication, one-transaction confirmed import, and a post-execution redacted report.
- `bookatlas-markdown/1` and CSV export use stable documented escaping; CSV protects six formula prefixes and remains round-trippable.
- `.bookatlasbackup` version 1 uses SQLite online backup, a path-free manifest, single-file journal mode, physical plus exact versioned table/index/trigger/view verification, a 4 GiB limit, capacity/error checks, non-overwrite output, restore preview, a retained recovery copy, staged migration, backend-authoritative atomic cancellation boundaries, a path-free process-interruption marker, startup recovery, connection close/reopen, and rollback.
- Prompt 7 passed its third independent review: Debug build succeeded, 114/114 unit and integration tests passed, and 17/17 UI tests passed, with no failures or skipped tests.
- Prompt 8 implements the five evidence families, deterministic one/two-layer projection, explicit default/hard limits, cancellable bounded layout, asynchronous Canvas interaction, keyboard/accessibility list, and fixed-fictional production/performance tests without a Schema change.
- Canvas interaction now fixes one drag mode per gesture and derives every pan update from the captured starting translation plus the gesture's cumulative translation. The catalog actor owns a monotonic in-process graph-content revision; book, organization, manual-relation, merge, import, and restore mutations advance it. `GraphStore` observes that revision, cancels invalid builds, prevents stale generations from publishing, rebuilds changed data on re-entry, and preserves view-local layout only when the revision is unchanged.
- Prompt 8 is awaiting independent re-review. Prompt 9 has not started.
