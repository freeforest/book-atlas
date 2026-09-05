# Milestone 6 — 手动关系用户闭环

## Goal

让用户在一本书的详情中，以本地、明确、可撤销的方式查看、新建、导航和删除手动书籍关系，同时保持现有 Schema 5、备份格式、合并规则和有界图谱语义不变。

## Stage

- **Prompt 11A：手动书籍关系用户闭环。** 当前状态：`BLOCKED — WAITING FOR CONTROLLER REVIEW`。
- Prompt 11A 的本地实现、测试或报告都不是主控验收；运行专区不得自行宣布本阶段通过。
- **Prompt 11B：BookKind 与详情完整性。** 尚未授权，本轮不得开始或预留实现。

## Scope

- 在书籍详情中分别呈现传出与传入关系，并显示对端书名、作者、关系类型、方向和可选备注。
- 从当前详情创建以当前书籍为 source 的关系：按标题、作者或 ISBN 使用 `LibraryQuery` 做确定性分页搜索，排除当前书籍，清楚预览方向后保存。
- 提交前可取消且不写入；提交处理中不可取消，直到写入结果明确。关闭视图或取消调用 Task 不是已提交数据库写入的撤销。
- 通过对端 UUID 复用现有精确聚焦导航；保留分页外目标和筛选排除目标的既有语义，不替换成第一行。
- 删除关系前明确确认；只删除关系记录，并在成功后刷新详情关系和局部书图 revision。
- 使用独立、按 `bookID` 绑定的关系 feature store；切换书籍立即清空旧快照，取消旧请求，并以 generation 与 `bookID` 拒绝迟到结果。
- Catalog 层提供面向 UI 的关系读取能力；SwiftUI 不直接访问 Repository 或 SQL。
- 使用固定虚构数据补充 Repository、Catalog、Store、Graph、合并、备份恢复、级联删除和 XCUI 回归。

## Non-goals

- 不编辑既有关系类型或备注，不批量操作关系。
- 不实现或预留 BookKind 编辑、显示或筛选。
- 不改变 CSV、备份格式、Schema 5、迁移、图谱边界或持久化框架。
- 不增加 AI、推荐、自动元数据、网络、云同步、账号、协作、遥测、广告或其他平台客户端。
- 不增加依赖、权限或 entitlement，不进行无关重构。
- 不提交、推送、建分支、打标签、发布 Release，也不修改 V1.0.0 版本元数据或历史证据。

## Gates

1. 新增领域、Repository、Catalog 与关系 Store 定向测试通过。
2. 现有关系、合并、备份恢复、删除级联和图谱定向回归通过。
3. 新 `/tmp` DerivedData 下 Debug 构建成功。
4. 完整非 UI 套件完整执行，测试数不少于 200，且 0 failure、0 skip；必须解析完整 xcresult。
5. 新增关系 XCUI 定向测试实际初始化 XCUIAutomation 并通过。
6. 完整 UI 套件完整执行，测试数不少于 41，且 0 failure、0 skip；必须解析完整 xcresult。
7. 新 `/tmp` DerivedData 下 Release 构建成功。
8. Schema 仍为 5；依赖、网络 entitlement 与 Release entitlement 未扩大；由用户手动执行的 `git diff --check` 和另行授权的隐私/产物扫描通过。
9. 固定虚构、内存数据库 Debug 应用完成一次真实鼠标与键盘检查。

产品断言失败必须先定位和修复。Xcode/XCUI 基础设施失败只允许使用全新 `/tmp` 路径干净重试一次；同一基础设施错误连续两次即 `BLOCKED`。不完整 xcresult、零测试或仅构建成功不计为测试通过。

## Local verification status

截至 2026-09-05，Prompt 11A 整体仍为 `BLOCKED`，未获得主控验收。

此前记录的新增定向 10/10、既有回归 10/10、Debug、完整非 UI 209/209
（`/tmp/bookatlas-p11a-final-g4-nonui-34.xcresult`）和定向 UI 3/3
（`/tmp/bookatlas-p11a-final-g5-targeted-ui-35.xcresult`）是窄修复前的历史证据，
本轮未重新复核这些旧包，不能作为修改后代码的验证结果。

