# Milestone 0 — foundation and app skeleton

## Goal

Create a safe repository baseline, replace uncertain technology assumptions with isolated evidence, and establish a minimal runnable macOS application without implementing library features.

## Stages

- Prompt 0: rules, privacy boundaries, core docs, ADR process, roadmap, and repository checks.
- Prompt 1: disposable experiments for persistence/migration, SwiftUI/AppKit, graph rendering, external links, sandboxed file access, deployment target, and build/test commands.
- Prompt 2: minimal `BookAtlas` Xcode project and test targets using the accepted decisions.

## Deliverables and gates

- No production dependency or database choice before Prompt 1 evidence.
- App Sandbox on and network entitlement off by default.
- Accepted ADRs for deployment target, persistence, and any adopted dependency or integration.
- Prompt 2 build and test commands run successfully on the recorded toolchain.
- No CRUD, import/export, duplicate merge, graph feature, or Apple Books promise.

## Prompt 0 verification

Check Git state, ignored private-data paths, fictional fixtures, private-path/secret patterns, document consistency, and the absence of an app build/test command. Report all real results.

