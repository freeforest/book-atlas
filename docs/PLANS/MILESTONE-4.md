# Milestone 4 — portability and exploration

## Goal

Give the user control of data portability, add bounded relationship exploration, and adopt only verified external-link behavior.

## Stages

- Prompt 7: second NO-GO closure implemented and pending independent re-review — bounded staged import, explicit export, exact versioned application-schema-validated backup, backend-authoritative cancellation, and interruption-safe restore.
- Prompt 8: local relationship graph projection, native rendering, bounded interaction, and accessible alternatives.
- Prompt 9: Apple Books and external-link behavior supported by Prompt 1 evidence.

## Gates

- Untrusted files are validated before transactions touch the live store.
- Restore cannot silently overwrite the live library and failures preserve the prior state.
- The graph is not a second source of truth and has practical size limits.
- External links validate schemes, require user action, and degrade visibly when unsupported.

## Prompt 7 implementation record

- `bookatlas-csv/1` supports streaming UTF-8/BOM parsing into bounded disk staging, user mapping generations, a 20-row/80-issue presentation bound, existing-library and same-batch Prompt 6 duplicate reuse, organization forecasts/deduplication, one-transaction confirmed import, and a post-execution redacted report.
- `bookatlas-markdown/1` and CSV export use stable documented escaping; CSV protects six formula prefixes and remains round-trippable.
- `.bookatlasbackup` version 1 uses SQLite online backup, a path-free manifest, single-file journal mode, physical plus exact versioned table/index/trigger/view verification, a 4 GiB limit, capacity/error checks, non-overwrite output, restore preview, a retained recovery copy, staged migration, backend-authoritative atomic cancellation boundaries, a path-free process-interruption marker, startup recovery, connection close/reopen, and rollback.
- Prompt 8 and Prompt 9 remain unimplemented.
