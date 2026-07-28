import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DataPortabilityView: View {
    @ObservedObject var store: PortabilityStore
    let didChangeLibrary: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BookAtlasDesign.pageSpacing) {
                Text("数据与可移植性")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("page-title-settings")

                Text("所有操作均由你主动选择文件，并只在本机完成。导入会先预览；恢复会先验证并创建恢复前副本。")
                    .foregroundStyle(.secondary)

                actionSection
                if let preview = store.importPreview {
                    importPreview(preview)
                }
                if let preview = store.backupPreview {
                    restorePreview(preview)
                } else if let phase = store.restorePhase {
                    restoreProgress(phase)
                }
                if let message = store.statusMessage {
                    Label(message, systemImage: "checkmark.circle")
                        .accessibilityIdentifier("portability-status")
                }
                if let message = store.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("portability-error")
                }
                if store.hasImportErrorReport {
                    Button("保存实际导入错误报告…") {
                        chooseSave(extension: "csv", action: store.saveErrorReport)
                    }
                    .accessibilityIdentifier("save-import-errors-button")
                }
            }
            .padding(BookAtlasDesign.pageSpacing)
        }
        .accessibilityIdentifier("data-portability-page")
        .onChange(of: store.requestedAction) { _, action in
            guard let action else { return }
            store.clearRequestedAction()
            perform(action)
        }
        .onChange(of: store.libraryRevision) { _, _ in
            didChangeLibrary()
        }
    }

    private var actionSection: some View {
        GroupBox("导入、导出与备份") {
            HStack {
                Button("导入 CSV…") { chooseImport() }
                    .keyboardShortcut("i", modifiers: .command)
                    .accessibilityIdentifier("import-csv-button")
                Button("导出 CSV…") { chooseSave(extension: "csv", action: store.exportCSV) }
                    .accessibilityIdentifier("export-csv-button")
                Button("导出 Markdown…") { chooseSave(extension: "md", action: store.exportMarkdown) }
                    .accessibilityIdentifier("export-markdown-button")
                Button("创建完整备份…") {
                    chooseSave(extension: LibraryBackupCoordinator.backupExtension, action: store.createBackup)
                }
                .accessibilityIdentifier("create-backup-button")
                Button("从备份恢复…") { chooseRestore() }
                    .accessibilityIdentifier("restore-backup-button")
            }
            .buttonStyle(.bordered)
            .disabled(store.isWorking)
            .padding(.vertical, 6)
        }
    }

    private func importPreview(_ preview: ImportPreview) -> some View {
        GroupBox("导入预览") {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    "总计 \(preview.totalRows) 行；可导入 \(preview.importableRows)；警告 \(preview.warningRows)；错误 \(preview.errorRows)；潜在重复 \(preview.potentialDuplicateRows)"
                )
                .accessibilityIdentifier("import-preview-counts")
                Text(
                    "将新建标签 \(preview.newTagCount)、书单 \(preview.newCollectionCount)、来源 \(preview.newSourceCount)。"
                )
                Text(preview.wasTruncated ? "屏幕预览已限制；执行仍覆盖所有已解析行。" : "预览未截断。")
                    .accessibilityIdentifier("import-preview-truncation")
                if preview.issuesWereTruncated {
                    Text("问题明细仅显示前 \(preview.issues.count) 项；统计覆盖全部已解析行。")
                        .accessibilityIdentifier("import-issue-truncation")
                }

                DisclosureGroup("字段映射") {
                    ForEach(ImportField.allCases) { field in
                        HStack {
                            Text(field.rawValue + (field.isRequired ? " *" : ""))
                                .frame(width: 150, alignment: .leading)
                            Picker(
                                field.rawValue,
                                selection: Binding(
                                    get: { preview.mapping.columns[field] },
                                    set: { store.updateMapping(field, header: $0) }
                                )
                            ) {
                                Text("不导入").tag(String?.none)
                                ForEach(preview.availableHeaders, id: \.self) {
                                    Text($0).tag(String?.some($0))
                                }
                            }
                            .labelsHidden()
                        }
                    }
                }
                .accessibilityIdentifier("import-field-mapping")

                ForEach(Array(preview.sampleRows.enumerated()), id: \.offset) { index, row in
                    Text("第 \(row.lineNumber) 行：\(row.draft.title) — \(row.draft.author)")
                        .lineLimit(1)
                        .accessibilityIdentifier("import-preview-row-\(index)")
                }
                if !preview.issues.isEmpty {
                    DisclosureGroup("问题明细（\(preview.issues.count)）") {
                        ForEach(Array(preview.issues.enumerated()), id: \.offset) { index, issue in
                            Text(
                                "第 \(issue.lineNumber) 行 · \(issue.field) · \(issue.description)"
                            )
                            .accessibilityIdentifier("import-preview-issue-\(index)")
                        }
                    }
                    .accessibilityIdentifier("import-preview-issues")
                }

                HStack {
                    Button("取消") { store.cancelImport() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("cancel-import-button")
                    Spacer()
                    Button("确认导入") {
                        store.executeImport()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(preview.importableRows == 0 || store.isWorking)
                    .accessibilityIdentifier("confirm-import-button")
                }
            }
            .padding(.vertical, 6)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("import-preview")
    }

    private func restorePreview(_ preview: BackupPreview) -> some View {
        GroupBox("恢复预览") {
            VStack(alignment: .leading, spacing: 10) {
                Text("备份格式 \(preview.formatVersion)，数据库 schema \(preview.schemaVersion)，共 \(preview.bookCount) 本书。")
                    .accessibilityIdentifier("restore-preview-details")
                Text("确认后，当前书库将被替换。Book Atlas 会先创建并验证恢复前安全副本；失败时回滚。")
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("restore-replacement-warning")
                if let phase = store.restorePhase {
                    Text(restorePhaseLabel(phase))
                        .accessibilityIdentifier("restore-progress-phase")
                }
                if store.isSafelyReplacing {
                    Label("正在安全替换书库；此阶段不能取消或使用 Escape。", systemImage: "lock.shield")
                        .accessibilityIdentifier("restore-safe-replacement")
                }
                HStack {
                    if store.canCancelRestore {
                        Button("取消") { store.cancelRestore() }
                            .keyboardShortcut(.cancelAction)
                            .accessibilityIdentifier("cancel-restore-button")
                    } else {
                        Button("正在安全替换") {}
                            .disabled(true)
                            .accessibilityIdentifier("cancel-restore-button")
                    }
                    Spacer()
                    Button("确认恢复", role: .destructive) {
                        store.confirmRestore()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(store.isWorking)
                    .accessibilityIdentifier("confirm-restore-button")
                }
            }
            .padding(.vertical, 6)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("restore-preview")
    }

    private func restoreProgress(_ phase: RestoreProgressPhase) -> some View {
        GroupBox("恢复检查") {
            HStack {
                ProgressView()
                Text(restorePhaseLabel(phase))
                    .accessibilityIdentifier("restore-progress-phase")
                Spacer()
                Button("取消") { store.cancelRestore() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(!store.canCancelRestore)
                    .accessibilityIdentifier("cancel-restore-button")
            }
            .padding(.vertical, 6)
        }
        .accessibilityIdentifier("restore-progress")
    }

    private func restorePhaseLabel(_ phase: RestoreProgressPhase) -> String {
        switch phase {
        case .inspecting:
            "正在验证备份；可取消且当前书库尚未更改。"
        case .creatingRecoveryCopy:
            "正在创建并验证恢复前副本；可取消且当前书库尚未更改。"
        case .staging:
            "正在暂存备份；可取消且当前书库尚未更改。"
        case .migrating:
            "正在迁移并验证暂存书库；可取消且当前书库尚未更改。"
        case .safeReplacement:
            "正在安全替换书库；此阶段不能取消。"
        case .reconnecting:
            "正在验证并重新连接；此阶段不能取消。"
        }
    }

    private func perform(_ action: PortabilityRequestedAction) {
        switch action {
        case .importCSV: chooseImport()
        case .exportCSV: chooseSave(extension: "csv", action: store.exportCSV)
        case .exportMarkdown: chooseSave(extension: "md", action: store.exportMarkdown)
        case .backup:
            chooseSave(extension: LibraryBackupCoordinator.backupExtension, action: store.createBackup)
        case .restore: chooseRestore()
        }
    }

    private func chooseImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.selectImport(url)
    }

    private func chooseRestore() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: LibraryBackupCoordinator.backupExtension) ?? .data
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.selectBackupForRestore(url)
    }

    private func chooseSave(extension fileExtension: String, action: (URL) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: fileExtension) ?? .data]
        panel.nameFieldStringValue = "BookAtlas-Export.\(fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        action(url)
    }
}
