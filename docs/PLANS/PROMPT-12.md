# P12 — BookAtlas v1.2.0 macOS 分发

## 授权与当前状态

2026-09-10，用户正式授权在当前 workspace、当前主代理直接实施。
P11 功能验收不变；用户表示已完成 Git 操作（用户反馈，不等于代理核验工作区）。
当前交付状态：**v1.2.0 已正式发布，公开下载校验通过；仅支持 M 系列 Mac / macOS 26.0+。**
2026-09-10 的 P12-RELEASE-FINAL 专项授权允许本次远端 tag、Release 和资产操作；
本地 Git 及发布后文档同步仍由用户处理，完整待提交范围核对 PENDING。
下方原准备与本地验证记录保留为历史，不代表当前尚未发布；v1.0.0 未修改。

## 范围

- 版本 1.2.0、build 2；保留 `io.github.freeforest.BookAtlas` 和 macOS 26.0。
- 标准 `.app`、图标、About 元数据、arm64/x86_64、本地 ad-hoc 签名。
- 简洁只读 DMG：App、Applications 链接、安装说明及 MIT License。
- 最小本地打包脚本、SHA-256、普通用户安装/升级说明和 Release Notes。
- 默认持久化路径、退出重开与替换安装验证；不重构数据层。

没有 Developer ID 或 Apple notarization，不关闭 Gatekeeper，不移除隔离属性，
不增加联网、自动更新、依赖、Schema、AI、账号或云服务。不执行 Git/gh 或访问
`.git`，不上传发布，不使用其他任务、worktree 或代理。

## 审计结论

本地 core docs、P11B 最终裁决、工程、应用启动、SQLite 路径及现有测试已检查。
只读查看公开 README 和 v1.0.0 Release：旧版为源码发布，零自定义二进制附件。
新授权明确改变未来分发方式，旧版本和历史证据保留。

现有 `BookAtlasDatabaseLocation.defaultURL()` 使用系统 Application Support，
再追加 `BookAtlas/book-atlas.sqlite`；在沙盒下属于稳定 Bundle ID 的容器。
路径不引用 App、安装位置、版本或 DerivedData。Schema 5 无需迁移或重写。
原工程已支持 Release ad-hoc / Hardened Runtime / 三项生产 entitlement，
缺少图标、资源 phase 和 DMG 脚本。About 优先使用系统默认面板及实际 bundle metadata。

## 验证计划

1. 脚本语法、项目 plist、图标视觉及尺寸。
2. 现有持久化/迁移/启动隔离相关定向非 UI；不为包装工作重跑全部历史 UI。
3. 脚本构建实际 Universal Release，检查 Info、签名、权限、架构、动态库；生成并核验 DMG。
4. 已取得本轮交互会话确认；用户确认正式书库为空或仅含测试数据并授权验证。
   先检查安装目标和进程，不覆盖未知安装；仅对已确认测试书库添加虚构数据。
5. 从 DMG 安装到 Applications，观察空库/创建、About、完全退出再启动，
   保留第一次安装副本后替换安装，再核对同一书籍和类型/备注。
6. 记录实际沙盒路径结构、数据库路径与 App 的分离，不将观察扩大为所有旧用户环境。

工具/构建失败先基于证据修复，保存失败结果；不重复运行未改变输入的通过门禁。
未知系统授权或数据安全问题停在对应动作，独立安全工作可继续。
Intel 实机、真实网络下载产生的 Gatekeeper 流程如无实际条件，明确标注未验证。
最终交付 DMG、校验文件、命令、实际结果与剩余限制；Git/上传由用户处理。

## 2026-09-10 实际交付与验证

环境：macOS 26.6.2（25G83）、Apple Silicon MacBook Air、Xcode 26.6
（17F113）、macOS SDK 26.5。实际两架构 LC_BUILD_VERSION 最低均为 26.0。
没有更改生产 Swift 逻辑、Schema、数据库目录、CSV/备份格式、权限或依赖。

产物为 `dist/BookAtlas-1.2.0.dmg`，约 5.5 MiB，及同名 `.dmg.sha256`。
最终交付 DMG SHA-256：

```text
553e23f6c69bb8b4aeac3cc1906dbaa470ae06fc0fab15771a8776cb438c4d12
```

### 构建、包与测试

