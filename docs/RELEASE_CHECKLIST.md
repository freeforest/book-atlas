# GitHub source publication checklist

This checklist applies only to making the Book Atlas source repository public
on GitHub. It does not create or upload a precompiled `.app`, enter the Mac App
Store, use Developer ID, perform Apple notarization, require an Apple Developer
account, or establish a binary download/update channel. Every push, public
visibility change, tag, GitHub Release, upload, and announcement requires the
user's explicit authorization.

Prompt 10 passed independent acceptance at documentation baseline
`ec0b04f1c004ef5c897d3269e335c92034d6021e`, against verified code baseline
`4cc20b8c88cb674a4f9a52d3e8de70c295169281`. Prompts 0–10 are complete. This
checklist is for the separate GitHub source-publication preparation task, not a
Prompt 11 and not evidence that publication has occurred.

## Scope and authorization

- [ ] Confirm that publication remains source-only: no downloadable
      precompiled `.app` and no third-party binary-distribution channel.
- [ ] Confirm the final GitHub repository owner and repository address without
      guessing a username or organization.
- [ ] Confirm the final public version number.
- [ ] Confirm whether a formal Git tag is wanted; a tag is optional unless the
      user decides otherwise.
- [ ] Record explicit user authorization separately before push, changing the
      repository to public, creating a tag or GitHub Release, uploading any
      file, or announcing publication.

## License, identity, and security reporting

- [ ] Obtain the user-confirmed copyright year.
- [ ] Obtain the user-confirmed copyright holder; do not infer a legal name or
      copyright subject.
- [ ] Replace `[YEAR] [COPYRIGHT HOLDER]` in `LICENSE` only after those values
      are confirmed. Repository text is not legal advice.
- [ ] Decide whether the placeholder bundle identifier
      `com.example.BookAtlas` should change for the public source build; do not
      guess a final identifier.
- [ ] Enable and test GitHub Private Vulnerability Reporting, or configure and
      test another user-confirmed, actually maintained private security channel.
      Do not invent an email address and do not treat a public Issue as private
      vulnerability reporting.
- [ ] Update `SECURITY.md` only after the selected private channel is real and
      verified.

## macOS 26 technical alignment

The confirmed future support policy is latest macOS 26 only. The Xcode project
currently still declares `MACOSX_DEPLOYMENT_TARGET = 14.0`; therefore the
macOS 26-only policy is not yet implemented technically. No macOS 14/15
compatibility promise or multi-version test matrix is planned.

- [ ] In a separately scoped implementation task, change the project deployment
      target from 14.0 to the user-confirmed macOS 26 target.
- [ ] Align README, DEVELOPMENT, support wording, and build instructions with
      the resulting project configuration.
- [ ] From a clean isolated checkout, build Debug and Release locally.
- [ ] Run the complete non-UI suite.
- [ ] Run the complete UI suite in an unlocked interactive session and confirm
      XCUIAutomation actually initialized and every test executed.
- [ ] Confirm every test, sample, screenshot, and generated dataset remains
      fixed and fictional.
- [ ] Repeat necessary Light/Dark, graph, accessibility, and window checks that
      could be affected by the deployment-target/toolchain alignment.

## Repository and documentation

- [ ] Confirm `.gitignore` covers databases, WAL/SHM/journal files, backups,
      bookmark data, `DerivedData`, `.xcresult`, certificates, keys, signing
      material, generated output, and private local data.
- [ ] Confirm README accurately states source-only publication, macOS 26-only
      policy, build-from-source requirements, and known integration limits.
- [ ] Confirm `LICENSE`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`,
      Issue templates, and the pull-request template render correctly.
- [ ] Confirm the committed sample data and performance generator are fictional
      and contain no personal identifiers or private destinations.
- [ ] Confirm roadmap, quality audit, development guidance, privacy/security
      documents, and known limitations agree with the accepted Prompt 10 state.
- [ ] Confirm no documentation claims that GitHub is already public, a tag or
      GitHub Release exists, or an application is available for download.

## Privacy, security, and artifact scan

- [ ] Scan tracked and staged files for real databases, WAL/SHM files, backups,
      exports, bookmarks, reading lists, user notes, local absolute paths,
      credentials, account identifiers, certificates, private keys, signing
      assets, `DerivedData`, `.xcresult`, and generated `.app` products.
- [ ] Confirm no telemetry, advertising, tracking, crash upload, network client,
      WebView, Shell, AppleScript, private API, or new permission was introduced.
- [ ] Recheck production logs and errors for titles, authors, notes, ISBNs,
      URLs, paths, rows, bookmark bytes, and database payloads.
- [ ] Confirm the production dependency inventory still contains only Apple
      frameworks and system SQLite, with no third-party binary dependency.
- [ ] Confirm Schema remains 5 and migration path remains
      `1 → 2 → 3 → 4 → 5` unless a separately reviewed implementation changes it.
- [ ] Review the final diff from the clean publication-preparation baseline.

## Accepted evidence boundaries to retain

- [ ] Keep 41/41 UI and 200/200 non-UI as the latest accepted full-suite counts;
      preserve 37/37, 40/40, 197/197, 199 plus `signal term`, the separately
      passed benchmark, and zero-test infrastructure runs in their historical
      contexts.
- [ ] Preserve the initial Light validation finding and its fixed summary,
      field-error, focus, and repeated-announcement closure.
- [ ] Preserve historical Inspector 25/16 warnings and the current state A/B
      zero-warning results without claiming permanent whole-application zero.
- [ ] Preserve `PASS WITH LIMITATION — 未实际显示原生系统文件面板`; fixed-fictional
      cancellation did not display or pass a real `NSOpenPanel`.
- [ ] State that a real browser, Apple Books launch, real long-lived bookmark,
      and other real external-system behavior remain unverified.

## Apple binary distribution: not applicable

Under the current source-only policy, the following are not publication gates:
Apple Developer membership, App Store Connect, App Store Review, Developer ID
Application/Installer, distribution certificates, provisioning profiles,
notarization and tickets, stapling, Gatekeeper validation of a downloadable
binary, Mac App Store sandbox submission, and App Store download/update flow.
Local ad-hoc signing, App Sandbox, Hardened Runtime, and entitlement inspection
remain local engineering evidence only.

If a future user decision introduces a downloadable precompiled `.app` through
GitHub Releases or another channel, open a separate authorized release task and
reassess Developer ID, notarization, Gatekeeper, distribution signing, download
integrity, installation instructions, and update strategy before any upload.

## Final public action

- [ ] Reconfirm the worktree, HEAD, branch, remote target, and final diff.
- [ ] Reconfirm no build product, private data, certificate, or key will be
      uploaded.
- [ ] Obtain explicit user authorization for each requested Git/GitHub write.
- [ ] Report exactly which actions succeeded; do not infer that source
      preparation means the repository is public.