### Prompt 11A-SAVE-LIFECYCLE-01

本轮仅授权保存生命周期窄修复和两个既有 UI 失败包的只读复核。
未恢复完整 UI 门禁，不运行任何新 UI、Release 或人工界面检查，不委派任务。
所有 Git/GitHub 操作（包括只读命令及 `.git` 访问）由用户手动接管。

修复前，受控异步写入进入后 `cancelCreate()` 可清空正在提交的编辑器并错误声称
“书库未更改”；再次保存可进入第二次写入；草稿操作可替换提交状态；成功后的刷新
只检查书籍 UUID，能向同一本书的新草稿发布旧提示。未知写入错误也被错误解释为未写入。
四项回归在生产代码修改前只执行一次，全部复现失败，共 16 个断言失败，不计为通过门禁。

本轮变更：

- `ManualRelationStore.swift`：Store 自身拒绝保存重入、保存中取消/重新打开/目标搜索和草稿修改；提交时取消并隔离迟到目标分页。增加局部草稿 generation，与既有 bookID/load generation 一起约束写入完成和后续刷新发布。失败保留草稿并恢复编辑/取消；未知失败及提交后的关闭不宣称数据库未更改。
- `BookDetailView.swift`：编辑器控件共用 `isSaving` 禁用状态，sheet 使用同一状态阻止交互关闭，绑定回写继续经过 Store 保护；沿用唯一取消快捷键，无新 Escape 监视器。显示处理中暂不能取消的忙碌提示。
- `ManualRelationStoreTests.swift`：新增 8 项受控 continuation 握手测试，覆盖提交前取消、悬挂取消/重入/草稿冻结、成功一次创建及刷新、失败恢复、调用 Task 取消、切书/reset/同书新上下文和迟到刷新。只使用固定虚构数据与内存 Repository，不以 sleep 或偶然调度复现。
- 文档仅同步本计划、`DEVELOPMENT.md`、`PRODUCT.md` 和 `CHANGELOG.md` 的当前段落。未修改 UI 测试或通用输入辅助函数；未修改 Schema、CSV、备份、依赖、entitlement、版本配置或 V1.0.0 历史。

结果路径公共前缀：`/tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/`。

| 顺序 / 状态 | 实际测试总数 / passed / failed / skipped | xcodebuild 进程退出码 | 结果包（公共前缀下） | 结构化解析退出码 |
| --- | --- | --- | --- | --- |
| 修复前复现：预期失败，不计通过 | 4 / 0 / 4 / 0 | 65 | `repro.xcresult` | 摘要最终 0、测试树 0 |
| 修复后 Store 定向：VERIFIED | 12 / 12 / 0 / 0 | 0 | `targeted.xcresult` | 摘要 0、测试树 0 |
| 完整 BookAtlasTests：VERIFIED | 217 / 217 / 0 / 0 | 0 | `full-nonui.xcresult` | 摘要 0、测试树 0 |
| Debug 构建：VERIFIED | 不适用，未运行测试 | 0 | `debug-build.xcresult` | build-results 0，`succeeded` |

三个测试包均完成摘要与全部测试树解析并一致；本轮完整非 UI 只有
`BookAtlasTests` bundle。定向修复后一次通过，未使用修正重跑机会；完整非 UI
和 Debug 各一轮。复现包第一次摘要解析因沙盒阻止 TestReport 缓存写入退出 64，
获准进行同一结果包的解析后退出 0；这不是 xcodebuild 退出码，也没有重跑复现测试。

以下为实际执行记录，不是新的运行授权；这些证据路径已经存在，不得覆盖重跑。
工作目录为项目根目录，shell 为 zsh；`pipefail` 用于保留管道失败。