| 检查 | 实际结果 |
| --- | --- |
| 6 项定向非 UI | 6 passed / 0 failed / 0 skipped / 0 cancelled，xcodebuild exit 0；summary 和完整树解析均 exit 0，六项身份一致 |
| 安装候选 Release | build exit 0；build-results succeeded，错误/结构化警告/分析器警告均 0；原始 AppIntents 元数据提取跳过警告保留 |
| 最终完整脚本独立验证 | `bash Scripts/package_release.sh <NEW_OUTPUT>` 整体 exit 0；生成独立 DMG，不覆盖已做安装验证的 dist 产物；其 build-results 也为 succeeded，原始 AppIntents 警告保留 |
| Bundle | `BookAtlas.app`，版本 1.2.0/build 2，稳定 ID，图标 ICNS、中文本地化、Reference 分类和版权元数据；实际 About 显示“版本1.2.0 (2)”及图像元素 |
| 签名/权限 | strict/deep 验签通过；Signature=adhoc、无 Team ID、Hardened Runtime；两架构仅 sandbox、用户选择文件读写、app-scope bookmark，无网络或 get-task-allow |
| 架构/依赖 | arm64+x86_64；`otool -L` 全部为 `/System/Library` 或 `/usr/lib` 的系统库；无自定义运行时、第三方 dylib、构建目录依赖 |
| DMG | hdiutil verify、SHA-256 校验、只读挂载通过；App、Applications 链接、安装说明及 License；无数据库、日志或开发凭据 |

六项定向身份：

- `MigrationTests/testEveryHistoricalSchemaMigratesToFiveWithAllAvailableDomainData`
- `MigrationTests/testNewDatabaseCreatesLatestSchemaAndRepeatedMigrationIsSafe`
- `MigrationTests/testFailedMigrationRollsBackWithoutRebuildingOrDeletingExistingData`
- `MigrationTests/testFutureSchemaVersionIsRejectedWithoutResettingTheDatabase`
- `LibraryStoreTests/testDefaultApplicationPathStillUsesProvidedTemporaryDatabaseAndRealRelationAccess`
- `BookEditorDraftTests/testBookKindsRoundTripThroughCatalogWithoutLosingFieldsOrRelations`

精确构建命令在 `Scripts/package_release.sh`。定向测试使用：

```sh
xcodebuild test -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath <TEST_EVIDENCE>/DerivedData \
  -resultBundlePath <TEST_EVIDENCE>/targeted.xcresult \
  -only-testing:BookAtlasTests/MigrationTests/testEveryHistoricalSchemaMigratesToFiveWithAllAvailableDomainData \
  -only-testing:BookAtlasTests/MigrationTests/testNewDatabaseCreatesLatestSchemaAndRepeatedMigrationIsSafe \
  -only-testing:BookAtlasTests/MigrationTests/testFailedMigrationRollsBackWithoutRebuildingOrDeletingExistingData \
  -only-testing:BookAtlasTests/MigrationTests/testFutureSchemaVersionIsRejectedWithoutResettingTheDatabase \
  -only-testing:BookAtlasTests/LibraryStoreTests/testDefaultApplicationPathStillUsesProvidedTemporaryDatabaseAndRealRelationAccess \
  -only-testing:BookAtlasTests/BookEditorDraftTests/testBookKindsRoundTripThroughCatalogWithoutLosingFieldsOrRelations
```

分别使用 `xcrun xcresulttool get test-results summary`、`get test-results tests`
解析同一个测试包；Release 使用 `get build-results`。真实本机证据路径见交付报告，
不写入公开文件。完整脚本生成的另一个候选不是对 dist DMG 字节一致性的承诺。

### 实际安装与持久性

用户在本轮确认可交互且不干扰 UI；另确认正式书库为空或仅有测试数据，明确允许
打开、添加虚构书籍。本轮不是默认擅自读取真实私人书库。

1. 打开保留的 P11 Release（元数据 1.0.0/build 1），观察空书库及新增入口。
   创建虚构的 `P12 Mist Harbor Upgrade`，类型工具书，带固定虚构备注。
2. 原生界面控制在保存动作后断开。先只读查询该指定测试记录，确认保存成功，
   没有重复创建。重连仍失败后，用户明确授权本轮改用 AppleScript/System Events。
3. 正常退出旧版，确认进程消失。原 Applications 目标不存在；从只读 DMG 复制
   App 到 Applications，验签及可执行文件/Info 哈希均与 DMG 一致，推出 DMG。
