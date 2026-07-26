# ADR-0006: Sandboxed file access

- Status: Accepted
- Date: 2026-07-26
- Owners: Project maintainers

## Context

Future import and attachment workflows may need access to user-selected local files without granting broad filesystem access. The lifecycle must include selection, bookmark creation, storage, resolution, stale or unavailable handling, scoped access, and release.

Prompt 1 built an isolated, ad-hoc-signed macOS app with App Sandbox, user-selected read-only-file, and app-scoped bookmark entitlements. The standalone entitlement inspection confirmed that no broad filesystem entitlement was included. Its UI test launched the sandboxed app and confirmed the fictional library UI and file-selection entry point. A separate fictional temporary-file test created a read-only security-scoped bookmark, resolved it, used `startAccessingSecurityScopedResource()` and `stopAccessingSecurityScopedResource()`, and verified that access fails after the selected file is removed.

## Decision

Use `NSOpenPanel` for explicit user selection. For long-lived access, create a read-only app-scoped security-scoped bookmark, store only its opaque bytes in the future local store, resolve it on use, handle stale or missing targets visibly, and balance every successful access start with a stop. Do not request broad file, downloads, or network entitlements.

Prompt 3 or Prompt 7 will define the production storage record, migration, retention, user-visible repair flow, and test fixture policy for bookmark bytes.

## Alternatives considered

- **Persisting absolute paths:** rejected because paths are not authorization and can leak private information.
- **Broad filesystem access:** rejected because it is unnecessary for user-selected workflows and expands privacy risk.
- **Keeping a resource scope open indefinitely:** rejected because access must be narrowly scoped and reliably released.

## Consequences

### Positive

- The application begins from explicit user consent and holds only the minimum permission artifact.
- Read-only access keeps the first import/attachment workflow conservative.

### Negative or tradeoffs

- Bookmarks can become stale or unavailable and need a repair experience.
- The automated check uses a fictional temporary file; a production UI workflow still needs manual confirmation with a user-selected test fixture, never a private library file.

## Privacy and security

Bookmark bytes, selected paths, file names, and file content are private. They must not be committed, included in fixtures, or logged. The experiment did not inspect user files. Network access remains off by default.

## Validation

Completed with the isolated project and package:

```sh
xcodebuild -project Experiments/TechnicalSpikes/MacOSApp/BookAtlasTechnicalSpikes.xcodeproj -scheme BookAtlasTechnicalSpikes -configuration Debug -derivedDataPath /tmp/bookatlas-xcode-spike-signed-derived -destination 'platform=macOS,arch=arm64' test
xcodebuild -project Experiments/TechnicalSpikes/MacOSApp/BookAtlasTechnicalSpikes.xcodeproj -scheme BookAtlasTechnicalSpikes -configuration Debug -derivedDataPath /tmp/bookatlas-xcode-spike-standalone-derived build
CLANG_MODULE_CACHE_PATH=/tmp/bookatlas-swift-module-cache swift test --package-path Experiments/TechnicalSpikes --scratch-path /tmp/bookatlas-spike-build -Xswiftc -module-cache-path -Xswiftc /tmp/bookatlas-swift-module-cache
```

The final macOS result contained two passing tests; the package result contained 13 passing tests. The standalone app entitlement inspection contained App Sandbox, app-scoped bookmark, and user-selected read-only-file permissions only, plus the debug task-allow entitlement.
