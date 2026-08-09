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

The repository must not contain API keys, private keys, certificates,
provisioning profiles, credentials, notarization secrets, private environment
files, or account identifiers. V1.0.0 is source-only and has no distribution
signing/notarization setup. If binary distribution is considered later, it
requires a separate task and secret-safe configuration outside the repository.

## Dependency policy

Apple frameworks are preferred. Before adding a dependency, record its need, source, version strategy, license, maintenance posture, transitive surface, and removal path in an ADR. Security updates must be possible without changing the product's data format unnecessarily.

The Prompt 10 inventory found no Swift package or third-party binary linked by
the production target. It links Apple SDK frameworks and the operating
system's SQLite library through `-lsqlite3`; the isolated technical-spike
package also declares no external package dependency. A release review must
repeat this inventory and assess any newly introduced license before
distribution.

## Backup, restore, and migration

Backups require a documented format/version, integrity checks, atomic destination writes, and failure recovery. Restore never silently overwrites a live library. Migrations are versioned, tested from representative fictional fixtures, and fail without corrupting the prior store.

Prompt 7 backups use `sqlite3_backup` against the live connection, convert the completed temporary snapshot to single-file DELETE journal mode, add a path-free manifest, verify physical integrity and the complete Book Atlas application schema, and refuse existing destinations. Restore rejects symbolic links, non-regular or wrong-type files, invalid SQLite headers/manifests, integrity or `foreign_key_check` failures, incomplete structures, invalid domain values, and future format/schema versions. The 4 GiB backup limit is checked before expensive inspection/copying; capacity is checked before snapshot, staging, and replacement, and Cocoa/POSIX/SQLite out-of-space errors share an explicit result.

Restore creates and validates a recovery snapshot, stages and migrates the selected database, and validates it again. Cancellable work ends before a visible non-cancellable replacement phase. A durable path-free state marker is written before the live connection closes; startup uses it to select only a complete schema-valid live, old, or new file, and otherwise stops editing with recovery guidance. Ordinary failures roll back and reopen the original. Repeatable failure injection covers cancellation, three process-termination positions, replacement, disk-full mapping, rollback, and reconnect boundaries. Details are in ADR-0008 and `docs/FORMATS/PORTABILITY.md`.

Book merges require an explicit preview and confirmation. Field changes, membership unions, link and relation migration, ignored-pair migration, and source deletion share one SQLite transaction; the source is deleted last. Self-relations, relation-note conflicts, and equal external links with different nonempty labels that cannot be preserved are rejected before mutation. The preview disables confirmation for a known blocking association, and any repository failure rolls back the target and source records plus all associations.

Prompt 8 graph construction is read-only and accepts only an existing book UUID plus bounded options. Repository projection queries use fixed SQL templates and indexed relationship columns; callers cannot supply table or column names. Deterministic node/edge caps, candidate truncation disclosure, bounded layout iterations, task cancellation, and stale-generation rejection limit resource use and prevent an older request from replacing the current graph. Canvas content has a separate semantic list so security/privacy controls do not depend on visual color alone. Graph rendering adds no network, file, process-launch, or entitlement surface.

Prompt 9 accepts only syntax-valid HTTPS values of at most 2,048 UTF-8 bytes with no whitespace, credentials, invalid percent encoding, invalid port, or ambiguous host. Both raw text and one-pass percent-decoded text reject C0 controls and DEL, including encoded NUL, Tab, CR, LF, and CRLF. An explicit authority port must be unsigned ASCII decimal in `1...65535`; empty, nondigit, signed, zero, and over-range ports are rejected before normalization. The host must be deterministic lowercased ASCII; Unicode/IDN and punycode are rejected. HTTP, `javascript:`, `data:`, `vbscript:`, manual `file:`, `ibooks:`, `ssh:`, `telnet:`, `shell:`, missing schemes, and unknown schemes are rejected. The same validator protects persistence, ordinary opening, and generated Apple Books search URLs. Stored links are revalidated before `NSWorkspace` dispatch and never fetched by Book Atlas. Tests replace every system integration and do not launch an external application.

Long-lived file entries originate only in `NSOpenPanel`, require a regular non-symbolic file, persist no absolute path, and keep only an opaque read-only app-scoped bookmark plus safe basename. Resolution uses no UI, stale authorization is replaced, and a successful `startAccessingSecurityScopedResource()` is always paired with `stopAccessingSecurityScopedResource()`. Missing, corrupt, moved, or revoked entries require visible repair or removal. Every create/update/read/restore path enforces a 1 MiB per-record bookmark limit. Strict Schema 5 validation rejects invalid lengths with SQLite `length()` before accessing BLOB bytes, streams valid BLOB rows instead of retaining the table, and rejects noncanonical stored display names rather than silently cleaning them. Merge moves every opaque file reference inside the existing single transaction; backup format 1 preserves it and CSV/Markdown exclude it.

Reading-entry presentation is a security boundary as well as a UI concern. The store clears prior-book rows synchronously, arbitrates asynchronous results with cancellation, generation, and `bookID`, and requires row actions to match the current scoped snapshot. Duplicate-candidate viewing uses a separate read-only store; return or cancellation resets only that scope and leaves the main detail unchanged.

Nested duplicate review has one active Escape owner. The duplicate-review layer routes Escape according to its current child state, the editor yields while that layer exists, and candidate detail does not register a competing global handler. One Escape therefore cannot both leave candidate detail and cancel review or trigger editor draft discard.

The Prompt 10 local Release configuration enables Hardened Runtime and
disables Xcode base-entitlement injection. Effective-product inspection found
only App Sandbox, user-selected read/write, and app-scoped bookmarks. Debug
retains `get-task-allow` for local testing; Release does not. Neither product
contains network, Apple Events, automation, Downloads, or broad filesystem
entitlements. This ad-hoc inspection is local engineering evidence; V1.0.0
does not distribute a binary and therefore has no Developer ID, notarization,
or Gatekeeper binary-distribution gate.

## Reporting vulnerabilities

The repository-level `SECURITY.md` directs contributors here and warns against
public disclosure of private content. The repository became Public on
2026-08-10, GitHub Private Vulnerability Reporting is enabled, and the public
non-administrator Security page displays **Report a vulnerability**. The
administrator view instead displays **New draft security advisory**; this is a
role-specific presentation, not a failed external-reporting check. PVR is only
for security vulnerabilities. Private conduct, harassment, and community-safety
reports use the separate channel defined in `CODE_OF_CONDUCT.md`. Do not publish
a personal alternate security address or invent an unmonitored reporting
channel.
