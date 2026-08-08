# Book Atlas v1.0.0 — GitHub source release notes draft

**Draft — not published**

Book Atlas · 图书志 is a local-first native macOS bibliography manager for
maintaining a personal book catalog and exploring bounded relationships among
books. V1.0.0 is prepared as source code only for macOS 26. Users build it with
a compatible Xcode 26 toolchain; no precompiled application is supplied.

## Highlights

- Create, inspect, edit, delete, search, filter, sort, and page through a local
  bibliography.
- Organize books with tags, lists, sources, reading status, and priority.
- Review explainable duplicate candidates and perform an explicit
  transactionally safe merge.
- Import versioned CSV through mapping and bounded preview; export selected
  data as CSV or Markdown.
- Create and validate full database backups, preview restores, retain a
  recovery copy, and recover safely across interrupted replacement.
- Explore a bounded local graph derived from author, tag, list, source, and
  explicit relation evidence.
- Add user-initiated HTTPS entries, conservative Apple Books fallbacks, and
  security-scoped local-file entries.
- Use keyboard navigation, VoiceOver semantics, Reduce Motion-safe behavior,
  responsive Light/Dark layouts, and an accessible graph list.

## Platform and build

- macOS 26 only; macOS 14/15 compatibility is not promised or tested as a
  supported matrix.
- Build from source with Xcode 26, Swift, SwiftUI, AppKit, and system SQLite.
- Application identifier: `io.github.freeforest.BookAtlas`.
- Version: 1.0.0; build: 1.
- Source license: MIT, Copyright (c) 2026 FreeForest.

The GitHub Release is intended to use the `v1.0.0` source archives and this
release-notes text only. It will not include an `.app`, `.dmg`, `.pkg`, binary
application archive, certificate, provisioning profile, or signing material.

## Privacy and data safety

Book Atlas is offline by default. It has no account, telemetry, analytics,
advertising, tracking, cloud sync, or automatic metadata download. External
URLs and local files are acted on only after explicit user actions. Local-file
references use app-scoped security bookmarks; CSV/Markdown exports omit local
bookmarks and private file paths. Full backups contain the private library and
are unencrypted, so users should store them appropriately.

## Quality summary

Prompt 10 passed independent acceptance at documentation baseline
`ec0b04f1c004ef5c897d3269e335c92034d6021e`, against verified code baseline
`4cc20b8c88cb674a4f9a52d3e8de70c295169281`. That accepted evidence includes
successful Debug/Release builds, 3/3 targeted graph regressions, 41/41 complete
UI tests after XCUIAutomation initialized, and 200/200 complete non-UI tests,
with zero failures and zero skips. Fresh V1.0.0 macOS 26 metadata builds/tests
and actual-product inspection are recorded separately in the quality audit
when completed.

Accessibility Inspector reported zero warnings separately for the unselected
Library state and the selected fixed-fictional A101 detail state. This is not a
claim that every page and future state is permanently warning-free. Earlier
accent, Reduce Motion, complete keyboard, and VoiceOver evidence also retains
its documented baseline boundary.

## Known limitations

- Book Atlas does not read or precisely target a private Apple Books library
  item. Public-search and application behavior remains controlled by macOS and
  Apple Books.
- Real browser, Apple Books, long-lived bookmark, and other external-system
  behavior is not guaranteed by adapter tests.
- Backups are unencrypted and recovery copies have no automatic retention
  policy.
- Possible duplicate lookup is deliberately bounded and is not a universal
  edition/translation authority system.
- The graph is local and bounded; it is not a global graph or recommendation
  service.

## Security reports

Sensitive reports will use GitHub Private Vulnerability Reporting through the
repository Security page. Because the repository remains Private during
preparation, the user must enable and verify **Report a vulnerability** during
the manual transition to Public. Do not disclose vulnerabilities, private
library content, paths, bookmarks, recovery data, credentials, keys, or
certificates through public Issues. Ordinary non-sensitive bugs may use the
public bug template with fixed fictional examples.

This draft does not state that the repository is Public, tag `v1.0.0` exists,
the GitHub Release exists, or V1.0.0 has been published.
