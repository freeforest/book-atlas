# Book Atlas V1.0.0 GitHub source publication checklist

This checklist applies only to the source-only publication of
[`freeforest/book-atlas`](https://github.com/freeforest/book-atlas). The
repository exists and remains Private during preparation. The user—not
Codex—will perform every Git/GitHub write, change visibility to Public, create
tag `v1.0.0`, and create the GitHub Release titled `Book Atlas v1.0.0`.

The Release will use the tag's GitHub source archives and prepared notes only.
It will not upload a precompiled `.app`, `.dmg`, `.pkg`, binary application
archive, certificate, or signing material. Mac App Store, Apple Developer,
Developer ID, notarization, stapling, and Gatekeeper binary distribution are
not part of this source-publication task.

Prompt 10 passed independent acceptance at documentation baseline
`ec0b04f1c004ef5c897d3269e335c92034d6021e`, against verified code baseline
`4cc20b8c88cb674a4f9a52d3e8de70c295169281`. Prompts 0–10 are complete; this
preparation is not Prompt 11 and is not proof that publication occurred.

## Confirmed identity and scope

- [x] GitHub owner `freeforest`, display name `FreeForest`, repository
      `book-atlas`, URL `https://github.com/freeforest/book-atlas`.
- [x] Repository exists and is currently Private.
- [x] Public source version is 1.0.0; intended tag is `v1.0.0`; intended
      Release title is `Book Atlas v1.0.0`.
- [x] Publication is source-only and users build with a compatible Xcode 26
      toolchain.
- [x] No precompiled application or binary package is planned for V1.0.0.
- [x] MIT copyright holder/year are user-confirmed as `2026 FreeForest`.
- [x] Application bundle identifier is user-confirmed as
      `io.github.freeforest.BookAtlas`.

## Platform and project metadata

- [x] Project-level Debug/Release deployment target is macOS 26.0.
- [x] App, unit-test, and UI-test Debug/Release targets declare macOS 26.0.
- [x] App Debug/Release marketing version is 1.0.0 and build number is 1.
- [x] App Debug/Release bundle identifier is
      `io.github.freeforest.BookAtlas`; test bundle identifiers use the same
      namespace and retain the correct host relationship.
- [x] ADR-0009 supersedes the historical ADR-0003 macOS 14 decision.
- [x] Verify deployment target, version, build, and bundle identifier in the
      fresh Debug and Release products.
- [ ] Verify from a clean post-commit checkout before public visibility changes.

## Security reporting

- [x] `SECURITY.md` selects GitHub Private Vulnerability Reporting and forbids
      sensitive disclosure through public Issues.
- [x] No personal email or invented alternate private channel is published.
- [ ] After the repository becomes Public, the user enables Private
      Vulnerability Reporting and confirms **Report a vulnerability** appears
      on the repository Security page. GitHub does not expose this feature for
      the current Private repository.
- [ ] Establish a separate private conduct-reporting channel. Security PVR is
      not a conduct-reporting substitute, and no personal address is guessed or
      published.

## Build and verification

- [x] Debug build succeeds from a new `/tmp` DerivedData path.
- [x] Release build succeeds from a separate new `/tmp` DerivedData path.
- [x] Complete non-UI suite executes 200/200 with zero failures and zero skips.
- [x] Complete UI suite initializes XCUIAutomation, executes 41/41, and
      has zero failures and zero skips.
- [x] `xcresulttool` summaries and tests trees agree with the reported counts.
- [x] Actual Debug/Release entitlements confirm App Sandbox, user-selected file
      access, and app-scoped bookmarks only; no network, Apple Events,
      automation, Downloads, Team ID, Developer ID, distribution certificate,
      or provisioning profile is present.
- [x] A real macOS `NSOpenPanel` appears from fixed-fictional in-memory data,
      is cancelled without selecting a file, and leaves the library unchanged.

## Repository and public materials

- [x] `LICENSE` contains `Copyright (c) 2026 FreeForest` with no template
      placeholders.
- [x] README states macOS 26-only, source-only, build-from-source requirements,
      repository identity, version/tag/Release strategy, and binary exclusions.
- [x] `CHANGELOG.md` keeps `[1.0.0] - Unreleased` until the user publishes.
- [x] `docs/RELEASE_NOTES-1.0.0.md` is a draft and has no release date or
      private/test-temporary path.
- [x] Confirm `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, Issue/PR
      templates, SampleData, Scripts, roadmap, quality, privacy, and security
      documents agree with the final evidence and explicitly retain the pending
      conduct/PVR publication gates.
- [x] Confirm all committed samples and generated examples are fixed fictional
      data and use only safe destinations such as `example.invalid`.

## Privacy, security, and artifact scan

- [x] Scan tracked and untracked paths for databases, WAL/SHM/journal files,
      backups, exports, bookmarks, real reading lists/notes, credentials,
      certificates, keys, provisioning profiles, `DerivedData`, `.xcresult`,
      `.app`, `.dmg`, `.pkg`, and binary archives.
- [x] Scan tracked text for current-user absolute paths, private URLs, real
      library content, temporary evidence paths, secrets, and signing material;
      classify documented fictional and historical test values explicitly.
- [x] Confirm `.gitignore` covers private data and generated artifacts.
- [x] Confirm no telemetry, advertising, tracking, crash upload, network
      client, third-party binary dependency, or new entitlement was introduced.
- [x] Confirm Schema remains 5 and migration path remains
      `1 → 2 → 3 → 4 → 5`.
- [x] Review the final diff and pass `git diff --check`.

## Evidence boundaries to retain

- [x] Prompt 10 history retains 37/37, 40/40, final 41/41 UI; 197/197,
      199 plus benchmark `signal term`, final 200/200 non-UI; and zero-test
      infrastructure attempts in their correct contexts.
- [x] Inspector history retains old 25/16 warnings and current state A/B zero
      warnings without claiming permanent whole-application zero.
- [x] Prior accent, Reduce Motion, complete keyboard, and VoiceOver evidence is
      not represented as fully rerun on `4cc20b8c…`.
- [x] Retain the historical native-panel `PASS WITH LIMITATION` and record the
      later V1.0.0 `PASS` only after a real `NSOpenPanel` is observed and safely
      cancelled without selecting or reading a file.
- [x] Real browser, Apple Books private-library targeting, and real long-lived
      bookmark behavior remain outside the accepted evidence.

## Manual public actions — intentionally incomplete

- [ ] User reviews and records the final manual Git changes.
- [ ] User pushes the final source changes.
- [ ] User changes `freeforest/book-atlas` from Private to Public.
- [ ] User enables and verifies GitHub Private Vulnerability Reporting.
- [ ] User creates tag `v1.0.0`.
- [ ] User creates and publishes GitHub Release `Book Atlas v1.0.0` using only
      the source archives and prepared notes.
- [ ] User publishes any announcement they choose.

Preparation does not authorize or imply completion of any item in this final
section. Whether V1.0.0 meets publication conditions belongs to independent
review after the evidence above is complete.
