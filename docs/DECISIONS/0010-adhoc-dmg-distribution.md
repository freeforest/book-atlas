# ADR-0010: Ad-hoc signed DMG distribution

- Status: Accepted (owner decision, 2026-09-10; verification is recorded separately)
- Supersedes: ADR-0009's source-only restriction for versions starting at 1.2.0;
  its macOS 26.0 minimum remains unchanged.

## Decision

Distribute a universal `BookAtlas.app` inside `BookAtlas-<version>.dmg` through
owner-managed GitHub Releases. End users need no developer tools. Use ad-hoc
signing, the existing Sandbox and Hardened Runtime settings. No Developer ID,
Apple Developer Program membership, notarization, stapling, or App Store work.
The v1.0.0 source-only Release and tag remain immutable historical releases.

Keep `io.github.freeforest.BookAtlas`, the sandbox Application Support path,
Schema 5 and existing portability formats. Never package a library/database.
App replacement must not delete or move user data. Recommend a full backup
before upgrades, especially from differently configured source builds.

## Consequences and security

Ad-hoc signing checks bundle integrity but does not authenticate this publisher
to Apple. Gatekeeper may block first launch; documentation explains the
per-app **Open Anyway** choice and its risk, following
[Apple's instructions](https://support.apple.com/guide/mac-help/mh40616/mac).
No global security changes or quarantine removal are recommended. Managed Macs
may prohibit unsigned apps. New releases may require renewed user approval.

The package script is local, uses Xcode and macOS tools only, preserves build
logs and does not publish or perform Git operations. A SHA-256 file detects
accidental corruption; it is not a publisher identity certificate.

Application networking and paid signing remain out of scope. Intel code in a
universal executable is not evidence of Intel hardware testing. Actual package,
installation, relaunch and persistence results belong in the
[P12 record](../PLANS/PROMPT-12.md).
