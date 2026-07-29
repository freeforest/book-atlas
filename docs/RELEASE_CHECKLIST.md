# Stable release checklist

This checklist is evidence collection, not proof that a release has happened.
Do not tag, sign, notarize, upload, or announce a stable version until every
applicable gate has an owner and recorded result.

## Product and documentation

- [ ] Confirm the intended stable version and replace the placeholder bundle
      identifier and version metadata.
- [ ] Re-check product boundaries and known limitations in `README.md`.
- [ ] Replace `[YEAR] [COPYRIGHT HOLDER]` in `LICENSE` after an appropriate
      legal/maintainer review; repository text is not legal advice.
- [ ] Configure and test a non-personal private security-reporting channel.
- [ ] Capture screenshots only from the committed fictional fixture; inspect
      the accessibility tree and image background for private content.
- [ ] Confirm README, contributor guidance, code of conduct, security policy,
      issue templates, and pull-request template render correctly.

## Build and compatibility

- [ ] Build Debug and Release from a clean isolated checkout.
- [ ] Run the complete unit/integration/migration/security/performance suite.
- [ ] Run the complete UI suite in an unlocked interactive session and confirm
      XCUIAutomation initialized and every test executed.
- [ ] Exercise the minimum supported macOS 14 runtime on real or official
      virtualized hardware; record Mac, OS, Xcode, and result.
- [ ] Perform manual light/dark, accent-color, small-window, keyboard,
      Reduce Motion, VoiceOver, and Accessibility Inspector review.
- [ ] Re-run the complete Schema 1→5 migration and backup/restore matrix.

## Privacy and security

- [ ] Inspect final signed-product entitlements; allow only App Sandbox,
      explicit user-selected file access, and app-scoped bookmarks.
- [ ] Confirm no network, Apple Events, automation, Downloads, broad
      filesystem, microphone, camera, or contacts permission is present.
- [ ] Confirm no telemetry, advertising, tracking, crash upload, network
      client, WebView, Shell, AppleScript, or private API was introduced.
- [ ] Audit every production log and error for titles, contributors, notes,
      ISBNs, URLs, paths, import rows, bookmark bytes, and database payloads.
- [ ] Scan tracked files for databases, WAL/SHM files, backups, exports,
      bookmarks, real reading lists, absolute private paths, secrets, signing
      material, `DerivedData`, and `.xcresult`.
- [ ] Re-test CSV formula protection, parser limits, symlink rejection, URL
      validation, bookmark bounds, transactional merge rollback, restore
      recovery copies, disk-full handling, and interruption recovery.

## Dependencies, performance, and distribution

- [ ] Re-run the dependency inventory and record every direct/transitive
      license; currently the production target uses only Apple frameworks and
      system SQLite.
- [ ] Run fixed-seed 1k/5k/10k benchmarks multiple times and publish
      environment, method, individual observations, median/range, memory, main
      actor responsiveness, and noise caveats.
- [ ] Select a release signing identity without committing certificates or
      profiles; inspect the signed archive's effective entitlements.
- [ ] Perform notarization and Gatekeeper validation using protected CI/local
      secrets, then record receipts without secret values.
- [ ] Prepare release notes and checksums. Obtain independent acceptance before
      tagging or uploading.
