# Milestone 5 — release quality

## Goal

Verify release quality and prepare an accurate, privacy-conscious open-source repository.

## Stage

- Prompt 10: regression and performance checks, accessibility review, privacy/security audit, packaging documentation, license/dependency inventory, contributor guidance, and known limitations.

Prompt 10 implementation is complete and awaits independent review. It is not
a release, tag, signed distribution, notarization, upload, or acceptance.
Local closure evidence is successful Debug and hardened local Release builds,
173/173 unit/integration/migration/security/performance tests, and 27/27 UI
tests with XCUIAutomation initialized.

## Gates

- Build and full test suite pass on the documented supported toolchain.
- Privacy scan, entitlement review, migration/backup recovery checks, and fictional-data audit pass.
- Performance results state hardware, dataset, method, and limitations.
- Public documentation does not expose personal contact details, data, paths, signing material, or unsupported capability claims.

## Deliverables

- full Debug/Release and regression evidence, including Schema 1→5;
- repeatable fixed-fictional 1k/5k/10k measurements with environment and noise
  disclosure;
- automated light/dark, small-window, keyboard, accessibility-tree, bounded
  graph, and main-actor responsiveness checks, plus an explicit list of manual
  accessibility work not performed;
- privacy, security, logging, entitlement, dependency/license, and repository
  artifact audits;
- license placeholder, contribution/conduct/security entry points, issue and
  pull-request templates, fictional fixture/generator, known limitations, and
  a stable-release checklist.

## Release blockers that remain external to implementation

- replace the placeholder bundle identifier, version decision, license year
  and holder;
- configure a monitored non-personal private security-reporting channel;
- manually exercise VoiceOver, Accessibility Inspector, Reduce Motion, accent
  colors, and macOS 14;
- configure release signing, archive verification, notarization, Gatekeeper
  validation, screenshots, release notes, tag, and upload.
