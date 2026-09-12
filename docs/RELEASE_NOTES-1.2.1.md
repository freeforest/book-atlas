# Book Atlas 1.2.1

Version **1.2.1 / build 3**。本地准备完成，尚未发布；本文为后续正式发布正文草稿。

## 本次修复

移除书库、书单、标签、书图和设置顶部重复的按钮状中央标题，保留页面标题、
sidebar 选中状态和已有导航与工具栏操作。未改变书库数据结构、Schema 5 或存储位置。

## 安装与首次打开

仅支持 **Apple Silicon / M 系列 Mac，macOS 26.0+**，无需 Xcode 或其他开发环境。
安装包保留 arm64 和 x86_64 代码，但不承诺 Intel 支持。

打开 `BookAtlas-1.2.1.dmg`，将 `BookAtlas.app` 拖入 Applications，推出 DMG，
再从 Applications 启动。对应校验文件为 `BookAtlas-1.2.1.dmg.sha256`。

本版使用 **ad-hoc 签名**，没有 Developer ID 签名或 Apple notarization（公证）。
首次因无法验证开发者而被阻止时，先确认安装包来自官方 Release 且可信，再按
[Apple 官方说明](https://support.apple.com/guide/mac-help/mh40616/mac)，进入
**系统设置 → 隐私与安全性 → 仍要打开**（System Settings → Privacy & Security → Open Anyway）。

不保证所有系统策略下都能放行。如出现“已损坏”、恶意软件警告或组织策略阻止，
请停止并反馈；不要将其当作普通未验证开发者提示处理。不要关闭 Gatekeeper 或删除隔离属性。

## 升级

先使用应用内完整备份，完全退出旧版，再替换 Applications 中的 App；不要删除
应用数据或沙盒容器。Bundle ID 保持 `io.github.freeforest.BookAtlas`。
本机隔离运行不代表真实用户数据库持久性、Intel 实机或其他 Mac 首次下载启动已验证。
