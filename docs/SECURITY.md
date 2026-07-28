# Security

## Security goals

Protect the integrity and confidentiality of the local library, minimize OS capabilities, handle untrusted imported content safely, and preserve a recoverable path through migrations, merges, and restore operations.

## Threat boundaries

- Imported Markdown, CSV, JSON, archives, URLs, images, and database backups are untrusted input.
- Local paths, bookmark data, library contents, exports, and logs may expose private information.
- External URLs may invoke another application or an unexpected destination.
- Malformed or oversized data can exhaust memory, disk, or UI responsiveness.

## Required controls

- Keep App Sandbox enabled and entitlements minimal; network access is absent by default.
- Use system file pickers and validated security-scoped access. Balance every access start with a stop and handle stale bookmarks explicitly.
- Parse data as data, never as executable commands. Validate type, size, encoding, structure, counts, and destinations before committing changes.
- Use transactions for migrations, merges, imports, and restore finalization.
- Stage imports and restores, show validation failures, and avoid partial replacement of the live library.
- Prevent path traversal and symlink surprises when processing archives or file bundles.
- Validate URL schemes and require a visible user action before opening external destinations.
- Apply least-privilege file permissions and avoid sensitive payloads in errors or logs.

## Secrets and signing

The repository must not contain API keys, private keys, certificates, provisioning profiles, credentials, notarization secrets, private environment files, or account identifiers. Signing and notarization setup is local or CI-secret configuration and must be documented without secret values.

## Dependency policy

Apple frameworks are preferred. Before adding a dependency, record its need, source, version strategy, license, maintenance posture, transitive surface, and removal path in an ADR. Security updates must be possible without changing the product's data format unnecessarily.

## Backup, restore, and migration

Backups require a documented format/version, integrity checks, atomic destination writes, and failure recovery. Restore never silently overwrites a live library. Migrations are versioned, tested from representative fictional fixtures, and fail without corrupting the prior store.

Book merges require an explicit preview and confirmation. Field changes, membership unions, link and relation migration, ignored-pair migration, and source deletion share one SQLite transaction; the source is deleted last. Self-relations and relation-note conflicts that cannot be preserved are rejected, and any failure rolls back the target and source records plus all associations.

## Reporting vulnerabilities

Before a public release, add a repository security policy with a private reporting channel. Do not publish a personal address or placeholder channel before the maintainer chooses one.