```sh
set -o pipefail
xcodebuild test -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/repro-dd -resultBundlePath /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/repro.xcresult -only-testing:BookAtlasTests/ManualRelationStoreTests/testSuspendedSaveRejectsCancellationAndDraftMutation -only-testing:BookAtlasTests/ManualRelationStoreTests/testSuspendedSaveRejectsDuplicateSubmissionAtStoreBoundary -only-testing:BookAtlasTests/ManualRelationStoreTests/testLateSaveRefreshCannotPublishIntoSameBookNewDraft -only-testing:BookAtlasTests/ManualRelationStoreTests/testFailedWritePreservesDraftAndRestoresEditingAndCancellation | tee /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/repro.log

set -o pipefail
xcodebuild test -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/targeted-dd -resultBundlePath /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/targeted.xcresult -only-testing:BookAtlasTests/ManualRelationStoreTests | tee /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/targeted.log

set -o pipefail
xcodebuild test -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/full-nonui-dd -resultBundlePath /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/full-nonui.xcresult -only-testing:BookAtlasTests | tee /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/full-nonui.log
bookatlas_test_exit=$pipestatus[1]
printf 'XCODEBUILD_EXIT_CODE=%s\n' "$bookatlas_test_exit"
exit "$bookatlas_test_exit"

set -o pipefail
xcodebuild build -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/debug-build-dd -resultBundlePath /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/debug-build.xcresult | tee /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/debug-build.log
bookatlas_build_exit=$pipestatus[1]
printf 'XCODEBUILD_EXIT_CODE=%s\n' "$bookatlas_build_exit"
exit "$bookatlas_build_exit"
```

各段在独立命令会话中执行。解析命令为：

```sh
xcrun xcresulttool get test-results summary --path /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/repro.xcresult --format json
xcrun xcresulttool get test-results tests --path /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/repro.xcresult --compact
xcrun xcresulttool get test-results summary --path /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/targeted.xcresult --compact
xcrun xcresulttool get test-results tests --path /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/targeted.xcresult --compact
xcrun xcresulttool get test-results summary --path /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/full-nonui.xcresult --compact
xcrun xcresulttool get test-results tests --path /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/full-nonui.xcresult --compact
xcrun xcresulttool get build-results --path /tmp/bookatlas-p11a-save-lifecycle-01.8Ne14O/debug-build.xcresult --compact
```

### Existing UI evidence — read-only reassessment

| 原始结果包 | 总数 / passed / failed / skipped | 原测试进程退出码 | 本轮 summary / tests 解析退出码 | 结论 |
| --- | --- | --- | --- | --- |
| `/tmp/bookatlas-p11a-final-g6-full-ui-36.xcresult` | 44 / 31 / 13 / 0 | UNKNOWN，现有记录未保留可靠终态退出码 | 0 / 0 | 完整收集但失败，非通过 |
| `/tmp/bookatlas-p11a-final-g6-full-ui-retry-37.xcresult` | 5 / 1 / 4 / 0 | 历史运行记录为 73，不是本轮解析码 | 0 / 0 | **可解析的中断运行，完整门禁未完成**；4 个 failed 中包含 1 项 `Testing was canceled` |

此前“结果日志未完整封装”的运行提示不等于当前不能解析；不得再写为不可解析，
也不能因为可以解析而称完整 UI 通过。原始结果包未覆盖或删除。
以下时间均为 Asia/Shanghai（UTC+08:00），仅查询对应测试的细节及必要活动日志，
不输出整份 AX 树，不扫描系统日志。

