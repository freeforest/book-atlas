import Foundation

enum PortabilityRequestedAction: Equatable {
    case importCSV
    case exportCSV
    case exportMarkdown
    case backup
    case restore
}

@MainActor
final class PortabilityStore: ObservableObject {
    @Published private(set) var importPreview: ImportPreview?
    @Published private(set) var backupPreview: BackupPreview?
    @Published private(set) var isWorking = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var libraryRevision = 0
    @Published var requestedAction: PortabilityRequestedAction?

    private let catalog: (any LibraryCataloging)?
    private var importURL: URL?
    private var backupURL: URL?
    private var task: Task<Void, Never>?

    init(catalog: (any LibraryCataloging)?) {
        self.catalog = catalog
    }

    func request(_ action: PortabilityRequestedAction) {
        requestedAction = action
    }

    func clearRequestedAction() {
        requestedAction = nil
    }

    func selectImport(_ url: URL) {
        importURL = url
        prepareImport(mapping: nil)
    }

    func updateMapping(_ field: ImportField, header: String?) {
        guard var mapping = importPreview?.mapping else { return }
        mapping.columns[field] = header
        prepareImport(mapping: mapping)
    }

    func cancelImport() {
        task?.cancel()
        importPreview = nil
        importURL = nil
        statusMessage = "已取消导入；书库未更改。"
        isWorking = false
    }

    func executeImport() {
        guard let catalog, let preview = importPreview else { return }
        run {
            let result = try await catalog.executeImport(preview)
            self.importPreview = nil
            self.importURL = nil
            self.libraryRevision &+= 1
            self.statusMessage = "已导入 \(result.imported) 本；跳过 \(result.skipped) 行，其中重复候选 \(result.duplicateRows) 行。"
        }
    }

    func saveErrorReport(to url: URL) {
        guard let catalog, let issues = importPreview?.issues else { return }
        run(url: url) {
            try await catalog.exportImportErrors(issues, to: url)
            self.statusMessage = "错误报告已保存。"
        }
    }

    func exportCSV(to url: URL) {
        guard let catalog else { return }
        run(url: url) {
            try await catalog.exportCSV(to: url)
            self.statusMessage = "CSV 已导出。"
        }
    }

    func exportMarkdown(to url: URL) {
        guard let catalog else { return }
        run(url: url) {
            try await catalog.exportMarkdown(to: url)
            self.statusMessage = "Markdown 已导出。"
        }
    }

    func createBackup(at url: URL) {
        guard let catalog else { return }
        run(url: url) {
            let result = try await catalog.createBackup(at: url)
            self.statusMessage = "备份已验证并保存，共 \(result.preview.bookCount) 本书。"
        }
    }

    func selectBackupForRestore(_ url: URL) {
        guard let catalog else { return }
        backupURL = url
        run(url: url) {
            self.backupPreview = try await catalog.inspectBackup(at: url)
        }
    }

    func cancelRestore() {
        task?.cancel()
        backupPreview = nil
        backupURL = nil
        statusMessage = "已取消恢复；当前书库未更改。"
        isWorking = false
    }

    func confirmRestore() {
        guard let catalog, let url = backupURL else { return }
        run(url: url) {
            let restored = try await catalog.restoreBackup(at: url)
            self.backupPreview = nil
            self.backupURL = nil
            self.libraryRevision &+= 1
            self.statusMessage = "恢复完成并重新打开书库，共 \(restored.bookCount) 本书。"
        }
    }

    func waitForPendingWork() async {
        await task?.value
    }

    func seedFictionalPreviewForUITesting() {
        let draft = BookDraft(
            title: "《虚构导入港湾》",
            author: "林雾",
            readingStatus: .reading,
            note: "仅供辅助功能测试。"
        )
        let row = PreparedImportRow(
            lineNumber: 2,
            draft: draft,
            tags: ["潮汐标签"],
            collections: ["北岸书单"],
            sources: ["纸页来源"],
            issues: [],
            duplicateCandidates: []
        )
        let headers = ["format_version", "title", "author", "tags", "collections", "sources"]
        importPreview = ImportPreview(
            totalRows: 1,
            importableRows: 1,
            warningRows: 0,
            errorRows: 0,
            potentialDuplicateRows: 0,
            newTagCount: 1,
            newCollectionCount: 1,
            newSourceCount: 1,
            sampleRows: [row],
            mapping: .inferred(from: headers),
            availableHeaders: headers,
            wasTruncated: false,
            preparedRows: [row],
            issues: []
        )
    }

    func seedFictionalRestorePreviewForUITesting() {
        backupPreview = BackupPreview(
            formatVersion: 1,
            schemaVersion: 4,
            applicationVersion: "ui-test",
            createdAt: Date(timeIntervalSince1970: 1_735_689_600),
            bookCount: 7
        )
    }

    private func prepareImport(mapping: CSVFieldMapping?) {
        guard let catalog, let url = importURL else { return }
        run(url: url) {
            self.importPreview = try await catalog.prepareImport(from: url, mapping: mapping)
        }
    }

    private func run(
        url: URL? = nil,
        _ operation: @escaping @MainActor () async throws -> Void
    ) {
        task?.cancel()
        isWorking = true
        errorMessage = nil
        statusMessage = nil
        task = Task { @MainActor [weak self] in
            let accessed = url?.startAccessingSecurityScopedResource() ?? false
            defer {
                if accessed { url?.stopAccessingSecurityScopedResource() }
                self?.isWorking = false
            }
            do {
                try Task.checkCancellation()
                try await operation()
            } catch is CancellationError {
                self?.statusMessage = "操作已取消；书库未更改。"
            } catch {
                self?.errorMessage = Self.userFacingMessage(for: error)
            }
        }
    }

    private static func userFacingMessage(for error: Error) -> String {
        switch error {
        case PortabilityError.destinationExists:
            "目标文件已存在；请选择新的文件名。"
        case PortabilityError.unsupportedCSVVersion:
            "CSV 格式版本不受支持。"
        case PortabilityError.corruptDatabase:
            "备份完整性检查失败，当前书库未更改。"
        case PortabilityError.invalidManifest:
            "备份清单无效，当前书库未更改。"
        case PortabilityError.unsupportedBackupFormat:
            "备份格式版本不受支持。"
        case PortabilityError.unsupportedSchemaVersion:
            "备份数据库版本不受支持。"
        case PortabilityError.restoreFailed:
            "恢复失败；原书库已回滚并重新打开。"
        case PortabilityError.insufficientDiskSpace:
            "可用磁盘空间不足；当前书库未更改。"
        case PortabilityError.replacementFailed:
            "无法安全替换书库；原书库已回滚。"
        case PortabilityError.restoreInterrupted:
            "恢复被中断；原书库已保留或回滚。"
        case PortabilityError.reconnectFailed:
            "恢复失败，且无法重新打开书库；请保留恢复前安全副本并停止编辑。"
        case is CSVParserError:
            "CSV 无法安全解析；请检查编码、引号和大小限制。"
        case PortabilityError.missingRequiredMapping:
            "请为格式版本、书名和作者选择字段。"
        default:
            "操作未完成；没有内容被发送到网络。"
        }
    }
}