4. 已安装新 App 的窗口显示旧记录、原 UUID、工具书类型及备注。进程打开的
   数据库仍是同一沙盒文件。About 显示 1.2.0 (2)。
5. 在已安装 App 内新建 `P12 New Install Check`（图书），带固定虚构备注。
   观察保存后两行及详情；完全退出后，由 Finder 正常打开，无测试参数，仍显示两行。
6. 再正常退出；先保留安装 App 的可恢复临时副本，再由 Finder 从 DMG **with replacing**
   覆盖 Applications 中的 App。推出 DMG并重新打开，两条 UUID、类型和备注不变。
   可执行文件换成了新 inode，数据库文件 inode 仍相同；SQLite quick_check 返回 ok。
7. 最终 App 的空书库提示另外使用显式内存模式观察，不与上面的默认持久化证据混用。
   首次读取尚无可观察窗口，不计通过；发出标准 reopen 并等待实际窗口后，观察到
   “书库尚无内容”、说明和新增入口。随后恢复普通 Finder 启动的持久书库。

上述是本机实际界面自动操作和读回证据，不冒称用户亲手完成的人工验收。
旧版起点是保留的 P11 本地 Release，**不是重新构建不可变 v1.0.0 tag**。

实际数据库路径的稳定部分为：

```text
~/Library/Containers/io.github.freeforest.BookAtlas/Data/Library/Application Support/BookAtlas/book-atlas.sqlite
```

路径与 `.app`、DMG、DerivedData、安装位置和版本号独立。没有搬迁、替换或删除数据库。
两本新建的虚构验证书籍保留在用户已授权的测试书库中，未自动删除。

### 保留的失败与边界

- 图标生成首次 Swift 模块缓存不可写；改用任务临时模块缓存。iconutil 在受限沙盒内
  报 Invalid Iconset，输入 PNG 尺寸/格式核验正常；同一图标输入获得系统工具权限后成功。
- 首轮 Release build 成功，但自动 Info.plist 未包含 icon key，lipo 校验参数顺序也有误。
  增加显式 Info.plist、修正校验命令后重新构建；首轮不是可发布候选。
- 修正后的受限打包在 hdiutil 报“设备未配置”停止；仅授权系统磁盘工具后从同一暂存
  产物继续生成当前 dist DMG。后续最终脚本在所需权限下独立全程 exit 0。
- 首轮测试因 testmanagerd sandbox restriction 在运行所选方法前失败（exit 65）。
  summary 为 1 total / 0 passed / 1 failed / 0 skipped；完整树中唯一节点是
  `System Failures / BookAtlas encountered an error`，不是六个业务测试之一。
  因此业务方法实际执行数为 0，不把结构化摘要写成 0 failure。
  同时发现一个选择器误含目录 `Features`，尚未执行，获权限后以正确六项身份运行通过。
  解析首次受 TestReport 缓存权限阻止（64），获得权限后仅解析同包，不重跑测试。
- `spctl --assess --type execute --verbose=4` 对安装 App 返回 rejected/exit 3，符合
  ad-hoc 未公证的已接受限制。未添加安全例外、关闭 Gatekeeper 或移除隔离属性。
- 本地启动不是另一台 Mac 的浏览器下载/首次 Gatekeeper 操作证明；该路径仍需用户或
  客户实测。Intel 实机、不同源构建身份/沙盒、长期本地文件 bookmark 重新授权未验证。
- 全套历史 UI/非 UI 未重跑，P11 的分轮计数不改写。未重新审计完整 Git 待提交范围。

### 最终元数据复核