| 现象 / 具体测试 | VERIFIED：事实与时间 | 推断及 UNKNOWN | 所需用户操作（需后续授权，本轮未执行） |
| --- | --- | --- | --- |
| 36：`testPerformanceSustainedListScrollingWithTenThousandBooks` | 09-04 22:13:26.079 开始；22:18:54.145 获取 snapshot 时报告 `Lost connection to the application`，测试树指向 UI 测试第 1802 行 | 连接中断是事实；应用崩溃、退出、挂起或测试服务故障均未证实，根因 UNKNOWN | 如追因，由用户提供该时间窗中明确选定的应用/测试宿主诊断，不扫描私人目录或无关系统日志 |
| 36：其后 12 项，首项 `testReadingEntryAppleBooksCopyAndLocalFileFailureUseTestDoubles`，末项 `testZeroResultSearchShowsFocusedIssueAndClearRecoversLibrary` | 测试树中 12 项均报告 `Not authorized for performing UI testing actions`；首项错误 22:18:55.793，末项 22:19:11.625 | 只能确认时间上后于连接中断；不能认定系统权限被撤销或同一根因，UNKNOWN | 后续由用户只读确认会话是否解锁、Xcode/测试宿主授权提示或设置是否变化；当前设置不能证明故障时状态，不自动重置权限 |
| 37：`testAuthorOnlyMouseSaveShowsVisibleTitleErrorAndPreservesDraft` | 09-05 15:37:55.523 开始输入；15:38:00.628 精确断言实际 `Manual AcceptanceAuthor`，预期 `Manual Acceptance Author`；第 115、129、145 行记录不一致 | 缺少空格的输入值事实已确认；输入事件丢失、焦点、输入法、应用处理或测试宿主原因 UNKNOWN；不是缺少输入后校验 | 后续授权后仅记录前台应用、焦点与输入法；任何人工输入检查只能使用获准的虚构内存界面，不循环重输或改用剪贴板 |
| 37：`testCommandFFocusesLibrarySearchFromAnotherSection` | 15:38:37.916 发出 `A101` 输入；15:38:41.537 第 598 行精确断言实际 `A01`；第 603 行结果等待亦失败 | 缺少字符 `1` 已确认；与作者用例或 36 的共同根因 UNKNOWN；原代码已有精确输入值断言 | 同上；不加 sleep、超时或放宽断言，不自行增加测试预算 |
| 37：`testCreateCollectionAndSourceWithKeyboardNavigation` | 15:39:05.368 第 634 行 `XCTAssertTrue` 失败，对应等待 `North Shelf` 行出现 | 仅证实预期行未在断言等待内出现；不能从此推定也丢字符，根因 UNKNOWN | 是否开展该断言的进一步窄诊断由主控决定 |
| 37：`testCreateEditCancelAndSaveWithKeyboardCommands` | 15:39:24.665 开始；15:39:38.201 活动记录 `Testing was canceled`，计入 failed 而非 skipped | 中断是事实；历史运行记录显示运行方发出了取消，不把它当成产品断言失败或已证明的共同基础设施故障 | 保留中断证据，后续验证范围和预算由主控重新授权 |

原代码作者输入 `value == expectedAuthor` 和 Command-F 输入
`value == expectedSearchText` 的精确值校验与结果包行号相符。
部分详情包含主线程或 QoS runtime warning，仅是伴随警告，不构成上述根因证明。

只读汇总命令（均 exit 0）：

```sh
xcrun xcresulttool get test-results summary --path /tmp/bookatlas-p11a-final-g6-full-ui-36.xcresult --format json
xcrun xcresulttool get test-results tests --path /tmp/bookatlas-p11a-final-g6-full-ui-36.xcresult --compact
xcrun xcresulttool get test-results summary --path /tmp/bookatlas-p11a-final-g6-full-ui-retry-37.xcresult --format json
xcrun xcresulttool get test-results tests --path /tmp/bookatlas-p11a-final-g6-full-ui-retry-37.xcresult --compact
```

表中具体测试使用完整 `BookAtlasUITests/<testName>()` 作为 `--test-id`，分别查询
`xcrun xcresulttool get test-results test-details --path <对应结果包> --test-id '<完整 ID>'`
和 `xcrun xcresulttool get test-results activities --path <对应结果包> --test-id '<完整 ID>' --compact`。
详情查询覆盖首个连接/授权错误及 37 的四个失败测试；末个授权错误补查 activities。
所有这些解析退出码为 0。活动输出只提取时间和短的输入/失败事件，未输出整份 AX 树。

### Remaining gaps and manual handoff

- `UNTESTED`：修改后界面忙碌状态、取消快捷键/Escape、sheet dismissal 的实际运行；Release 与真实鼠标/键盘检查。本轮源码/非 UI 证据不替代这些运行门禁。
- `BLOCKED`：完整 UI 门禁。未重跑、拆批替代、跳过断言或恢复耗尽的 UI 预算。
- `NOT VERIFIED`：最终 Schema/依赖/entitlement 配置核验和隐私/产物审计，需后续独立授权；本轮编辑范围没有触及这些配置。
- Git 来源：此前报告中的 status 和 diff-check 结果标记为 **执行来源待确认**，并未确认由用户手动执行，不能标为 `USER-PROVIDED`。本轮未补跑任何 Git/gh 命令，未访问 `.git`；当前工作区状态、完整未提交列表及 diff-check 由用户手动检查后提供。
- 本轮未 commit、push、切分支、stash、回退、tag、发布或修改 GitHub 状态。窄修复完成，等待主控复核；Prompt 11A 仍 `BLOCKED`。

