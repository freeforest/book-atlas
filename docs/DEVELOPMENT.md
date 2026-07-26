# Development

## Current production skeleton

`BookAtlas.xcodeproj` contains the `BookAtlas` macOS application scheme plus `BookAtlasTests` and `BookAtlasUITests`. It targets macOS 14.0, uses only SwiftUI and AppKit supplied by macOS, and is sandboxed. The Debug bundle identifier is the intentional placeholder `com.example.BookAtlas`; release signing, distribution identity, and notarization are not configured.

The skeleton contains no database, network client entitlement, external-link opening, local-file access, or book business logic. It uses only navigation metadata and static, non-private placeholder text.

## Build

```sh
xcodebuild -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -derivedDataPath /tmp/bookatlas-production-standalone-derived build
```

This command was verified on Xcode 26.6 (build 17F113), Swift 6.3.3, and an arm64 Mac running macOS 26.5.2. It ad-hoc signs the Debug product for local execution.

## Test

```sh
xcodebuild -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -derivedDataPath /tmp/bookatlas-production-derived -destination 'platform=macOS,arch=arm64' test
```

The latest result passed six tests with no failures: five unit tests for navigation, layout, and appearance smoke coverage, plus one UI test that launches the app and visits all five sidebar entries.

## Working boundaries

- Keep `BookAtlas/App/` responsible for composition and lightweight navigation only.
- Keep page placeholders independently replaceable; do not add persistence work to SwiftUI views.
- Follow ADR-0002 for the future single SQLite store, but add it only in Prompt 3.
- Keep App Sandbox enabled and add no network client entitlement unless a future accepted ADR requires it.
- Preserve `Experiments/TechnicalSpikes/` as evidence only; production code must not import it.
