import XCTest
@testable import BookAtlas

@MainActor
final class PortabilityStoreTests: XCTestCase {
    func testPreviewMappingAndCancelKeepDatabaseUnchanged() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try BookRepository.inMemory()
        let service = LibraryCatalogService(repository: repository)
        let store = PortabilityStore(catalog: service)
        let csvURL = directory.appendingPathComponent("import.csv")
        try Data(
            """
            format_version,title,author
            bookatlas-csv/1,《状态层虚构书》,林雾
            """.utf8
        ).write(to: csvURL)

        store.selectImport(csvURL)
        await store.waitForPendingWork()
        XCTAssertEqual(store.importPreview?.totalRows, 1)
        XCTAssertEqual(store.importPreview?.mapping.columns[.title], "title")

        store.cancelImport()
        XCTAssertNil(store.importPreview)
        let booksAfterCancel = try await service.queryBooks(LibraryQuery())
        XCTAssertEqual(booksAfterCancel.count, 0)
        XCTAssertEqual(store.statusMessage, "已取消导入；书库未更改。")
    }

    func testExecuteImportPublishesStatisticsAndWritesOnlyAfterConfirmation() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try BookRepository.inMemory()
        let service = LibraryCatalogService(repository: repository)
        let store = PortabilityStore(catalog: service)
        let csvURL = directory.appendingPathComponent("import.csv")
        try Data(
            """
            format_version,title,author
            bookatlas-csv/1,《确认后导入》,沈遥
            """.utf8
        ).write(to: csvURL)

        store.selectImport(csvURL)
        await store.waitForPendingWork()
        let booksBeforeConfirmation = try await service.queryBooks(LibraryQuery())
        XCTAssertTrue(booksBeforeConfirmation.isEmpty)
        store.executeImport()
        await store.waitForPendingWork()

        XCTAssertNil(store.importPreview)
        let booksAfterConfirmation = try await service.queryBooks(LibraryQuery())
        XCTAssertEqual(booksAfterConfirmation.map(\.title), ["《确认后导入》"])
        XCTAssertTrue(store.statusMessage?.contains("已导入 1 本") == true)
        XCTAssertEqual(store.libraryRevision, 1)
    }

    func testExecutionPublishesOnlyActualImportIssueReport() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try BookRepository.inMemory()
        let service = LibraryCatalogService(repository: repository)
        let store = PortabilityStore(catalog: service)
        let csvURL = directory.appendingPathComponent("duplicates.csv")
        try Data(
            """
            format_version,title,author,isbn
            bookatlas-csv/1,《实际导入基准》,虚构作者,978-0-306-40615-7
            bookatlas-csv/1,《执行时重复》,另一作者,9780306406157
            """.utf8
        ).write(to: csvURL)

        store.selectImport(csvURL)
        await store.waitForPendingWork()
        XCTAssertFalse(store.hasImportErrorReport, "Preview must not expose a saved execution report")
        store.executeImport()
        await store.waitForPendingWork()
        XCTAssertTrue(store.hasImportErrorReport)
        XCTAssertTrue(store.statusMessage?.contains("重复 1 行") == true)

        let reportURL = directory.appendingPathComponent("actual-errors.csv")
        store.saveErrorReport(to: reportURL)
        await store.waitForPendingWork()
        XCTAssertFalse(store.hasImportErrorReport)
        let report = try String(contentsOf: reportURL, encoding: .utf8)
        XCTAssertTrue(report.contains("duplicate_at_execution"))
        XCTAssertFalse(report.contains("执行时重复"))
    }

    func testRestorePreviewRequiresExplicitConfirmationAndCancelPreservesLibrary() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("library.sqlite")
        let repository = try BookRepository(databaseURL: databaseURL)
        _ = try repository.create(BookDraft(title: "《当前书》", author: "许岸"))
        let service = LibraryCatalogService(
            repository: repository,
            databaseURL: databaseURL,
            recoveryDirectory: directory.appendingPathComponent("recovery")
        )
        let source = try BookRepository(
            databaseURL: directory.appendingPathComponent("source.sqlite")
        )
        _ = try source.create(BookDraft(title: "《备份书》", author: "顾弦"))
        let backupURL = directory.appendingPathComponent("source.bookatlasbackup")
        _ = try LibraryBackupCoordinator().backup(repository: source, to: backupURL)
        let store = PortabilityStore(catalog: service)

        store.selectBackupForRestore(backupURL)
        await store.waitForPendingWork()
        XCTAssertEqual(store.backupPreview?.bookCount, 1)
        let booksBeforeCancel = try await service.queryBooks(LibraryQuery())
        XCTAssertEqual(booksBeforeCancel.map(\.title), ["《当前书》"])

        store.cancelRestore()
        XCTAssertNil(store.backupPreview)
        let booksAfterCancel = try await service.queryBooks(LibraryQuery())
        XCTAssertEqual(booksAfterCancel.map(\.title), ["《当前书》"])
    }

    func testRapidMappingChangesCannotPublishAnOlderPreview() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("mapping.csv")
        try Data("format_version,first_title,latest_title,author\n".utf8).write(to: url)
        let race = MappingRaceProbe()
        let catalog = PortabilityRaceCatalog(mappingRace: race)
        let store = PortabilityStore(catalog: catalog)

        store.selectImport(url)
        await store.waitForPendingWork()
        XCTAssertNotNil(store.importPreview)
        store.updateMapping(.title, header: "first_title")
        for _ in 0 ..< 2_000 where !race.hasStarted {
            await Task.yield()
        }
        XCTAssertTrue(race.hasStarted)
        store.updateMapping(.title, header: "latest_title")
        await store.waitForPendingWork()

        XCTAssertEqual(store.importPreview?.mapping.columns[.title], "latest_title")
        XCTAssertNil(store.errorMessage)
        let discardedCount = await catalog.discardedPreviewCount()
        XCTAssertGreaterThanOrEqual(discardedCount, 1)
        store.cancelImport()
    }

    func testCancellingWhilePreviewIsParsingRemovesStagingAndNeverWritesLibrary() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try BookRepository.inMemory()
        let service = LibraryCatalogService(repository: repository)
        let store = PortabilityStore(catalog: service)
        let csvURL = directory.appendingPathComponent("large.csv")
        var csv = "format_version,title,author,note\n"
        let note = String(repeating: "x", count: 500)
        for index in 0 ..< 40_000 {
            csv += "bookatlas-csv/1,Cancel\(index),Fictional\(index),\(note)\n"
        }
        try Data(csv.utf8).write(to: csvURL)
        let before = importStagingDirectories()

        store.selectImport(csvURL)
        for _ in 0 ..< 2_000 where importStagingDirectories().subtracting(before).isEmpty {
            await Task.yield()
        }
        XCTAssertFalse(importStagingDirectories().subtracting(before).isEmpty)
        store.cancelImport()
        await store.waitForPendingWork()
        for _ in 0 ..< 100 { await Task.yield() }

        XCTAssertNil(store.importPreview)
        XCTAssertFalse(store.isWorking)
        XCTAssertEqual(store.statusMessage, "已取消导入；书库未更改。")
        let books = try await service.queryBooks(LibraryQuery())
        XCTAssertTrue(books.isEmpty)
        XCTAssertEqual(importStagingDirectories(), before)
    }

    func testRestoreCancellationDuringCancellablePhasePublishesAccurateState() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("fictional.bookatlasbackup")
        try Data("fictional test placeholder".utf8).write(to: url)
        let catalog = PortabilityRaceCatalog()
        let store = PortabilityStore(catalog: catalog)

        store.selectBackupForRestore(url)
        await store.waitForPendingWork()
        XCTAssertNotNil(store.backupPreview)
        store.confirmRestore()
        for _ in 0 ..< 2_000 where store.restorePhase != .staging {
            await Task.yield()
        }
        XCTAssertEqual(store.restorePhase, .staging)
        XCTAssertTrue(store.canCancelRestore)
        store.cancelRestore()
        await store.waitForPendingWork()

        XCTAssertNil(store.backupPreview)
        XCTAssertNil(store.restorePhase)
        XCTAssertFalse(store.isWorking)
        XCTAssertEqual(store.statusMessage, "已取消且书库未更改。")
        let completedRestoreCount = await catalog.completedRestoreCount()
        XCTAssertEqual(completedRestoreCount, 0)
    }

    func testSafeReplacementStateCannotBeCancelled() {
        let store = PortabilityStore(catalog: nil)
        store.seedSafeReplacementForUITesting()
        let generation = store.operationGeneration

        XCTAssertTrue(store.isSafelyReplacing)
        XCTAssertFalse(store.canCancelRestore)
        store.cancelRestore()
        XCTAssertEqual(store.operationGeneration, generation)
        XCTAssertNotNil(store.backupPreview)
        XCTAssertEqual(store.restorePhase, .safeReplacement)
        XCTAssertTrue(store.isWorking)
        XCTAssertNil(store.statusMessage)
    }

    func testCancellationAtUnpublishedSafeReplacementBoundaryCannotHideSuccessfulRestore() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("safe-race.bookatlasbackup")
        try Data("fixed fictional backup placeholder".utf8).write(to: url)
        let race = RestoreRaceProbe()
        let catalog = PortabilityRaceCatalog(restoreMode: .safeBoundaryDelayed, restoreRace: race)
        let store = PortabilityStore(catalog: catalog)

        store.selectBackupForRestore(url)
        await store.waitForPendingWork()
        store.confirmRestore()
        for _ in 0 ..< 10_000 where !race.hasEnteredSafeReplacement {
            await Task.yield()
        }
        XCTAssertTrue(race.hasEnteredSafeReplacement)
        XCTAssertNotEqual(
            store.restorePhase,
            .safeReplacement,
            "The deterministic race keeps the safe phase callback unpublished"
        )
        let generation = store.operationGeneration

        store.cancelRestore()
        XCTAssertEqual(store.operationGeneration, generation)
        XCTAssertEqual(store.restorePhase, .safeReplacement)
        XCTAssertFalse(store.canCancelRestore)
        XCTAssertNotEqual(store.statusMessage, "已取消且书库未更改。")
        XCTAssertTrue(store.isWorking)

        race.releaseSafeReplacement()
        await store.waitForPendingWork()
        XCTAssertEqual(store.libraryRevision, 1)
        XCTAssertNil(store.restorePhase)
        XCTAssertNil(store.backupPreview)
        XCTAssertEqual(store.statusMessage, "恢复完成并重新打开书库，共 1 本书。")
        XCTAssertNil(store.errorMessage)
        let completedRestoreCount = await catalog.completedRestoreCount()
        XCTAssertEqual(completedRestoreCount, 1)
    }

    func testStaleRestorePhaseCallbackCannotOverwriteFinalSuccessOrFailure() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("stale-phase.bookatlasbackup")
        try Data("fixed fictional backup placeholder".utf8).write(to: url)

        for mode in [RestoreRaceMode.staleAfterSuccess, .staleAfterFailure] {
            let race = RestoreRaceProbe()
            let catalog = PortabilityRaceCatalog(restoreMode: mode, restoreRace: race)
            let store = PortabilityStore(catalog: catalog)
            store.selectBackupForRestore(url)
            await store.waitForPendingWork()
            store.confirmRestore()
            await store.waitForPendingWork()
            for _ in 0 ..< 10_000 where !race.hasPublishedStalePhase {
                await Task.yield()
            }
            for _ in 0 ..< 100 { await Task.yield() }

            XCTAssertTrue(race.hasPublishedStalePhase)
            XCTAssertNil(store.restorePhase)
            XCTAssertFalse(store.isWorking)
            if mode == .staleAfterSuccess {
                XCTAssertEqual(store.libraryRevision, 1)
                XCTAssertNotNil(store.statusMessage)
                XCTAssertNil(store.errorMessage)
            } else {
                XCTAssertEqual(store.libraryRevision, 0)
                XCTAssertNil(store.statusMessage)
                XCTAssertNotNil(store.errorMessage)
            }
        }
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "BookAtlas-PortabilityStoreTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func importStagingDirectories() -> Set<String> {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: FileManager.default.temporaryDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []
        return Set(urls.filter {
            $0.lastPathComponent.hasPrefix("BookAtlas-Import-")
        }.map(\.path))
    }
}