## Exit condition

运行专区完成实现与可取得的证据收集，按 Prompt 11A 格式报告并停止。只有主控区可以决定如何解除阻断、验收 Prompt 11A 或授权 Prompt 11B；在此之前本计划保持 `BLOCKED — WAITING FOR CONTROLLER REVIEW`。

## 2026-09-05 — ACCEPTANCE-RECOVERY-01：有限恢复证据

- 本轮仅一次 Release 构建、只读配置/隐私范围核验及获用户明确确认后的 U1/U2/U3 各一次探针；没有修改生产代码、测试、辅助函数、工程配置或系统设置。主控提供的 Store 12/12、非 UI 217/217 与 Debug 通过裁决不等于完整 Prompt 11A 验收；本轮没有重跑完整非 UI。
- 63 个生产/测试 Swift、entitlement、工程与共享 scheme 文件的 SHA-256 清单在构建前、Release 后、U1 前及每批后完全一致；清单摘要为 `bb3bdbc69e5aea8c2da59f029d12e6f83a51baccd1c1b9e2a2ab3b3e4f2df82d`。它不是完整待提交范围审计。
- 本地 Release：xcodebuild 真实退出码 0；build-results 解析退出码 0，status succeeded、errorCount 0、warningCount 0、analyzerWarningCount 0。原始构建日志另有 AppIntents 元数据提取跳过警告（无 AppIntents.framework 依赖），不得混同为日志完全无警告。产物含 x86_64 与 arm64；本机/目的地为 arm64，Intel Mac 运行 `NOT VERIFIED`。本轮不 archive、不发布。

| 探针 | 实际执行 / passed / failed / skipped | 测试进程退出码 | summary / tests 解析退出码 | 结果包 |
| --- | --- | --- | --- | --- |
| U1 输入与集合操作 | 3 / 3 / 0 / 0 | 0 | 0 / 0 | `<EVIDENCE_DIR>/U1.xcresult` |
| U2 既有手动关系 UI | 3 / 3 / 0 / 0 | 0 | 0 / 0 | `<EVIDENCE_DIR>/U2.xcresult` |
| U3 万本滚动与普通 AX | 2 / 2 / 0 / 0 | 0 | 0 / 0 | `<EVIDENCE_DIR>/U3.xcresult` |

