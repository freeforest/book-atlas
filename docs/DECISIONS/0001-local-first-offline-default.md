# ADR-0001: Local-first and offline by default

- Status: Accepted
- Date: 2026-07-24
- Owners: Project maintainers

## Context

Book Atlas manages a personal bibliography, including notes, reading status, sources, URLs, and relationships that may reveal private interests. The first release serves one local user and does not need accounts, collaboration, recommendations, or remote metadata retrieval.

## Decision

Book Atlas will be a sandboxed native macOS application whose primary data store is local to the app. It will work offline and will not request the network client entitlement by default. It will not include accounts, cloud sync, telemetry, advertising, tracking, automatic crash upload, or automatic cover/metadata downloads.

User-initiated import, export, backup, restore, and opening of validated external links are compatible with this decision. Any future network feature requires a separate accepted ADR with a concrete user need, explicit data flow, privacy and security review, entitlement rationale, and visible user control.

This ADR does not choose the persistence framework or deployment target; Prompt 1 must validate those separately.

## Alternatives considered

- **Cloud-backed source of truth:** rejected because it adds accounts, service operations, network failure modes, and privacy exposure without a first-release need.
- **Automatic online enrichment:** rejected because it changes the offline and privacy boundary and requires provider, licensing, caching, and data-quality decisions.
- **Optional telemetry from the first release:** rejected because local diagnostics and explicit user reports are sufficient for the initial single-user scope.

## Consequences

### Positive

- The application remains useful without connectivity.
- Operational complexity and exposure of private library content are reduced.
- Data ownership and backup/restore behavior stay visible to the user.

### Negative or tradeoffs

- No cross-device synchronization or automatic enrichment.
- The user is responsible for initiating and storing backups and exports.
- Any later network capability needs explicit architectural and product review.

## Privacy and security

Private content stays on the device unless the user explicitly selects an export or external destination. App Sandbox and least-privilege entitlements are baseline controls. Logging must omit or redact content, URLs, and paths.

## Validation

This is a repository-level product constraint, verified by documentation review in Prompt 0. Entitlement behavior, storage location, file authorization, and external URL handling remain technical experiments for Prompt 1 and implementation checks for later prompts.