private actor PortabilityRaceCatalog: LibraryCataloging {
    private var discarded = 0
    private var completedRestores = 0
    private let mappingRace: MappingRaceProbe?
    private let restoreMode: RestoreRaceMode
    private let restoreRace: RestoreRaceProbe?

    init(
        mappingRace: MappingRaceProbe? = nil,
        restoreMode: RestoreRaceMode = .cancellable,
        restoreRace: RestoreRaceProbe? = nil
    ) {
        self.mappingRace = mappingRace
        self.restoreMode = restoreMode
        self.restoreRace = restoreRace
    }

    func queryBooks(_ query: LibraryQuery) throws -> [Book] { [] }
    func queryBookPage(_ query: LibraryQuery) throws -> LibraryPage {
        LibraryPage(books: [], totalCount: 0, offset: query.offset)
    }
    func queryBookPage(
        _ query: LibraryQuery,
        focusedBookID: UUID
    ) async throws -> FocusedLibraryPage {
        FocusedLibraryPage(
            page: try queryBookPage(query),
            focusedBook: nil
        )
    }
    func createBook(from editor: BookEditorDraft) throws -> Book {
        throw PortabilityError.restoreFailed
    }
    func updateBook(_ book: Book, from editor: BookEditorDraft) throws -> Book {
        throw PortabilityError.restoreFailed
    }
    func deleteBook(_ book: Book) throws {}

    func prepareImport(from url: URL, mapping: CSVFieldMapping?) throws -> ImportPreview {
        if mapping?.columns[.title] == "first_title" {
            mappingRace?.started()
            Thread.sleep(forTimeInterval: 0.08)
        }
        let headers = ["format_version", "first_title", "latest_title", "author"]
        let effective = mapping ?? CSVFieldMapping(columns: [
            .formatVersion: "format_version",
            .title: "first_title",
            .author: "author"
        ])
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "BookAtlas-RacePreview-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let records = directory.appendingPathComponent("records.jsonl")
        try Data().write(to: records)
        return ImportPreview(
            totalRows: 1,
            importableRows: 1,
            warningRows: 0,
            errorRows: 0,
            potentialDuplicateRows: 0,
            newTagCount: 0,
            newCollectionCount: 0,
            newSourceCount: 0,
            sampleRows: [],
            mapping: effective,
            availableHeaders: headers,
            wasTruncated: false,
            issues: [],
            issuesWereTruncated: false,
            staging: ImportStagingReference(
                directoryURL: directory,
                recordsURL: records,
                token: UUID(),
                sourceFingerprint: "fictional",
                mappingFingerprint: effective.columns[.title] ?? "",
                rowCount: 1
            )
        )
    }

    func discardImport(_ preview: ImportPreview) {
        discarded += 1
        try? FileManager.default.removeItem(at: preview.staging.directoryURL)
    }

    func inspectBackup(at url: URL) throws -> BackupPreview {
        BackupPreview(
            formatVersion: 1,
            schemaVersion: 4,
            applicationVersion: "test",
            createdAt: FictionalLibraryFixtures.timestamp,
            bookCount: 1
        )
    }

    func restoreBackup(
        at url: URL,
        control: RestoreOperationControl,
        progress: @escaping @Sendable (RestoreProgressPhase) -> Void
    ) throws -> BackupPreview {
        defer { control.finish() }
        switch restoreMode {
        case .cancellable:
            try control.transition(to: .staging)
            progress(.staging)
            while !control.isCancellationRequested {
                Thread.sleep(forTimeInterval: 0.001)
            }
            throw PortabilityError.cancelled
        case .safeBoundaryDelayed:
            try control.transition(to: .staging)
            progress(.staging)
            try control.transition(to: .safeReplacement)
            restoreRace?.enteredSafeReplacement()
            while restoreRace?.canLeaveSafeReplacement != true {
                Thread.sleep(forTimeInterval: 0.001)
            }
            progress(.safeReplacement)
            try control.transition(to: .reconnecting)
            progress(.reconnecting)
            completedRestores += 1
            return fictionalBackupPreview()
        case .staleAfterSuccess:
            completedRestores += 1
            publishStalePhaseLater(progress)
            return fictionalBackupPreview()
        case .staleAfterFailure:
            publishStalePhaseLater(progress)
            throw PortabilityError.restoreFailed
        }
    }

    func discardedPreviewCount() -> Int { discarded }
    func completedRestoreCount() -> Int { completedRestores }

    private func fictionalBackupPreview() -> BackupPreview {
        BackupPreview(
            formatVersion: 1,
            schemaVersion: 4,
            applicationVersion: "test",
            createdAt: FictionalLibraryFixtures.timestamp,
            bookCount: 1
        )
    }

    private func publishStalePhaseLater(
        _ progress: @escaping @Sendable (RestoreProgressPhase) -> Void
    ) {
        let race = restoreRace
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.03) {
            progress(.staging)
            race?.publishedStalePhase()
        }
    }
}

private enum RestoreRaceMode: Equatable, Sendable {
    case cancellable
    case safeBoundaryDelayed
    case staleAfterSuccess
    case staleAfterFailure
}

private final class RestoreRaceProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var enteredSafeReplacementValue = false
    private var leaveSafeReplacementValue = false
    private var publishedStalePhaseValue = false

    var hasEnteredSafeReplacement: Bool {
        lock.withLock { enteredSafeReplacementValue }
    }

    var canLeaveSafeReplacement: Bool {
        lock.withLock { leaveSafeReplacementValue }
    }

    var hasPublishedStalePhase: Bool {
        lock.withLock { publishedStalePhaseValue }
    }

    func enteredSafeReplacement() {
        lock.withLock { enteredSafeReplacementValue = true }
    }

    func releaseSafeReplacement() {
        lock.withLock { leaveSafeReplacementValue = true }
    }

    func publishedStalePhase() {
        lock.withLock { publishedStalePhaseValue = true }
    }
}

private final class MappingRaceProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var startedValue = false

    var hasStarted: Bool {
        lock.withLock { startedValue }
    }

    func started() {
        lock.withLock { startedValue = true }
    }
}