- 完整摘要与测试树确认各批只包含授权用例，XCUI 实际运行，无重试、取消或追加用例；具体测试身份与命令见 DEVELOPMENT 本轮追加段。不得拼成完整 UI 通过。
- U3 活动顺序（UTC+08）：滚动测试 Start Test 16:57:30.759，Tear Down 17:03:10.168；普通测试 Start Test 17:03:11.073，书籍行 StaticText 查找 17:03:18.369。本次证明滚动测试之后普通 AX 访问成功，不宣称同一应用进程持续存活或旧根因修复。原有万本数据量、15 页/3000 已加载行、滚动负载及三次测量未调整；不是性能平滑度验收。
- 用户确认已解锁本地会话、期间不操作输入/切换应用且无其他 UI 自动化。只读环境采样：U1 前为 Codex / ABC；U2 前为 Codex / SCIM.ITABC；U3 前为 Codex / ABC。没有自动切换输入法；采样间变化原因 `UNKNOWN`，采样不能证明全程状态，更不能反推历史故障环境。
- 当前配置 `VERIFIED`：Schema 最新版本 5、迁移注册 1–5；CSV `bookatlas-csv/1` 的 16 字段不携带手动关系；备份格式 1 使用既有 SQLite 快照与四字段 manifest。生产项目无 Swift 包引用，显式链接 SQLite，实际产物仅 Apple/系统依赖。声明及两个 Release 架构的实际 entitlement 均仅 sandbox、用户选择文件读写、app-scope bookmark；无网络 entitlement。版本 1.0.0 / build 1，adhoc 本地签名并开启 hardened runtime，严格签名核验退出 0。
- 当前源码的已知主动联网/日志 API 模式扫描未发现实现匹配；已检查本地 Data 读取与用户主动 NSWorkspace 打开入口。不能从有限静态扫描推导绝对无联网或隐私风险。与历史版本、Schema/格式实现、权限及 V1.0.0 标签的逐字节无变化结论均 `NOT VERIFIED`，本轮未访问历史 Git 状态。
- 排除 `.git` 的项目元数据清单共 194 项、0 符号链接；范围内未发现数据库、备份、日志、证书、密钥、xcresult 或 app/archive 产物候选。发现四个 `.DS_Store` 和实验目录 `.build` 空缓存目录及锁文件：仅核验元数据，未读取内容、未删除；不得交付，最终是否进入待提交范围由用户核对。现有 ignore 规则不是未跟踪/未暂存证明。
- 已知源码/文档/配置/固定虚构样本的敏感模式扫描未发现实际凭据或机器专属 home 路径；路径匹配为脱敏表达式及固定虚构测试。没有读取真实书库、未知私人文件或项目外私人目录。完整待提交内容审计 `PENDING`。
- `UNTESTED`：保存忙碌态的专项原生 UI（保存中禁用、Escape、sheet dismissal）、真实鼠标键盘人工检查。完整 UI 门禁仍 `BLOCKED`；旧应用连接中断、后续授权错误、丢字符和取消的根因继续分别保留 `UNKNOWN`，本次通过不能将其归并或宣称修复。
- Git 全部由用户手动接管。本轮未执行 git/gh、未访问 `.git`；此前 status/diff-check 的执行来源仍待确认，不能标成 USER-PROVIDED。用户尚未提供新的完整变更清单、status 和 diff-check，均 `PENDING`；未 commit、push、tag 或发布。
- **Release 与有限 UI 恢复探针完成，等待主控决定后续验收；Prompt 11A 尚未完成整体验收，整体仍 BLOCKED。** 本轮停止，不启动 Prompt 11B。

## 2026-09-05 — BUSY-UI-AND-FULL-GATE-01（BLOCKED）

本轮授权最小 Debug 内存测试替身及一个原生忙碌态 UI 用例，保留原有 44 项 UI 身份和 12 项 ManualRelationStore 测试。仅 LibraryStore 的测试注入/启动隔离、BookDetailView 的稳定标识、LibraryStoreTests、BookAtlasUITests 及本计划/DEVELOPMENT 在修改范围内。不修复生产缺陷，不改保存语义、工程、Schema、格式、依赖、权限或版本。

验证顺序：Store 定向（源码/单元问题最多一次有证据修正）；冻结代码后一次完整非 UI；取得本轮新会话确认后一次 4 项关系 UI；通过且同一冻结状态后一次完整 UI（原 44 项加新 1 项）；通过后同状态一次 Release 与增量核验。UI 不重跑、不拆批替代完整门禁、不改变性能负载。后续阶段以实际前置结果为准，尚未执行的门禁不是通过。真实人工 UI、完整待提交范围和 Git 操作仍由用户接管；不清理未知文件、不启动 Prompt 11B。

### 本轮停止证据

