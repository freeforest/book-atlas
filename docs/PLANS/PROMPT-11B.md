# Prompt 11B — BookKind 与详情完整性

## 当前状态

已授权，局部实现已形成；新增授权的两项测试前置修正验证 2/2 通过，停在 UI 启动前等待本轮用户会话确认。其余历史 11 项通过证据沿用，不表述为本轮 13/13。P11 整体待主控最终验收，未发布。P11A 功能验收与文档收口已完成，其历史证据不改写。Git 与完整待提交范围由用户核对，仍 PENDING。

## 范围与检查

- 复用四种 BookKind 与既有草稿/保存通路；共享中文映射，增加编辑器选择器和详情显示。
- 在共享查询中增加参数绑定的类型多选：族内 OR、族间 AND，接入计数、分页、精确聚焦、清除筛选而保留排序。
- 详情其余指定字段已存在，日期使用 storageValue 保留原始精度；不改手动关系或外部阅读区域。
- 不改变 Schema 5、格式、依赖、权限、编译条件、版本或合并规则。

授权顺序：一批定向非 UI（兼 Debug 构建证据）；取得新会话确认后一批至多两项类型 UI 加既有键盘回归；通过后一次 Release 与最小产物检查；最后用户虚构内存人工反馈。全轮最多一次有证据的窄修正与受影响项重跑；未知基础设施/输入异常、修正仍失败或 Release 失败即停止。不使用 P11A 结果替代。

真实用户数据库持久性人工验证、Intel 实机运行未完成。不得执行 Git 或发布。

## 2026-09-09 实际结果与停止

- 首轮非 UI：测试编译失败，真实 xcodebuild exit 65；0 executed / 0 passed / 0 failed / 0 skipped，未开始测试。新增 Catalog 回归将 Repository 交给 actor 后继续直接访问，Swift 报 sending repository risks causing data races。结果为 unknown，不能按零失败称通过。摘要/完整树首次解析因 TestReport 缓存权限各 exit 64，取得解析权限后同包各 exit 0；未重跑首轮。
- 唯一一次窄修正：仅将该测试交接后的读取改经 Catalog；不改变生产逻辑或断言。此前全部选择项未执行，因此修正运行仍选择原批次。
- 修正运行完整结束：13 executed / 11 passed / 2 failed / 0 skipped / 0 cancelled；真实 xcodebuild exit 65，摘要与完整树各 exit 0。Debug 测试编译成功只作为构建证据，定向门禁未通过。
- 失败一：`BookEditorDraftTests/testBookKindsRoundTripThroughCatalogWithoutLosingFieldsOrRelations()`，第 29 行 Book 整体相等、第 36 行关系整体相等断言失败。测试使用实时 Date，存储使用 ISO8601 fractional-seconds 编解码；精度往返差异是待核实解释，未输出的更细日期差值尚未验证，不据此认定字段/关系丢失。
- 失败二：`LibraryStoreTests/testKindFilterExcludesExactFocusAndClearRestoresWithoutChangingSort()`，预期 createdAt/ascending，实际 updatedAt/descending。源码确认测试先 setSort 后调用既有 focusBook，而 focusBook 会重建默认 LibraryQuery；清除筛选前的测试前置已重置排序。未修改或重跑。
- 通过身份：BookEditorDraftTests 原有 8 项；LibraryQueryTests 的 `testBookKindPredicatesShareCountsPagingAndExactFocus`、`testAssociationFamiliesUseAndWhileReadingStatusesUseOr`、`testClearFiltersPreservesSortAndRestoresNormalResults`。完整身份见结果树，不是完整非 UI 通过。
- 修正后的 63 个源码、测试、工程/scheme/entitlement 校验清单在运行后全部一致。后续只更新文档。未运行 UI、Release 或人工检查（前置未通过，不计 skipped tests）；新增 UI 用例及 P11B 人工结果 UNTESTED/PENDING。

命令使用下述共同选择参数，首轮 `<RUN>` 为 `nonui`，唯一修正轮为 `nonui-correction`；`<EVIDENCE_DIR>` 为本轮唯一临时证据目录，真实路径在交付报告中。

