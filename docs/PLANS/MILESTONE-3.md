# Milestone 3 — data hygiene

## Goal

Provide explainable, user-reviewed duplicate handling without automatic destructive decisions.

## Stage

- Prompt 6: independently accepted — explainable duplicate candidates, pair-specific ignored decisions, concrete association previews, and user-reviewed transactional merging.

Prompt 5 belongs to Milestone 2 and passed independent acceptance before Prompt 6 work began.

## Gates

- Duplicate signals are explainable; automatic destructive merging is prohibited.
- Merge preserves required metadata and relationships or reports conflicts.
- Candidate review, ignore behavior, merge transactions, rollback, and any schema migration are tested with fixed fictional data.

## Implementation record

- Schema version 4 stores indexed derived keys/tokens and minimal ignored candidate pairs, with transactional backfill and idempotent migration coverage.
- ISBN-10/13 checksum validation, conservative title/author normalization, confidence rules, reasons, integer weights, and uncertainty are separated from persistence and UI.
- Exact/Strong candidates intercept create-save; review supports cancellation, viewing the existing record, three keep-separate meanings, and merge preview.
- A keep-separate decision writes only the selected pair; a new record is created once and any remaining candidates continue against that saved identity. Viewing a candidate preserves the original draft.
- Exact and Strong indexed lookups are deterministic and uncapped. Possible token lookup is deterministically capped at 250 raw index hits and exposes truncation to the review UI.
- Merge retains the selected target identity, exposes scalar conflicts and concrete association outcomes, unions/deduplicates every existing association table, redirects safe relations, rejects self/lossy/link-label conflicts, and deletes the source last in one transaction.
- The accepted implementation added no dependency, network path, entitlement, import flow, graph UI, AI model, or automatic destructive action. Prompt 7's later user-selected file entitlement is recorded separately in ADR-0008.
