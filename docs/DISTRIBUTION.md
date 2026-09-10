# Local macOS distribution

P12 prepares an **ad-hoc signed, non-notarized** GitHub Release DMG.
The owner publishes it manually. The historical
[v1.0.0 source checklist](RELEASE_CHECKLIST.md) is not a binary release checklist.

## Build and package

On a Mac with Xcode 26 and its command-line tools selected, from the repo root:

```sh
bash Scripts/package_release.sh
```

The script reads the Release version/build from the Xcode project, builds
`Release` with `ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO`, validates actual
metadata, signature, three production entitlements and system-only dynamic
links, then creates and verifies a compressed read-only DMG using `hdiutil`.
It does not launch the app or inspect any library. The printed temporary
directory retains the raw build log, true exit code, `.xcresult`, app and
package diagnostics. No log or database is embedded in the DMG.

Output for this version:

```text
dist/BookAtlas-1.2.0.dmg
dist/BookAtlas-1.2.0.dmg.sha256
```

Existing artifacts are never overwritten. To build a second candidate use
`bash Scripts/package_release.sh /tmp/bookatlas-new-candidate` with a new
destination. For a future release change both app Debug/Release versions and
advance the build number, then update the release notes. A stable command does
not promise byte-identical DMGs across builds or different Xcode versions.

The ICNS artwork is included in source. To regenerate it after an intentional
design edit, run `swift Scripts/generate_app_icon.swift <new-temp-directory>`
and `iconutil -c icns <new-temp-directory>/AppIcon.iconset -o
BookAtlas/Resources/AppIcon.icns`. It uses AppKit vector drawing and macOS
tools, with no downloaded assets or external package dependency.

## Installation and release checks

- Verify DMG checksum with `shasum -a 256 -c BookAtlas-1.2.0.dmg.sha256` in
  the directory containing both files.
- Mount DMG, check App/icon/Applications shortcut, copy into Applications,
  eject DMG and open that installed app. Do not run from the disk image.
- On an explicitly authorized fictional test library, create and save a book,
  fully quit and relaunch; then replace the installed app and verify the same
  UUID, kind and notes. Record the installed artifact identity.
- Verify About shows 1.2.0 (2), actual bundle minimum is 26.0, both slices
  exist, and no development path, third-party runtime or data is in the bundle.
- A real browser download on a separate Mac is needed to verify its actual
  Gatekeeper/first-approval flow. A local `open` success is not that evidence.
- Intel is unverified until tested on an Intel Mac running supported macOS.

Never open a real user library for testing without explicit permission. Do not
rename/delete a data container or use cleanup/security bypass commands to make
a test pass. A backup is the supported transfer route for differently signed
or differently identified source builds.

## Owner's GitHub Release

After reviewing the current files and verification record, the owner manually
creates a **new** `v1.2.0` tag/Release titled **Book Atlas v1.2.0**.
Do not move, replace or delete `v1.0.0`. Upload **only** the DMG and its
`.dmg.sha256` checksum as custom assets. Use
[RELEASE_NOTES-1.2.0.md](RELEASE_NOTES-1.2.0.md) as the body, omitting its
pre-publication preparation sentence. Replace the relative P12 record link
with a link to that file in the v1.2.0 source snapshot.

Do not upload DerivedData, `.xcresult`, logs, signing keys/certificates,
databases, backups, or the temporary test app. The DMG already contains the
app and install instructions; a ZIP or PKG is unnecessary.

Only after publication should README's prepared/not-published wording change
to the actual release URL/date. Document the real downloaded-artifact checks
separately. [P12](PLANS/PROMPT-12.md) records performed checks and limitations.