按 [Apple 的 macOS 分类列表](https://developer.apple.com/documentation/bundleresources/information-property-list/lsapplicationcategorytype)
把分类从初始候选的 `public.app-category.books` 修正为正式定义的
`public.app-category.reference`，并将此断言加入打包脚本。业务源码和六项测试未变。
最终脚本在全新目录整体 exit 0，最终 Release 结构化解析 exit 0/succeeded；
原始 AppIntents 跳过警告仍保留。对最终 DMG 再次验签/校验、Finder 覆盖安装、
推出 DMG、正常启动及退出重开，仍显示原来的两条 UUID、类型和备注。
这才是上方列出的最终 SHA-256 对应产物。

旧 DMG（SHA-256 `e21152d1…e9220`）及校验文件被移至任务临时目录保留，未覆盖其证据。
六项非 UI 的构建早于这项纯分类元数据修正，不冒称最终配置重跑六项。
P11 保存的 9 个直接相关 Swift/测试文件与当前逐字节校验一致；工程配置是本阶段
授权修改，不纳入该不变声明。此局部校验仍不等于 Git 待提交范围审计。

结论：本地 App、DMG 和安装/重开/覆盖安装的数据持久性检查通过，所述限制保留。
发行文件和普通用户文档已准备；发布前由用户核对本次变更并创建新的 v1.2.0 Release。

## 2026-09-10 P12-RELEASE-FINAL：正式发布

**PUBLISHED**。发布时间为 2026-09-10 08:17:55 UTC。用户专项授权本次远端
创建 tag、草稿、上传两个资产并正式发布；未执行本地 Git 或访问 `.git`。
未修改 v1.0.0、历史 tag、权限或 Secrets，未构建、测试、启动或安装应用。

- [正式 Release](https://github.com/freeforest/book-atlas/releases/tag/v1.2.0)，
  标题 `BookAtlas v1.2.0`，非 Draft、非 Pre-release；此前只有 v1.0.0，设置为 Latest。
- tag `v1.2.0` 指向完整提交 `7c324d82dbb6a4f65b2aafceabbddd942050c97b`。
- [BookAtlas-1.2.0.dmg](https://github.com/freeforest/book-atlas/releases/download/v1.2.0/BookAtlas-1.2.0.dmg)，5,751,239 bytes。
- [校验文件](https://github.com/freeforest/book-atlas/releases/download/v1.2.0/BookAtlas-1.2.0.dmg.sha256)，86 bytes。
- DMG SHA-256：`553e23f6c69bb8b4aeac3cc1906dbaa470ae06fc0fab15771a8776cb438c4d12`。
- 版本 1.2.0 / build 2，Bundle ID `io.github.freeforest.BookAtlas`。

### 本轮最小核验

从上述不可变提交下载公开源码快照，46 个应用源码、工程、资源和打包输入逐文件
`cmp` 与本地一致；保留构建的 36 个应用 Swift 输入身份也一致。相关输入修改时间
均不晚于最终构建开始；保留的最终构建结果为 exit 0，本轮 build-results 只读解析
exit 0 / succeeded / 0 errors / 0 structured warnings。原始 AppIntents 跳过警告保留。
最终包装暂存的安装说明、License、图标与输入逐字节一致，dist DMG 与该最终包装
DMG 逐字节一致。结合既有最终元数据、签名及安装记录建立本次发行输入对应关系；
不声称重建可复现或完整历史/待提交范围审计。

首次受限网络 POST 在连接代理前被沙盒拒绝；随后先查询确认 tag 仍不存在（404），
获所需网络执行权限后才创建。草稿按 tag 查询返回 404，改用 Release 列表核验同一
草稿，未重复创建。创建、上传及发布操作均 exit 0，两资产 state=uploaded，GitHub
摘要与本地一致，无覆盖操作。

发布后使用不带认证的 `curl --fail --location` 读取公开页面、Release API 和 tag，
并将两个资产重新下载至独立 `<PUBLISH_EVIDENCE>/download/`；命令完成 exit 0。
公开 API 确认 draft=false、prerelease=false、tag 提交与资产名称/大小正确；
`shasum -a 256 -c BookAtlas-1.2.0.dmg.sha256` 及与本地两个文件的 `cmp` 均成功。
这是公开下载交付核验，不是另一台 Mac 的 Gatekeeper 或首次启动验证。

### 支持与剩余事项

仅支持 **Apple Silicon / M 系列 Mac，macOS 26.0+**。安装包保留 arm64+x86_64，
不是 arm64-only，也不承诺 Intel 支持。ad-hoc 签名，无 Developer ID/Apple 公证；
其他设备首次下载和启动反馈尚未收集，Intel 实机运行未验证，均为本次已接受限制。
首次启动按 Apple 官方“隐私与安全性 → 仍要打开”流程，不绕过系统保护。

本轮发布后文档修改尚未同步远端，交用户手动 Git；完整待提交范围核对仍 PENDING。
本地文档未提交不改变安装包已公开发布的事实。既有真实用户数据、历史版本和
跨设备验证边界保留；不把 P11 分轮证据合并成单轮完整通过，不启动下一功能阶段。