- 定向非 UI 一次运行：44 executed、43 passed、1 failed、0 skipped；原始 xcodebuild exit 65，summary 和完整 tests 解析各 exit 0。ManualRelationStoreTests 原有 12 项全部通过；LibraryStoreTests 32 项中 31 通过、1 失败。不是通过门禁。
- 失败身份：`LibraryStoreTests/testSuspendedRelationSwitchAllowsOnlyExplicitMemoryFixture()`。合法显式内存参数返回 databaseUnavailable，选中书籍为 nil、关系状态为 idle；三个断言失败归于同一测试。
- 根因 `VERIFIED`：当前工程 Debug 配置未定义 Swift `DEBUG` 条件，实际 BookAtlas 与 BookAtlasTests 的 SwiftDriver 命令也没有 `-D DEBUG`。因此 `#if DEBUG` 替身和新增握手测试没有进入此次编译；新增有效入口进入 `#if !DEBUG` 拒绝分支。源码新增四项单元测试，但实际只发现三项，不能把未编译的握手用例算为 passed 或 skipped。
- 要满足明确要求的 `#if DEBUG` 测试替身，需要另外授权 Debug 编译条件（覆盖应用与相关测试，Release 保持不定义）。工程配置不在本轮范围内；未用命令行宏绕过边界，未修改工程，未使用一次修正重跑额度。保留局部修改，等待主控决定扩展范围和后续预算。
- 原有 44 项 UI 身份全部保留，源码增加 `testManualRelationSubmittedSaveDisablesEditingCancelAndEscape` 后为 45 项。没有运行任何 UI，也未重复 U1–U3；忙碌状态仍 `UNTESTED`。新增界面代码仅为 ProgressView 的 accessibility identifier。
- 测试支撑设计：LibraryStore 可注入 ManualRelationStore；专用开关须显式内存参数且排除性能命令；无效组合在文件库解析前拒绝，Release 拒绝该开关。Debug actor 使用每实例 AsyncStream 等待，正常保存才进入 add，绝不转发写入；显式 finish 或调用任务取消均以错误结束，UI 测试结束仅终止其虚构内存进程，不宣称取消真实写入。该 actor 因上述条件未被编译，其运行行为 `UNTESTED`。
- 63 文件前后清单仅四个授权源码/测试文件变化；ManualRelationStore 及其 12 项测试、工程/scheme、entitlement 保持原校验值。测试后无源码修改；当前清单摘要 `5c7b60de79a478abf60b263745e077d659bfea9cb1cca62f50d25d4f20f8d723`，不是阶段 2 已冻结/通过的证明。
- 完整非 UI、4 项关系 UI、完整 UI、Release 和增量产物审计：**未执行，因阶段 1 未通过并需范围扩展**。本次 Debug 测试构建成功只能证明实际编译部分，不能证明被条件排除的替身。
- 日志及结果包采用新的 `<EVIDENCE_DIR>/targeted.log`、`targeted.xcresult`，精确本机路径留在本地交付；命令见 DEVELOPMENT。旧证据保留，不复查旧故障根因。Git/完整待提交范围仍 PENDING；本轮无 git/gh、无 `.git` 访问、无提交或发布。Prompt 11A 整体仍 BLOCKED，停止等待主控。

## 2026-09-05 — DEBUG-CONDITION-AND-GATE-CONTINUE-01（BLOCKED）

- 本轮仅在 PBXProject Debug `BA0000000000000000000401` 插入 `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) DEBUG";`。生产/测试源码和断言、Release 配置、scheme、签名、权限、版本等未修改；另仅追加两份授权文档。
- 修改前 63 文件与上轮 after 清单一致；条件扫描仅发现已知等待替身、启动隔离和握手测试。工程 plutil 检查 exit 0，普通字节比较确认仅一项插入。修改前后各一次 Debug/Release 全目标 showBuildSettings 均 exit 0：三个唯一目标 Debug 均继承 DEBUG，且只有该设置变化；Release 均不含 DEBUG，其他配置无差异。
- 实际 SwiftDriver 命令确认应用、单元测试及 UI 测试目标均带 `-DDEBUG`（等价于 `-D DEBUG`），未通过命令行或环境临时注入。配置修正已生效。
- 唯一一次 Store 定向修正运行完整结束：**45 executed、44 passed、1 failed、0 skipped**，原始进程 **exit 65**；summary 和完整 tests 解析各 **exit 0**。ManualRelationStoreTests 12/12，LibraryStoreTests 32/33。新增四项均实际发现并执行，尤其握手 `testSuspendedRelationAccessHandshakeReleaseAndCancellationNeverWrite` 已通过。旧 44/43/1 失败包及其 exit 65 原样保留。
- 唯一失败为 `testSuspendedRelationSwitchAllowsOnlyExplicitMemoryFixture` 第 44 行：关系状态 idle，预期 content。书库 content、固定 UUID 和不访问生产路径的断言本次未失败。只读源码表明关系加载由 BookDetailView `.task(id:)` 触发；该单元测试仅构造 Store 并等待已有任务，未挂载详情或显式调用关系 load，故断言缺少生命周期前置。不据此认定新的生产保存缺陷。未修改测试或再次运行。
- 配置修正加本次运行已消耗剩余唯一一次修正重跑额度。**完整非 UI、4 项关系 UI、完整 UI、Release 与增量产物审计均未执行，因定向前置未通过**，不是测试跳过计数。没有启动 UI 或沿用旧会话确认。
- 测试对应 63 文件清单摘要 `d523ef061aadcb6ba69df83f3021fbf4415467b9aa164ed609b479b33362abbc`，测试后全数一致；本轮只有工程该项变化。阶段 2 的通过后冻结尚未发生，不能将此失败运行当成最终门禁证据。
- 忙碌态原生 UI 仍 UNTESTED；Release 实际编译、替身排除、两架构产物权限仍 NOT VERIFIED，本轮静态 Release 设置核验不能替代构建。Intel 实机 NOT VERIFIED；真实人工检查、Git 和完整待提交范围 PENDING。旧 UI 根因分别 UNKNOWN，本轮不追查。
- 命令与证据位置见 DEVELOPMENT 追加记录及临时交付文件。无 git/gh、无 `.git` 访问、无清理、系统调整、提交或发布。**Prompt 11A 仍 BLOCKED，停止等待主控；不开始 Prompt 11B。**

