import XCTest
@testable import BookAtlas

@MainActor
final class PortabilityStoreTests: XCTestCase {
    func testPreviewMappingAndCancelKeepDatabaseUnchanged() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("library.sqlite")
        let repository = try BookRepository(databaseURL: databaseURL)
        let service = LibraryCatalogService(repository: repository, databaseURL: databaseURL)
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
        let databaseURL = directory.appendingPathComponent("library.sqlite")
        let repository = try BookRepository(databaseURL: databaseURL)
        let service = LibraryCatalogService(repository: repository, databaseURL: databaseURL)
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

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "BookAtlas-PortabilityStoreTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
