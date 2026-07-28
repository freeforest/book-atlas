# Milestone 3 — data hygiene

## Goal

Provide explainable, user-reviewed duplicate handling without automatic destructive decisions.

## Stage

- Prompt 6: implementation and closure evidence complete; independent acceptance review pending — explainable duplicate candidates, persistent ignored-pair semantics, and user-reviewed transactional merging.

Prompt 5 belongs to Milestone 2 and passed independent acceptance before Prompt 6 work began.

## Gates

- Duplicate signals are explainable; automatic destructive merging is prohibited.
- Merge preserves required metadata and relationships or reports conflicts.
- Candidate review, ignore behavior, merge transactions, rollback, and any schema migration are tested with fixed fictional data.

## Implementation record

- Schema version 4 stores indexed derived keys/tokens and minimal ignored candidate pairs, with transactional backfill and idempotent migration coverage.
- ISBN-10/13 checksum validation, conservative title/author normalization, confidence rules, reasons, integer weights, and uncertainty are separated from persistence and UI.
- Exact/Strong candidates intercept create-save; review supports cancellation, viewing the existing record, three keep-separate meanings, and merge preview.
- Merge retains the selected target identity, exposes scalar conflicts, unions/deduplicates every existing association table, redirects safe relations, rejects self/lossy conflicts, and deletes the source last in one transaction.
- The implementation adds no dependency, network path, entitlement, import flow, graph UI, AI model, or automatic destructive action.
