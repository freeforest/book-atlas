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
    @Published private(set) var restorePhase: RestoreProgressPhase?
    @Published private(set) var isWorking = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var libraryRevision = 0
    @Published var requestedAction: PortabilityRequestedAction?

    private let catalog: (any LibraryCataloging)?
    private var importURL: URL?
    private var backupURL: URL?
    private var importErrorReport: ImportErrorReport?
    private var task: Task<Void, Never>?
    private var restoreControl: RestoreOperationControl?
    @Published private(set) var restoreCancellationPending = false
    private(set) var operationGeneration: UInt64 = 0

    var canCancelRestore: Bool {
        if restoreCancellationPending {
            return false
        }
        if let restoreControl {
            return restoreControl.canRequestCancellation
        }
        return restorePhase?.allowsCancellation ?? (backupPreview != nil)
    }

    var isSafelyReplacing: Bool {
        let authoritativePhase = restoreControl?.currentPhase ?? restorePhase
        return authoritativePhase == .safeReplacement || authoritativePhase == .reconnecting
    }

    var hasImportErrorReport: Bool {
        importErrorReport != nil
    }

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
        discardCurrentImportPreview()
        discardCurrentErrorReport()
        importURL = url
        prepareImport(mapping: nil)
    }

    func updateMapping(_ field: ImportField, header: String?) {
        guard var mapping = importPreview?.mapping else { return }
        mapping.columns[field] = header
        prepareImport(mapping: mapping)
    }

    func cancelImport() {
        invalidateCurrentOperation()
        task?.cancel()
        discardCurrentImportPreview()
        importPreview = nil
        importURL = nil
        statusMessage = "已取消导入；书库未更改。"
        isWorking = false
    }

    func executeImport() {
        guard let catalog, let preview = importPreview else { return }
        start(
            operation: { _ in try await catalog.executeImport(preview) },
            apply: { result in
                self.importPreview = nil
                self.importURL = nil
                self.importErrorReport = result.errorReport
                self.libraryRevision &+= 1
                self.statusMessage = "已导入 \(result.imported) 本；跳过 \(result.skipped) 行，其中重复 \(result.duplicateRows) 行。"
            },
            onFailure: {
                self.importPreview = nil
                self.importURL = nil
            }
        )
    }

    func saveErrorReport(to url: URL) {
        guard let catalog, let report = importErrorReport else { return }
        start(
            url: url,
            operation: { _ in
                try await catalog.exportImportErrors(report, to: url)
                return ()
            },
            apply: { _ in
                self.importErrorReport = nil
                self.statusMessage = "实际导入错误报告已保存。"
            }
        )
    }

    func exportCSV(to url: URL) {
        guard let catalog else { return }
        start(
            url: url,
            operation: { _ in try await catalog.exportCSV(to: url) },
            apply: { self.statusMessage = "CSV 已导出。" }
        )
    }

    func exportMarkdown(to url: URL) {
        guard let catalog else { return }
        start(
            url: url,
            operation: { _ in try await catalog.exportMarkdown(to: url) },
            apply: { self.statusMessage = "Markdown 已导出。" }
        )
    }

    func createBackup(at url: URL) {
        guard let catalog else { return }
        start(
            url: url,
            operation: { _ in try await catalog.createBackup(at: url) },
            apply: {
                self.statusMessage = "备份已验证并保存，共 \($0.preview.bookCount) 本书。"
            }
        )
    }

    func selectBackupForRestore(_ url: URL) {
        guard let catalog else { return }
        backupURL = url
        restorePhase = .inspecting
        start(
            url: url,
            operation: { _ in try await catalog.inspectBackup(at: url) },
            apply: {
                self.backupPreview = $0
                self.restorePhase = nil
            },
            onFailure: { self.restorePhase = nil }
        )
    }

    func cancelRestore() {
        if let restoreControl {
            switch restoreControl.requestCancellation() {
            case .accepted:
                restoreCancellationPending = true
                statusMessage = "正在安全取消恢复…"
            case let .rejected(authoritativePhase):
                restorePhase = authoritativePhase
            case .inactive:
                break
            }
            return
        }

        guard canCancelRestore else { return }
        if isWorking {
            task?.cancel()
            return
        }

        backupPreview = nil
        backupURL = nil
        restorePhase = nil
        statusMessage = "已取消恢复；当前书库未更改。"
    }

    func confirmRestore() {
        guard let catalog, let url = backupURL else { return }
        let control = RestoreOperationControl()
        restoreControl = control
        restoreCancellationPending = false
        start(
            url: url,
            operation: { generation in
                try await catalog.restoreBackup(at: url, control: control) { phase in
                    Task { @MainActor [weak self] in
                        guard let self,
                              self.operationGeneration == generation,
                              self.isWorking,
                              self.restoreControl === control
                        else { return }
                        self.restorePhase = phase
                    }
                }
            },
            apply: { restored in
                guard self.restoreControl === control else { return }
                self.restoreControl = nil
                self.restoreCancellationPending = false
                self.backupPreview = nil
                self.backupURL = nil
                self.restorePhase = nil
                self.libraryRevision &+= 1
                self.statusMessage = "恢复完成并重新打开书库，共 \(restored.bookCount) 本书。"
            },
            onFailure: {
                guard self.restoreControl === control else { return }
                self.restoreControl = nil
                self.restoreCancellationPending = false
                self.backupPreview = nil
                self.backupURL = nil
                self.restorePhase = nil
            }
        )
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
            duplicateCandidates: [],
            duplicateMatches: []
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
            issues: [],
            issuesWereTruncated: false,
            staging: ImportStagingReference(
                directoryURL: FileManager.default.temporaryDirectory,
                recordsURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("bookatlas-ui-preview.jsonl"),
                token: UUID(uuidString: "00000000-0000-0000-0000-000000000701")!,
                sourceFingerprint: "ui-preview",
                mappingFingerprint: "ui-preview",
                rowCount: 1
            )
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

    func seedSafeReplacementForUITesting() {
        seedFictionalRestorePreviewForUITesting()
        let control = RestoreOperationControl()
        try? control.transition(to: .safeReplacement)
        restoreControl = control
        restorePhase = .safeReplacement
        isWorking = true
    }

    func seedRestoreInspectionForUITesting() {
        restorePhase = .inspecting
        start(
            operation: { _ in
                try await Task.sleep(for: .seconds(60))
            },
            apply: { _ in },
            onFailure: { self.restorePhase = nil }
        )
    }

    private func prepareImport(mapping: CSVFieldMapping?) {
        guard let catalog, let url = importURL else { return }
        let previous = importPreview
        start(
            url: url,
            operation: { _ in try await catalog.prepareImport(from: url, mapping: mapping) },
            apply: { preview in
                if let previous, previous.staging != preview.staging {
                    await catalog.discardImport(previous)
                }
                self.importPreview = preview
            },
            discardStale: { await catalog.discardImport($0) }
        )
    }

    private func start<T: Sendable>(
        url: URL? = nil,
        operation: @escaping @MainActor (UInt64) async throws -> T,
        apply: @escaping @MainActor (T) async -> Void,
        discardStale: @escaping @MainActor (T) async -> Void = { _ in },
        onFailure: @escaping @MainActor () -> Void = {}
    ) {
        task?.cancel()
        operationGeneration &+= 1
        let generation = operationGeneration
        isWorking = true
        errorMessage = nil
        statusMessage = nil
        task = Task { @MainActor [weak self] in
            let accessed = url?.startAccessingSecurityScopedResource() ?? false
            defer {
                if accessed { url?.stopAccessingSecurityScopedResource() }
                if self?.operationGeneration == generation {
                    self?.isWorking = false
                }
            }
            do {
                try Task.checkCancellation()
                let value = try await operation(generation)
                guard self?.operationGeneration == generation else {
                    await discardStale(value)
                    return
                }
                await apply(value)
            } catch is CancellationError {
                guard self?.operationGeneration == generation else { return }
                onFailure()
                self?.statusMessage = "已取消且书库未更改。"
            } catch PortabilityError.cancelled {
                guard self?.operationGeneration == generation else { return }
                onFailure()
                self?.statusMessage = "已取消且书库未更改。"
            } catch {
                guard self?.operationGeneration == generation else { return }
                onFailure()
                self?.errorMessage = Self.userFacingMessage(for: error)
            }
        }
    }

    private func invalidateCurrentOperation() {
        operationGeneration &+= 1
    }

    private func discardCurrentImportPreview() {
        guard let catalog, let preview = importPreview else { return }
        Task { await catalog.discardImport(preview) }
        importPreview = nil
    }

    private func discardCurrentErrorReport() {
        guard let catalog, let report = importErrorReport else { return }
        Task { await catalog.discardImportErrors(report) }
        importErrorReport = nil
    }

    private static func userFacingMessage(for error: Error) -> String {
        switch error {
        case PortabilityError.destinationExists:
            "目标文件已存在；请选择新的文件名。"
        case PortabilityError.unsupportedCSVVersion:
            "CSV 格式版本不受支持。"
        case PortabilityError.corruptDatabase:
            "备份完整性检查失败，当前书库未更改。"
        case PortabilityError.invalidBackupSchema:
            "备份不是可安全读取的 Book Atlas 数据库，当前书库未更改。"
        case PortabilityError.backupTooLarge:
            "备份超过支持的大小上限，尚未执行完整性检查或复制。"
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
        case PortabilityError.recoveryRequired:
            "检测到未完成且无法自动判定的恢复状态。请停止编辑并保留当前文件，按恢复指引处理。"
        case PortabilityError.cancelled:
            "已取消且书库未更改。"
        case is CSVParserError:
            "CSV 无法安全解析；请检查编码、引号和大小限制。"
        case PortabilityError.missingRequiredMapping:
            "请为格式版本、书名和作者选择字段。"
        default:
            "操作未完成；没有内容被发送到网络。"
        }
    }
}
