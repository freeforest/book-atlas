# Book Atlas v1.2.0 · 图书志

Published on 2026-09-10: [BookAtlas v1.2.0](https://github.com/freeforest/book-atlas/releases/tag/v1.2.0).

## Download and install / 下载与安装

Download **BookAtlas-1.2.0.dmg** from this Release's Assets. You do not need
Xcode, a compiler, Homebrew, or a developer account.

1. Open the DMG.
2. Drag **BookAtlas.app** into **Applications**.
3. Eject the DMG and launch BookAtlas from Applications.

Supports **Apple Silicon / M-series Macs with macOS 26.0 or newer**. The app
contains arm64 and x86_64 code, but this release does not offer Intel support.
Intel hardware execution has not been verified.

## First launch / 首次打开

This release is **ad-hoc signed, not Apple Developer ID signed or notarized**.
macOS may block it because the developer cannot be verified. Only if you trust
the official release, try opening it once, then use **System Settings →
Privacy & Security → Open Anyway**, and confirm opening. Future launches
normally work by double-clicking; system policies or updates may ask again.

中文路径：尝试打开一次 → **系统设置 → 隐私与安全性 → 安全性 → 仍要打开**。
这是针对单个应用的用户决定，不代表 Apple 已验证开发者或审查过此应用。
若提示恶意软件、文件损坏或受组织策略限制，请停止并反馈，不要强行运行。
Follow [Apple's official instructions](https://support.apple.com/guide/mac-help/mh40616/mac).
Do not disable Gatekeeper or remove quarantine attributes.

## What's included

- A normal macOS App icon, About/version metadata, and drag-to-install DMG.
- P11's accepted manual relationship workflow: create, navigate, cancel and
  confirm relationship deletion, with graph refresh and save-state protection.
- Book kinds (图书 / 文集 / 工具书 / 其他) in editing, details and filters.
- Existing local catalog, search, lists, tags, sources, graph, CSV/Markdown
  portability and full backup/restore.
- Version **1.2.0**, build **2**; stable identifier `io.github.freeforest.BookAtlas`.

## Upgrade and data safety

Before updating, use **数据 → 创建完整备份…**, then quit the old app completely.
Drag the new app into Applications and confirm replacement. Do not use an
uninstaller/cleaner that removes BookAtlas's data container.

The library is stored in sandbox Application Support, outside the `.app` and
DMG. This release retains the Bundle ID, database path and Schema 5. App
replacement does not intentionally remove or relocate a library. Source
builds with a different Bundle ID or sandbox configuration may use a different
container: export a full backup with that old app and restore it through the
new app's UI. Do not move live SQLite files manually.

There is no automatic updater, cloud sync, AI, account, telemetry or application
network client. Backups are unencrypted and must be kept somewhere safe.

## Integrity and limitations

The adjacent `BookAtlas-1.2.0.dmg.sha256` file provides a SHA-256 checksum.
It detects corrupted downloads, not publisher impersonation; use this official
repository's Release, not an unknown mirror.

No macOS 14/15 compatibility, Intel hardware validation, or App Store review is
claimed. A locally created package does not by itself prove first-launch
Gatekeeper behavior after a browser download on another Mac. See the
[P12 verification record](PLANS/PROMPT-12.md) for actual execution and remaining
boundaries. v1.0.0 remains the unchanged historical source-only release.