## 2026-09-05 — TEST-LIFECYCLE-AND-GATE-CONTINUE-01：等待本轮 UI 会话确认

- 本轮仅修改 `LibraryStoreTests.testSuspendedRelationSwitchAllowsOnlyExplicitMemoryFixture`：改为 async throws，XCTUnwrap 已选 sourceID，显式 load(bookID:) 并等待关系任务，新增 currentBookID 一致断言，保留所有原断言。不新增方法、不改生产/视图/替身/辅助函数/工程。这只模拟详情拥有的加载前置，不证明 SwiftUI 生命周期已运行。
- 主控新授权的一次完整 Store 定向已执行：45/45 passed、0 failed、0 skipped；LibraryStoreTests 33、ManualRelationStoreTests 12，四项新增测试含握手均实际执行。原始进程 exit 0，summary/tests 解析各 exit 0，完整身份与源码清单一致。未单独试跑失败用例，未重置或使用旧额度。
- 定向通过后冻结 63 个源码/测试/工程配置文件，清单摘要 `36f3e76d74b2049f97674c23598e459093f3688a3e34dbea997add5a5f02b2ab`。唯一源码差异为上述测试方法；既有 Debug 设置及其他文件保持基线。完整非 UI 后重新核验 63/63 一致。
- 唯一一次完整 BookAtlasTests 完整执行 **221/221 passed、0 failed、0 skipped**；原始进程 exit 0，summary/tests 解析各 exit 0；完整树方法身份逐一匹配 221 项源码清单。其测试构建作为本轮 Debug 构建证据，不重复独立 build。实际三个目标编译命令带 -DDEBUG。
- 当前未收到本轮新的解锁/可交互/无输入与切换/无其他 UI 自动化确认，故**停在关系定向 UI 之前**；不沿用旧确认。4 项关系 UI、完整 UI、Release 和增量产物审计均未执行，不是 skipped tests，保留原条件额度；继续前须确认会话并复核冻结状态。
- 原有 44 项 UI 身份保留，当前 45 项清单已记录；没有单独运行 U1–U3，没有真实人工 UI。忙碌态原生 UI UNTESTED，完整 Prompt 11A 仍 BLOCKED。Release 产物/替身排除/两架构实际权限本轮 NOT VERIFIED，Intel 实机 NOT VERIFIED。Git、完整待提交范围、人工验收 PENDING，旧 UI 根因分别 UNKNOWN。
- 精确本机命令与路径保留在新临时 EVIDENCE.md，仓库命令用 `<EVIDENCE_DIR>` 代替；见 DEVELOPMENT。历史失败包及其退出码未覆盖。仅追加本计划与 DEVELOPMENT。无 git/gh、无 `.git` 访问、无清理、系统调整或发布；不开始 Prompt 11B。
