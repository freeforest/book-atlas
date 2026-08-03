# Milestone 5 — release quality

## Goal

Verify release quality and prepare an accurate, privacy-conscious open-source repository.

## Stage

- Prompt 10: regression and performance checks, accessibility review, privacy/security audit, packaging documentation, license/dependency inventory, contributor guidance, and known limitations.

Prompt 10 implementation is complete and awaits independent review. It is not
a release, tag, signed distribution, notarization, upload, or acceptance.
Local closure evidence is successful Debug and hardened local Release builds,
190/190 unit/integration/migration/security/performance tests, and 37/37 UI
tests with XCUIAutomation initialized. The fixed-fictional performance record
now separates test-data preparation from three-run existing-library launch,
database open, 200-row first-page load, next-page load, disclosed multi-page
scrolling/hitch, tag-count, and Schema 1–4→5 migration measurements. The
ordinary list discloses exact result counts and appends bounded 200-row pages
through an accessible keyboard action; it no longer silently truncates at
500. Graph focus and create/edit/merge refreshes preserve an explicit UUID
beyond the first page with a bounded first-page-plus-one lookup; missing or
excluded targets clear selection instead of selecting an unrelated first
row. Release Instruments existing-library launch remains unverified because
the measured desktop trace could not be authorized from this execution
surface. The
required human VoiceOver/Accessibility Inspector and appearance/accent/
small-window/Reduce Motion audit could not be controlled from the current task
execution surface and remains an explicit unverified release gate.

The fifth closure also makes the precise missing/excluded selection issue win
over generic empty/no-results placeholders when a bounded query returns zero
rows. The excluded state includes an accessible clear-query action, and both
paths have Store plus real XCUI regressions without changing the 200-row page
or 1,000-row repository hard limit. A second manual-audit attempt on
2026-08-03 started only a fixed-fictional in-memory Debug app, but the native
Computer Use pipe closed before any Book Atlas desktop or AX state could be read; all
human gates remain blocked rather than inferred from automation.

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
  graph, and main-actor responsiveness checks, plus a detailed BLOCKED record
  for every manual accessibility/visual path not performed;
- privacy, security, logging, entitlement, dependency/license, and repository
  artifact audits;
- license placeholder, contribution/conduct/security entry points, issue and
  pull-request templates, fictional fixture/generator, known limitations, and
  a stable-release checklist.

## Release blockers that remain external to implementation

- replace the placeholder bundle identifier, version decision, license year
  and holder;
- configure a monitored non-personal private security-reporting channel;
- manually exercise Light/Dark, a non-default accent, 520×360 and normal
  windows, VoiceOver, Accessibility Inspector, Reduce Motion, the complete
  keyboard path, and macOS 14;
- run three authorized Release Instruments launches against each
  pre-generated 1k/5k/10k Schema 5 library and record the same exact-count
  verification used by Debug;
- configure release signing, archive verification, notarization, Gatekeeper
  validation, screenshots, release notes, tag, and upload.
