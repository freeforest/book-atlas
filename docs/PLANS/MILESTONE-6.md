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
8. Schema 仍为 5；依赖、网络 entitlement 与 Release entitlement 未扩大；`git diff --check` 和隐私/产物扫描通过。
9. 固定虚构、内存数据库 Debug 应用完成一次真实鼠标与键盘检查。

产品断言失败必须先定位和修复。Xcode/XCUI 基础设施失败只允许使用全新 `/tmp` 路径干净重试一次；同一基础设施错误连续两次即 `BLOCKED`。不完整 xcresult、零测试或仅构建成功不计为测试通过。

## Local verification status

截至 2026-09-05，本地实现已形成，但未完成全部门禁，也未获得主控验收：

- `VERIFIED`：新增领域、Repository、Catalog、Store 定向测试 10/10；关系、合并、备份恢复和图谱定向回归 10/10；Debug 构建成功。
- `VERIFIED`：完整非 UI 套件 209/209，0 failure、0 skip；结果包为 `/tmp/bookatlas-p11a-final-g4-nonui-34.xcresult`。
- `VERIFIED`：新增关系定向 UI 3/3，XCUIAutomation 实际初始化，0 failure、0 skip；结果包为 `/tmp/bookatlas-p11a-final-g5-targeted-ui-35.xcresult`。
- `BLOCKED`：首次完整 UI 结果包 `/tmp/bookatlas-p11a-final-g6-full-ui-36.xcresult` 完整收集 44 项，其中 31 passed、13 failed、0 skipped；首个错误为应用连接丢失，其后为 UI 测试授权链失效。
- `INCOMPLETE RESULT`：唯一一次全新路径重试 `/tmp/bookatlas-p11a-final-g6-full-ui-retry-37.xcresult` 在多个未由 Prompt 11A 修改的既有用例中重复出现 XCUI 合成输入丢字符，依规则停止；命令退出 73，Xcode 报告结果日志未完整封装。
- `UNTESTED`：Release 构建；`NOT VERIFIED`：最终 Schema/依赖/entitlement/隐私扫描及真实界面鼠标与键盘检查。阻断后未越过门禁继续执行。

## Exit condition

运行专区完成实现与可取得的证据收集，按 Prompt 11A 格式报告并停止。只有主控区可以决定如何解除阻断、验收 Prompt 11A 或授权 Prompt 11B；在此之前本计划保持 `BLOCKED — WAITING FOR CONTROLLER REVIEW`。
