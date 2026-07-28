import XCTest
@testable import BookAtlas

final class BackupRestoreTests: XCTestCase {
    func testEmptyAndPopulatedBackupHaveManifestIntegrityAndNoSourcePath() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("library.sqlite")
        let repository = try BookRepository(databaseURL: databaseURL)
        let coordinator = LibraryBackupCoordinator(
            applicationVersion: "7.0-test",
            now: { FictionalLibraryFixtures.timestamp }
        )

        let emptyURL = directory.appendingPathComponent("empty.bookatlasbackup")
        let empty = try coordinator.backup(repository: repository, to: emptyURL)
        XCTAssertEqual(empty.preview.bookCount, 0)
        XCTAssertEqual(try coordinator.inspect(emptyURL).schemaVersion, 4)

        _ = try repository.create(FictionalLibraryFixtures.draft())
        let populatedURL = directory.appendingPathComponent("populated.bookatlasbackup")
        let populated = try coordinator.backup(repository: repository, to: populatedURL)
        XCTAssertEqual(populated.preview.bookCount, 1)
        XCTAssertEqual(populated.preview.applicationVersion, "7.0-test")
        let bytes = try Data(contentsOf: populatedURL)
        XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains(databaseURL.path))
        XCTAssertThrowsError(try coordinator.backup(repository: repository, to: populatedURL)) {
            XCTAssertEqual($0 as? PortabilityError, .destinationExists)
        }
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).contains { $0.lastPathComponent.hasPrefix(".bookatlas-backup-") }
        )
    }

    func testFailedBackupCleansControlledTemporaryFile() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try BookRepository(
            databaseURL: directory.appendingPathComponent("closed.sqlite")
        )
        try repository.close()
        XCTAssertThrowsError(
            try LibraryBackupCoordinator().backup(
                repository: repository,
                to: directory.appendingPathComponent("failed.bookatlasbackup")
            )
        ) {
            XCTAssertEqual($0 as? PortabilityError, .backupFailed)
        }
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).contains { $0.lastPathComponent.hasPrefix(".bookatlas-backup-") }
        )
    }

    func testOnlineBackupIncludesWALDataWithoutCheckpointingFirst() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("wal-library.sqlite")
        let database = try SQLiteDatabase(path: databaseURL.path)
        _ = try database.query("PRAGMA journal_mode = WAL") { $0.string(at: 0) }
        let repository = try BookRepository(database: database)
        _ = try repository.create(BookDraft(title: "《WAL 中的虚构书》", author: "周栩"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path + "-wal"))

        let backupURL = directory.appendingPathComponent("wal.bookatlasbackup")
        let coordinator = LibraryBackupCoordinator()
        _ = try coordinator.backup(repository: repository, to: backupURL)
        XCTAssertEqual(try coordinator.inspect(backupURL).bookCount, 1)
    }

    func testRestoreCreatesRecoveryCopyReplacesDataAndReopensConnection() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let recoveryDirectory = directory.appendingPathComponent("recovery", isDirectory: true)
        let liveURL = directory.appendingPathComponent("live.sqlite")
        var live = try BookRepository(databaseURL: liveURL)
        _ = try live.create(BookDraft(title: "《当前书库》", author: "林雾"))

        let sourceURL = directory.appendingPathComponent("source.sqlite")
        let source = try BookRepository(databaseURL: sourceURL)
        _ = try source.create(BookDraft(title: "《恢复后的书》", author: "沈遥"))
        _ = try source.create(BookDraft(title: "《恢复后的第二本》", author: "周栩"))
        let backupURL = directory.appendingPathComponent("source.bookatlasbackup")
        let coordinator = LibraryBackupCoordinator()
        _ = try coordinator.backup(repository: source, to: backupURL)

        let preview = try coordinator.restore(
            backupURL: backupURL,
            databaseURL: liveURL,
            repository: &live,
            recoveryDirectory: recoveryDirectory
        )

        XCTAssertEqual(preview.bookCount, 2)
        XCTAssertEqual(Set(try live.allBooks().map(\.title)), ["《恢复后的书》", "《恢复后的第二本》"])
        _ = try live.create(BookDraft(title: "《重连后可写》", author: "顾弦"))
        let recoveryFiles = try FileManager.default.contentsOfDirectory(
            at: recoveryDirectory,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(recoveryFiles.count, 1)
        XCTAssertEqual(try coordinator.inspect(try XCTUnwrap(recoveryFiles.first)).bookCount, 1)
    }

    func testReplacementFailureRollsBackOriginalAndLeavesVerifiedRecoveryCopy() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let recoveryDirectory = directory.appendingPathComponent("recovery", isDirectory: true)
        let liveURL = directory.appendingPathComponent("live.sqlite")
        var live = try BookRepository(databaseURL: liveURL)
        _ = try live.create(BookDraft(title: "《必须保留》", author: "许岸"))
        let backupURL = try makeBackup(
            in: directory,
            title: "《不应留下》",
            filename: "replacement.bookatlasbackup"
        )
        let coordinator = LibraryBackupCoordinator(injectFailure: { point in
            if point == .afterReplacement { throw PortabilityError.replacementFailed }
        })

        XCTAssertThrowsError(
            try coordinator.restore(
                backupURL: backupURL,
                databaseURL: liveURL,
                repository: &live,
                recoveryDirectory: recoveryDirectory
            )
        ) {
            XCTAssertEqual($0 as? PortabilityError, .replacementFailed)
        }
        XCTAssertEqual(try live.allBooks().map(\.title), ["《必须保留》"])
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(
                at: recoveryDirectory,
                includingPropertiesForKeys: nil
            ).count,
            1
        )
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).contains { $0.lastPathComponent.hasPrefix(".BookAtlas-Restore-") }
        )
    }

    func testFailureAfterCloseBeforeReplacementDoesNotDeleteOriginal() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let liveURL = directory.appendingPathComponent("live.sqlite")
        var live = try BookRepository(databaseURL: liveURL)
        _ = try live.create(BookDraft(title: "《原库仍在》", author: "林雾"))
        let backupURL = try makeBackup(
            in: directory,
            title: "《备份》",
            filename: "close.bookatlasbackup"
        )
        let coordinator = LibraryBackupCoordinator(injectFailure: { point in
            if point == .afterConnectionClose { throw PortabilityError.restoreInterrupted }
        })
        XCTAssertThrowsError(
            try coordinator.restore(
                backupURL: backupURL,
                databaseURL: liveURL,
                repository: &live,
                recoveryDirectory: directory.appendingPathComponent("recovery")
            )
        ) {
            XCTAssertEqual($0 as? PortabilityError, .restoreInterrupted)
        }
        XCTAssertEqual(try live.allBooks().map(\.title), ["《原库仍在》"])
    }

    func testCorruptSymlinkInvalidManifestAndFutureVersionsAreRejected() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = LibraryBackupCoordinator()
        let corrupt = directory.appendingPathComponent("corrupt.bookatlasbackup")
        try Data("not sqlite".utf8).write(to: corrupt)
        XCTAssertThrowsError(try coordinator.inspect(corrupt)) {
            XCTAssertEqual($0 as? PortabilityError, .corruptDatabase)
        }

        let valid = try makeBackup(in: directory, title: "《版本测试》", filename: "valid.bookatlasbackup")
        let symlink = directory.appendingPathComponent("link.bookatlasbackup")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: valid)
        XCTAssertThrowsError(try coordinator.inspect(symlink)) {
            XCTAssertEqual($0 as? PortabilityError, .unsafeFile)
        }

        let missingManifest = directory.appendingPathComponent("missing-manifest.bookatlasbackup")
        try FileManager.default.copyItem(at: valid, to: missingManifest)
        let missingManifestDB = try SQLiteDatabase(path: missingManifest.path)
        try missingManifestDB.execute("DROP TABLE \(LibraryBackupCoordinator.manifestTable)")
        try missingManifestDB.close()
        XCTAssertThrowsError(try coordinator.inspect(missingManifest)) {
            XCTAssertEqual($0 as? PortabilityError, .invalidManifest)
        }

        let futureFormat = directory.appendingPathComponent("future-format.bookatlasbackup")
        try FileManager.default.copyItem(at: valid, to: futureFormat)
        let futureFormatDB = try SQLiteDatabase(path: futureFormat.path)
        try futureFormatDB.execute(
            "UPDATE \(LibraryBackupCoordinator.manifestTable) SET format_version = 99"
        )
        try futureFormatDB.close()
        XCTAssertThrowsError(try coordinator.inspect(futureFormat)) {
            XCTAssertEqual($0 as? PortabilityError, .unsupportedBackupFormat(99))
        }

        let futureSchema = directory.appendingPathComponent("future-schema.bookatlasbackup")
        try FileManager.default.copyItem(at: valid, to: futureSchema)
        let futureSchemaDB = try SQLiteDatabase(path: futureSchema.path)
        try futureSchemaDB.execute(
            "UPDATE \(LibraryBackupCoordinator.manifestTable) SET schema_version = 99"
        )
        try futureSchemaDB.execute("PRAGMA user_version = 99")
        try futureSchemaDB.close()
        XCTAssertThrowsError(try coordinator.inspect(futureSchema)) {
            XCTAssertEqual($0 as? PortabilityError, .unsupportedSchemaVersion(99))
        }
    }

    func testReconnectFailureHasExplicitErrorAfterOriginalIsPutBack() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let liveURL = directory.appendingPathComponent("live.sqlite")
        var live = try BookRepository(databaseURL: liveURL)
        _ = try live.create(BookDraft(title: "《原库》", author: "林雾"))
        let backupURL = try makeBackup(in: directory, title: "《目标库》", filename: "target.bookatlasbackup")
        let coordinator = LibraryBackupCoordinator(injectFailure: { point in
            if point == .beforeReconnect || point == .beforeRollbackReconnect {
                throw PortabilityError.reconnectFailed
            }
        })
        XCTAssertThrowsError(
            try coordinator.restore(
                backupURL: backupURL,
                databaseURL: liveURL,
                repository: &live,
                recoveryDirectory: directory.appendingPathComponent("recovery")
            )
        ) {
            XCTAssertEqual($0 as? PortabilityError, .reconnectFailed)
        }
        let reopened = try BookRepository(databaseURL: liveURL)
        XCTAssertEqual(try reopened.allBooks().map(\.title), ["《原库》"])
    }

    func testInjectedDiskSpaceFailurePreservesLiveLibrary() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let liveURL = directory.appendingPathComponent("live.sqlite")
        var live = try BookRepository(databaseURL: liveURL)
        _ = try live.create(BookDraft(title: "《空间不足时保留》", author: "林雾"))
        let backupURL = try makeBackup(in: directory, title: "《目标》", filename: "disk.bookatlasbackup")
        let coordinator = LibraryBackupCoordinator(injectFailure: { point in
            if point == .afterRecoveryCopy { throw PortabilityError.insufficientDiskSpace }
        })
        XCTAssertThrowsError(
            try coordinator.restore(
                backupURL: backupURL,
                databaseURL: liveURL,
                repository: &live,
                recoveryDirectory: directory.appendingPathComponent("recovery")
            )
        ) {
            XCTAssertEqual($0 as? PortabilityError, .insufficientDiskSpace)
        }
        XCTAssertEqual(try live.allBooks().map(\.title), ["《空间不足时保留》"])
    }

    func testRestoreMigratesSchemaThreeBackupToCurrentSchemaFour() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let oldURL = directory.appendingPathComponent("old.sqlite")
        let oldDatabase = try SQLiteDatabase(path: oldURL.path)
        _ = try DatabaseMigrator().migrate(oldDatabase, through: 3)
        let oldRepository = try BookRepository(database: oldDatabase, automaticallyMigrate: false)
        _ = try oldRepository.create(BookDraft(title: "《旧版港湾》", author: "林雾"))
        let backupURL = directory.appendingPathComponent("old.bookatlasbackup")
        let coordinator = LibraryBackupCoordinator()
        XCTAssertEqual(
            try coordinator.backup(repository: oldRepository, to: backupURL).preview.schemaVersion,
            3
        )

        let liveURL = directory.appendingPathComponent("live.sqlite")
        var live = try BookRepository(databaseURL: liveURL)
        _ = try coordinator.restore(
            backupURL: backupURL,
            databaseURL: liveURL,
            repository: &live,
            recoveryDirectory: directory.appendingPathComponent("recovery")
        )
        XCTAssertEqual(live.schemaVersion, 4)
        XCTAssertEqual(try live.allBooks().map(\.title), ["《旧版港湾》"])
        XCTAssertEqual(
            try live.duplicateCandidates(
                for: DuplicateProbe(
                    id: UUID(),
                    draft: BookDraft(title: "旧版港湾", author: "林雾")
                )
            ).count,
            1
        )
    }

    private func makeBackup(in directory: URL, title: String, filename: String) throws -> URL {
        let sourceURL = directory.appendingPathComponent("\(UUID().uuidString).sqlite")
        let source = try BookRepository(databaseURL: sourceURL)
        _ = try source.create(BookDraft(title: title, author: "固定虚构作者"))
        let backupURL = directory.appendingPathComponent(filename)
        _ = try LibraryBackupCoordinator().backup(repository: source, to: backupURL)
        return backupURL
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "BookAtlas-BackupTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
