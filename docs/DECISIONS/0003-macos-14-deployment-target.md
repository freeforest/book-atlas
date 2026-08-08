# ADR-0003: macOS 14 deployment target

- Status: Superseded by ADR-0009
- Date: 2026-07-26
- Owners: Project maintainers

## Context

The project needs a deployment target that supports a modern SwiftUI macOS application, AppKit bridges where needed, App Sandbox, security-scoped bookmarks, and an evaluated SwiftData alternative without creating multiple compatibility paths during the first release.

Prompt 1 verified Xcode 26.6 (build 17F113), Swift 6.3.3, and the macOS 26.5 SDK. The isolated SwiftUI app compiled and its signed unit/UI tests passed on an arm64 Mac running macOS 26.5.2. The test target uses `MACOSX_DEPLOYMENT_TARGET = 14.0`.

## Decision

Set the first production deployment target to macOS 14.0 (Sonoma). Prompt 2 must preserve this target unless a new ADR supersedes it.

## Alternatives considered

- **macOS 13:** could widen compatibility, but requires a separate audit of the modern SwiftUI and persistence-candidate API surface before it can be supported honestly.
- **A newer target only:** reduces compatibility without an evidence-backed product need.

## Consequences

### Positive

- The first release can use the verified modern SwiftUI baseline and keep the SwiftData candidate available for future reassessment.
- Maintenance starts with one deployment target and no legacy compatibility layer.

### Negative or tradeoffs

- Macs that cannot run macOS 14 are outside the first release.
- Prompt 10 still needs an accessibility and performance check on supported macOS versions; Prompt 1 tested only macOS 26.5.2.

## Privacy and security

No additional data collection, entitlement, or network impact follows from the deployment target. The normal privacy and sandbox requirements remain mandatory.

## Validation

Completed commands in the isolated experiment:

```sh
xcodebuild -project Experiments/TechnicalSpikes/MacOSApp/BookAtlasTechnicalSpikes.xcodeproj -scheme BookAtlasTechnicalSpikes -configuration Debug -derivedDataPath /tmp/bookatlas-xcode-spike-signed-derived -destination 'platform=macOS,arch=arm64' test
xcodebuild -project Experiments/TechnicalSpikes/MacOSApp/BookAtlasTechnicalSpikes.xcodeproj -scheme BookAtlasTechnicalSpikes -configuration Debug -derivedDataPath /tmp/bookatlas-xcode-spike-standalone-derived build
```

The final test result contained two passing tests and no failures. The standalone build was ad-hoc signed and contained only App Sandbox, app-scoped bookmark, and user-selected read-only-file entitlements (plus the debug task-allow entitlement).