```sh
xcodebuild test -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -derivedDataPath <EVIDENCE_DIR>/<RUN>-dd -resultBundlePath <EVIDENCE_DIR>/<RUN>.xcresult -only-testing:BookAtlasTests/BookEditorDraftTests -only-testing:BookAtlasTests/LibraryQueryTests/testBookKindPredicatesShareCountsPagingAndExactFocus -only-testing:BookAtlasTests/LibraryQueryTests/testAssociationFamiliesUseAndWhileReadingStatusesUseOr -only-testing:BookAtlasTests/LibraryQueryTests/testClearFiltersPreservesSortAndRestoresNormalResults -only-testing:BookAtlasTests/LibraryStoreTests/testKindFilterExcludesExactFocusAndClearRestoresWithoutChangingSort > <EVIDENCE_DIR>/<RUN>.log 2>&1
bookatlas_exit=$?
printf '%s\n' "$bookatlas_exit" > <EVIDENCE_DIR>/<RUN>-exit.txt
exit "$bookatlas_exit"
```

解析分别为 `xcrun xcresulttool get test-results summary --path <EVIDENCE_DIR>/<RUN>.xcresult --compact` 与 `xcrun xcresulttool get test-results tests --path <EVIDENCE_DIR>/<RUN>.xcresult --compact`，JSON 均保留。原始日志亦保留；解析码不是测试码。

本轮修正额度耗尽，停止等待主控。Git、完整待提交范围 PENDING；未运行 git/gh、未访问 `.git`、未清理或发布。P11A 已验收状态不受本轮失败撤销。

## 2026-09-09 测试前置窄修正与条件续跑

主控新增授权一次两项测试前置修正与定向验证，不重置上一轮额度。仅修改指定两个方法：Catalog 回归的对端和关系使用固定 timestamp、now 注入 timestamp + 120 秒，保留全部相等断言并增加 updatedAt 断言；Store 回归先 focus 并等待，再 setSort 并等待、断言排序前置，然后继续原流程。不修改生产代码、其他测试或 helper，不把历史日期差值推断写成实测根因。

普通文件比较确认只改两方法；修改前 63 文件与上一轮校验全部一致，修改后测试状态清单在运行后全部一致。其余历史 11 项通过可沿用；本轮没有重跑它们，也不是完整 13/13 或完整非 UI。

唯一一次定向运行完整结束：**2 executed / 2 passed / 0 failed / 0 skipped / 0 cancelled**，真实 xcodebuild exit **0**；summary 和完整 tests 解析各 exit **0**，身份恰为下列两项。日志保留包括系统服务伴随诊断在内的原始输出，不将测试通过解释为所有环境警告不存在。

```sh
xcodebuild test -project BookAtlas.xcodeproj -scheme BookAtlas -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -derivedDataPath <EVIDENCE_DIR>/DerivedData -resultBundlePath <EVIDENCE_DIR>/targeted.xcresult -only-testing:BookAtlasTests/BookEditorDraftTests/testBookKindsRoundTripThroughCatalogWithoutLosingFieldsOrRelations -only-testing:BookAtlasTests/LibraryStoreTests/testKindFilterExcludesExactFocusAndClearRestoresWithoutChangingSort > <EVIDENCE_DIR>/targeted.log 2>&1
bookatlas_exit=$?
printf '%s\n' "$bookatlas_exit" > <EVIDENCE_DIR>/targeted-exit.txt
exit "$bookatlas_exit"
```

解析命令为 `xcrun xcresulttool get test-results summary --path <EVIDENCE_DIR>/targeted.xcresult --compact` 及 `xcrun xcresulttool get test-results tests --path <EVIDENCE_DIR>/targeted.xcresult --compact`；完整 JSON 留存。唯一新证据目录的本机路径见交付。

当前停在 UI 启动前：尚未取得本轮新会话确认，不能沿用历史确认。后续条件授权仅一次现有两项 UI，通过后一次 Release 最小核验，再等待用户虚构内存人工反馈；尚未执行，不计为 skipped tests。未额外构建或运行完整套件。Git 与完整待提交范围 PENDING，真实库持久性人工验证及 Intel 实机未完成。未运行 git/gh、未访问 `.git`、未清理或发布。
