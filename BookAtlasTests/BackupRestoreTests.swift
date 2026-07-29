import SQLite3
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
        XCTAssertEqual(
            try coordinator.inspect(emptyURL).schemaVersion,
            BookAtlasSchema.latestVersion
        )

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

    func testSchemaValidationReadsEveryPersistedRelationshipFamilyAndDuplicateIndex() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("complete-source.sqlite")
        let source = try BookRepository(databaseURL: sourceURL)
        let first = try source.create(
            BookDraft(title: "《完整关系甲》", author: "虚构作者甲"),
            at: FictionalLibraryFixtures.timestamp
        )
        let second = try source.create(
            BookDraft(title: "《完整关系乙》", author: "虚构作者乙"),
            at: FictionalLibraryFixtures.timestamp
        )
        let tag = try source.createTag(FictionalLibraryFixtures.tag())
        let collection = try source.createCollection(FictionalLibraryFixtures.collection())
        let recommendation = try source.createSource(FictionalLibraryFixtures.source())
        try source.attach(tagID: tag.id, toBookID: first.id)
        try source.add(bookID: first.id, toCollectionID: collection.id)
        try source.attach(sourceID: recommendation.id, toBookID: first.id)
        try source.addExternalLink(try ExternalLink(
            bookID: first.id,
            kind: .web,
            label: "虚构详情",
            value: "https://example.invalid/complete",
            createdAt: FictionalLibraryFixtures.timestamp
        ))
        let localFile = try source.addLocalFileReference(
            LocalFileReference(
                bookID: first.id,
                displayName: "完整关系虚构文件.pdf",
                bookmarkData: Data([0x42, 0x4F, 0x4F, 0x4B, 0x00, 0xFF]),
                createdAt: FictionalLibraryFixtures.timestamp
            )
        )
        try source.addManualRelation(try ManualBookRelation(
            sourceBookID: first.id,
            targetBookID: second.id,
            kind: .related,
            note: "固定虚构备注",
            createdAt: FictionalLibraryFixtures.timestamp
        ))
        try source.ignoreDuplicatePair(
            first.id,
            second.id,
            disposition: .notDuplicate,
            at: FictionalLibraryFixtures.timestamp
        )

        let backupURL = directory.appendingPathComponent("complete.bookatlasbackup")
        let coordinator = LibraryBackupCoordinator()
        _ = try coordinator.backup(repository: source, to: backupURL)
        XCTAssertEqual(try coordinator.inspect(backupURL).bookCount, 2)

        let liveURL = directory.appendingPathComponent("restored.sqlite")
        var live = try BookRepository(databaseURL: liveURL)
        _ = try coordinator.restore(
            backupURL: backupURL,
            databaseURL: liveURL,
            repository: &live,
            recoveryDirectory: directory.appendingPathComponent("recovery")
        )
        XCTAssertEqual(try live.tags(forBookID: first.id).map(\.name), [tag.name])
        XCTAssertEqual(
            try live.collections(forBookID: first.id).map(\.name),
            [collection.name]
        )
        XCTAssertEqual(
            try live.sources(forBookID: first.id).map(\.name),
            [recommendation.name]
        )
        XCTAssertEqual(try live.externalLinks(forBookID: first.id).count, 1)
        XCTAssertEqual(
            try live.localFileReferences(forBookID: first.id),
            [localFile]
        )
        XCTAssertEqual(try live.manualRelations(forBookID: first.id).count, 1)
        XCTAssertEqual(
            try live.ignoredDuplicatePair(between: first.id, and: second.id)?.disposition,
            .notDuplicate
        )
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

    func testApplicationSchemaValidationRejectsStructurallyIncompleteAndInvalidBackupsBeforeClosingLiveLibrary() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let valid = try makeBackup(
            in: directory,
            title: "《完整结构基准》",
            filename: "valid-schema.bookatlasbackup"
        )
        let cases: [(String, (SQLiteDatabase) throws -> Void)] = [
            ("missing-core-table", { database in
                try database.execute("DROP TABLE manual_book_relations")
            }),
            ("missing-required-column", { database in
                try database.execute("ALTER TABLE books DROP COLUMN note")
            }),
            ("invalid-domain-enum", { database in
                try database.execute("PRAGMA ignore_check_constraints = ON")
                try database.execute("UPDATE books SET reading_status = 'impossible_state'")
            }),
            ("invalid-uuid", { database in
                try database.execute(
                    """
                    INSERT INTO tags (id, name, created_at, updated_at)
                    VALUES ('not-a-uuid', '虚构非法标识标签', ?, ?)
                    """,
                    bindings: [
                        .text(StorageDateCodec.encode(FictionalLibraryFixtures.timestamp)),
                        .text(StorageDateCodec.encode(FictionalLibraryFixtures.timestamp))
                    ]
                )
            }),
            ("foreign-key-orphan", { database in
                try database.execute("PRAGMA foreign_keys = OFF")
                try database.execute(
                    "INSERT INTO book_tags (book_id, tag_id) VALUES (?, ?)",
                    bindings: [
                        .text("00000000-0000-0000-0000-000000009901"),
                        .text("00000000-0000-0000-0000-000000009902")
                    ]
                )
            }),
            ("migration-history-mismatch", { database in
                try database.execute("DELETE FROM schema_migrations WHERE version = 4")
            })
        ]

        for (name, mutate) in cases {
            let backup = directory.appendingPathComponent("\(name).bookatlasbackup")
            try FileManager.default.copyItem(at: valid, to: backup)
            let database = try SQLiteDatabase(path: backup.path)
            try mutate(database)
            XCTAssertTrue(try database.integrityCheck(), "\(name) must remain physically valid")
            XCTAssertEqual(try database.schemaVersion(), BookAtlasSchema.latestVersion)
            try database.close()

            let liveURL = directory.appendingPathComponent("\(name)-live.sqlite")
            var live = try BookRepository(databaseURL: liveURL)
            _ = try live.create(BookDraft(title: "《原库 \(name)》", author: "虚构守护者"))
            var didClose = false
            let coordinator = LibraryBackupCoordinator(injectFailure: { point in
                if point == .afterConnectionClose { didClose = true }
            })

            XCTAssertThrowsError(
                try coordinator.restore(
                    backupURL: backup,
                    databaseURL: liveURL,
                    repository: &live,
                    recoveryDirectory: directory.appendingPathComponent("\(name)-recovery")
                ),
                name
            ) {
                XCTAssertEqual($0 as? PortabilityError, .invalidBackupSchema, name)
            }
            XCTAssertFalse(didClose, "\(name) reached the close boundary")
            XCTAssertEqual(try live.allBooks().map(\.title), ["《原库 \(name)》"])
            _ = try live.create(BookDraft(title: "《仍可写 \(name)》", author: "虚构守护者"))
        }
    }

    func testSchemaObjectValidationRejectsMissingModifiedAndUnknownTriggersBeforeClosingLiveLibrary() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let valid = try makeBackup(
            in: directory,
            title: "《触发器结构基准》",
            filename: "valid-trigger.bookatlasbackup"
        )
        let trigger = BookAtlasSchema.ignoredPairInvalidationTriggerName
        let cases: [(String, (SQLiteDatabase) throws -> Void)] = [
            ("missing-trigger", { database in
                try database.execute("DROP TRIGGER \(trigger)")
            }),
            ("modified-trigger", { database in
                try database.execute("DROP TRIGGER \(trigger)")
                try database.execute(
                    """
                    CREATE TRIGGER \(trigger)
                    AFTER UPDATE OF title ON books
                    BEGIN
                        DELETE FROM ignored_duplicate_pairs
                        WHERE first_book_id = NEW.id;
                    END
                    """
                )
            }),
            ("unknown-trigger", { database in
                try database.execute(
                    """
                    CREATE TRIGGER untrusted_bookatlas_test_trigger
                    AFTER UPDATE ON books
                    BEGIN
                        DELETE FROM tags;
                    END
                    """
                )
            }),
            ("unknown-view", { database in
                try database.execute(
                    "CREATE VIEW untrusted_bookatlas_test_view AS SELECT id FROM books"
                )
            })
        ]

        for (name, mutate) in cases {
            try assertInvalidBackupRejectedBeforeClose(
                validBackup: valid,
                name: name,
                directory: directory,
                mutate: mutate
            )
        }
    }

    func testSchemaObjectValidationRejectsMissingAndMalformedNamedIndexesBeforeClosingLiveLibrary() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let valid = try makeBackup(
            in: directory,
            title: "《索引结构基准》",
            filename: "valid-index.bookatlasbackup"
        )
        let cases: [(String, (SQLiteDatabase) throws -> Void)] = [
            ("missing-v3-index", { database in
                try database.execute("DROP INDEX idx_books_original_title")
            }),
            ("missing-v4-index", { database in
                try database.execute("DROP INDEX idx_duplicate_keys_isbn")
            }),
            ("missing-v5-index", { database in
                try database.execute("DROP INDEX idx_local_file_references_book_id")
            }),
            ("wrong-index-column-order", { database in
                try database.execute("DROP INDEX idx_duplicate_keys_title_author")
                try database.execute(
                    """
                    CREATE INDEX idx_duplicate_keys_title_author
                    ON book_duplicate_keys(normalized_author, normalized_title)
                    """
                )
            }),
            ("wrong-index-uniqueness", { database in
                try database.execute("DROP INDEX idx_duplicate_keys_isbn")
                try database.execute(
                    """
                    CREATE UNIQUE INDEX idx_duplicate_keys_isbn
                    ON book_duplicate_keys(valid_isbn)
                    """
                )
            })
        ]

        for (name, mutate) in cases {
            try assertInvalidBackupRejectedBeforeClose(
                validBackup: valid,
                name: name,
                directory: directory,
                mutate: mutate
            )
        }
    }

    func testSchemaFiveValidationRejectsMissingLocalFileTableAndInvalidBookmarkRowsBeforeClose() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let valid = try makeBackup(
            in: directory,
            title: "《Schema 5 本地引用基准》",
            filename: "valid-local-file-schema.bookatlasbackup"
        )
        let cases: [(String, (SQLiteDatabase) throws -> Void)] = [
            ("missing-local-file-table", { database in
                try database.execute("DROP TABLE local_file_references")
            }),
            ("invalid-local-file-uuid", { database in
                let bookID = try database.query("SELECT id FROM books LIMIT 1") {
                    $0.string(at: 0)
                }.first!
                try database.execute(
                    """
                    INSERT INTO local_file_references (
                        id, book_id, display_name, bookmark_data, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    bindings: [
                        .text("not-a-uuid"),
                        .text(bookID!),
                        .text("虚构文件.pdf"),
                        .blob(Data("opaque".utf8)),
                        .text(StorageDateCodec.encode(FictionalLibraryFixtures.timestamp)),
                        .text(StorageDateCodec.encode(FictionalLibraryFixtures.timestamp))
                    ]
                )
            }),
            ("invalid-local-file-date", { database in
                let bookID = try database.query("SELECT id FROM books LIMIT 1") {
                    $0.string(at: 0)
                }.first!
                try database.execute(
                    """
                    INSERT INTO local_file_references (
                        id, book_id, display_name, bookmark_data, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    bindings: [
                        .text(UUID().uuidString),
                        .text(bookID!),
                        .text("虚构文件.pdf"),
                        .blob(Data("opaque".utf8)),
                        .text("invalid-date"),
                        .text(StorageDateCodec.encode(FictionalLibraryFixtures.timestamp))
                    ]
                )
            }),
            ("path-shaped-local-file-name", { database in
                try database.execute("PRAGMA ignore_check_constraints = ON")
                let bookID = try database.query("SELECT id FROM books LIMIT 1") {
                    $0.string(at: 0)
                }.first!
                try database.execute(
                    """
                    INSERT INTO local_file_references (
                        id, book_id, display_name, bookmark_data, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    bindings: [
                        .text(UUID().uuidString),
                        .text(bookID!),
                        .text("/private/fictional/hidden.pdf"),
                        .blob(Data("opaque".utf8)),
                        .text(StorageDateCodec.encode(FictionalLibraryFixtures.timestamp)),
                        .text(StorageDateCodec.encode(FictionalLibraryFixtures.timestamp))
                    ]
                )
            })
        ]

        for (name, mutate) in cases {
            try assertInvalidBackupRejectedBeforeClose(
                validBackup: valid,
                name: name,
                directory: directory,
                mutate: mutate
            )
        }
    }

    func testVersionedSchemaObjectExpectationsAcceptVersionsOneThroughFiveAndMigrateRestore() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = LibraryBackupCoordinator()

        for version in 1 ... BookAtlasSchema.latestVersion {
            let sourceURL = directory.appendingPathComponent("schema-\(version).sqlite")
            let database = try SQLiteDatabase(path: sourceURL.path)
            _ = try DatabaseMigrator().migrate(database, through: version)
            let source = try BookRepository(database: database, automaticallyMigrate: false)
            let expectedTitle = "《Schema \(version) 固定虚构书》"
            _ = try source.create(BookDraft(title: expectedTitle, author: "虚构迁移作者"))
            let backupURL = directory.appendingPathComponent(
                "schema-\(version).bookatlasbackup"
            )

            XCTAssertEqual(
                try coordinator.backup(repository: source, to: backupURL).preview.schemaVersion,
                version
            )
            XCTAssertEqual(try coordinator.inspect(backupURL).schemaVersion, version)

            let liveURL = directory.appendingPathComponent("schema-\(version)-live.sqlite")
            var live = try BookRepository(databaseURL: liveURL)
            _ = try coordinator.restore(
                backupURL: backupURL,
                databaseURL: liveURL,
                repository: &live,
                recoveryDirectory: directory.appendingPathComponent(
                    "schema-\(version)-recovery"
                )
            )
            XCTAssertEqual(live.schemaVersion, BookAtlasSchema.latestVersion)
            XCTAssertEqual(try live.allBooks().map(\.title), [expectedTitle])
        }
    }

    func testRestoredSchemaFourIdentityTriggerInvalidatesIgnoredDuplicatePair() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try BookRepository(
            databaseURL: directory.appendingPathComponent("trigger-source.sqlite")
        )
        let first = try source.create(
            BookDraft(title: "《恢复触发器甲》", author: "虚构作者"),
            at: FictionalLibraryFixtures.timestamp
        )
        let second = try source.create(
            BookDraft(title: "恢复触发器甲", author: "虚构作者"),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(1)
        )
        let backupURL = directory.appendingPathComponent("trigger.bookatlasbackup")
        let coordinator = LibraryBackupCoordinator()
        _ = try coordinator.backup(repository: source, to: backupURL)

        let liveURL = directory.appendingPathComponent("trigger-live.sqlite")
        var live = try BookRepository(databaseURL: liveURL)
        _ = try coordinator.restore(
            backupURL: backupURL,
            databaseURL: liveURL,
            repository: &live,
            recoveryDirectory: directory.appendingPathComponent("trigger-recovery")
        )
        try live.ignoreDuplicatePair(
            first.id,
            second.id,
            disposition: .separateEdition,
            at: FictionalLibraryFixtures.timestamp
        )
        XCTAssertNotNil(try live.ignoredDuplicatePair(between: first.id, and: second.id))

        let restoredSecond = try XCTUnwrap(try live.book(id: second.id))
        try live.update(try restoredSecond.applying(
            BookDraft(title: "《恢复触发器乙》", author: "虚构作者"),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(2)
        ))
        XCTAssertNil(try live.ignoredDuplicatePair(between: first.id, and: second.id))
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

    func testInterruptedReplacementProtocolRecoversDeterministicallyAtEveryPersistentBoundary() throws {
        let scenarios: [(RestoreInjectionPoint, String)] = [
            (.afterConnectionClose, "《中断前原库》"),
            (.afterOriginalPreparedForReplacement, "《中断前原库》"),
            (.afterReplacement, "《中断后新库》")
        ]

        for (point, expectedTitle) in scenarios {
            let directory = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let liveURL = directory.appendingPathComponent("live.sqlite")
            var live = try BookRepository(databaseURL: liveURL)
            _ = try live.create(BookDraft(title: "《中断前原库》", author: "虚构守护者"))
            let backup = try makeBackup(
                in: directory,
                title: "《中断后新库》",
                filename: "incoming.bookatlasbackup"
            )
            let recoveryDirectory = directory.appendingPathComponent("recovery")
            let interrupted = LibraryBackupCoordinator(simulatedTerminationPoint: point)

            XCTAssertThrowsError(
                try interrupted.restore(
                    backupURL: backup,
                    databaseURL: liveURL,
                    repository: &live,
                    recoveryDirectory: recoveryDirectory
                )
            ) {
                XCTAssertEqual($0 as? PortabilityError, .restoreInterrupted)
            }
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: directory
                        .appendingPathComponent(LibraryBackupCoordinator.restoreStateFilename).path
                )
            )

            let restarted = LibraryBackupCoordinator()
            try restarted.recoverInterruptedRestore(databaseURL: liveURL)
            let reopened = try BookRepository(databaseURL: liveURL)
            XCTAssertEqual(try reopened.allBooks().map(\.title), [expectedTitle])
            _ = try reopened.create(BookDraft(title: "《重启后可写》", author: "虚构守护者"))
            XCTAssertEqual(
                try FileManager.default.contentsOfDirectory(
                    at: recoveryDirectory,
                    includingPropertiesForKeys: nil
                ).count,
                1
            )
            let leftovers = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).map(\.lastPathComponent)
            XCTAssertFalse(leftovers.contains(LibraryBackupCoordinator.restoreStateFilename))
            XCTAssertFalse(leftovers.contains { $0.hasPrefix(".book-atlas-restore-old-") })
            XCTAssertFalse(leftovers.contains { $0.hasPrefix(".book-atlas-restore-new-") })
        }
    }

    func testCancellationBeforeSafeReplacementLeavesLiveLibraryOpenAndUnchanged() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let liveURL = directory.appendingPathComponent("live.sqlite")
        var live = try BookRepository(databaseURL: liveURL)
        _ = try live.create(BookDraft(title: "《取消时保留》", author: "虚构守护者"))
        let backup = try makeBackup(
            in: directory,
            title: "《不应安装》",
            filename: "cancel.bookatlasbackup"
        )
        let cancellation = CancellationProbe()
        let phases = RestorePhaseProbe()

        XCTAssertThrowsError(
            try LibraryBackupCoordinator().restore(
                backupURL: backup,
                databaseURL: liveURL,
                repository: &live,
                recoveryDirectory: directory.appendingPathComponent("recovery"),
                cancellation: RestoreCancellation(isCancelled: { cancellation.value }),
                progress: { phase in
                    phases.append(phase)
                    if phase == .staging { cancellation.cancel() }
                }
            )
        ) {
            XCTAssertEqual($0 as? PortabilityError, .cancelled)
        }
        XCTAssertTrue(phases.contains(.creatingRecoveryCopy))
        XCTAssertTrue(phases.contains(.staging))
        XCTAssertFalse(phases.contains(.safeReplacement))
        XCTAssertEqual(try live.allBooks().map(\.title), ["《取消时保留》"])
        _ = try live.create(BookDraft(title: "《取消后可写》", author: "虚构守护者"))
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).contains {
                $0.lastPathComponent.hasPrefix(".book-atlas-restore-new-")
                    || $0.lastPathComponent == LibraryBackupCoordinator.restoreStateFilename
            }
        )
    }

    func testAuthoritativeCancellationRequestBeforeSafeReplacementIsConfirmedByCoordinator() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let liveURL = directory.appendingPathComponent("controlled-live.sqlite")
        var live = try BookRepository(databaseURL: liveURL)
        _ = try live.create(BookDraft(title: "《后台取消保留》", author: "虚构守护者"))
        let backup = try makeBackup(
            in: directory,
            title: "《后台取消不安装》",
            filename: "controlled-cancel.bookatlasbackup"
        )
        let control = RestoreOperationControl()
        let phases = RestorePhaseProbe()

        XCTAssertThrowsError(
            try LibraryBackupCoordinator().restore(
                backupURL: backup,
                databaseURL: liveURL,
                repository: &live,
                recoveryDirectory: directory.appendingPathComponent("controlled-recovery"),
                control: control,
                cancellation: RestoreCancellation(
                    isCancelled: { control.isCancellationRequested }
                ),
                progress: { phase in
                    phases.append(phase)
                    if phase == .staging {
                        XCTAssertEqual(control.requestCancellation(), .accepted)
                    }
                }
            )
        ) {
            XCTAssertEqual($0 as? PortabilityError, .cancelled)
        }
        XCTAssertFalse(phases.contains(.safeReplacement))
        XCTAssertEqual(try live.allBooks().map(\.title), ["《后台取消保留》"])
        _ = try live.create(BookDraft(title: "《后台取消后可写》", author: "虚构守护者"))
    }

    func testOversizedBackupAndRealWriteSpaceErrorsAreMappedBeforeReplacement() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let oversized = directory.appendingPathComponent("oversized.bookatlasbackup")
        XCTAssertTrue(FileManager.default.createFile(atPath: oversized.path, contents: nil))
        let handle = try FileHandle(forWritingTo: oversized)
        try handle.truncate(atOffset: UInt64(LibraryBackupCoordinator.maximumBackupBytes + 1))
        try handle.close()
        XCTAssertThrowsError(try LibraryBackupCoordinator().inspect(oversized)) {
            XCTAssertEqual($0 as? PortabilityError, .backupTooLarge)
        }

        let errors: [(String, Error)] = [
            ("cocoa", NSError(
                domain: NSCocoaErrorDomain,
                code: CocoaError.Code.fileWriteOutOfSpace.rawValue
            )),
            ("posix", NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))),
            ("sqlite", SQLiteDatabaseError.executionFailed(SQLITE_FULL))
        ]
        for (name, injectedError) in errors {
            let scenario = directory.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(
                at: scenario,
                withIntermediateDirectories: true
            )
            let liveURL = scenario.appendingPathComponent("live.sqlite")
            var live = try BookRepository(databaseURL: liveURL)
            _ = try live.create(BookDraft(title: "《空间错误原库》", author: "虚构守护者"))
            let backup = try makeBackup(
                in: scenario,
                title: "《空间错误目标》",
                filename: "space-error.bookatlasbackup"
            )
            let coordinator = LibraryBackupCoordinator(injectedSystemError: { operation in
                operation == .stageRestore ? injectedError : nil
            })
            XCTAssertThrowsError(
                try coordinator.restore(
                    backupURL: backup,
                    databaseURL: liveURL,
                    repository: &live,
                    recoveryDirectory: scenario.appendingPathComponent("recovery")
                ),
                name
            ) {
                XCTAssertEqual($0 as? PortabilityError, .insufficientDiskSpace, name)
            }
            XCTAssertEqual(try live.allBooks().map(\.title), ["《空间错误原库》"], name)
            _ = try live.create(
                BookDraft(title: "《空间错误后仍可写》", author: "虚构守护者")
            )
            let leftovers = try FileManager.default.contentsOfDirectory(
                at: scenario,
                includingPropertiesForKeys: nil
            ).map(\.lastPathComponent)
            XCTAssertFalse(
                leftovers.contains { $0.hasPrefix(".book-atlas-restore-new-") },
                name
            )
            XCTAssertFalse(
                leftovers.contains(LibraryBackupCoordinator.restoreStateFilename),
                name
            )
            XCTAssertEqual(
                try FileManager.default.contentsOfDirectory(
                    at: scenario.appendingPathComponent("recovery"),
                    includingPropertiesForKeys: nil
                ).count,
                1,
                "\(name) keeps one verified recovery copy"
            )
        }
    }

    func testCapacityPreflightRejectsBackupBeforeCreatingTemporarySnapshot() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try BookRepository(
            databaseURL: directory.appendingPathComponent("library.sqlite")
        )
        _ = try repository.create(BookDraft(title: "《容量预检》", author: "虚构守护者"))
        let destination = directory.appendingPathComponent("no-space.bookatlasbackup")
        let coordinator = LibraryBackupCoordinator(availableCapacity: { _ in 0 })
        XCTAssertThrowsError(try coordinator.backup(repository: repository, to: destination)) {
            XCTAssertEqual($0 as? PortabilityError, .insufficientDiskSpace)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).contains { $0.lastPathComponent.hasPrefix(".bookatlas-backup-") }
        )
    }

    func testRestoreMigratesSchemaThreeBackupToCurrentSchemaFive() throws {
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
        XCTAssertEqual(live.schemaVersion, BookAtlasSchema.latestVersion)
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

    private func assertInvalidBackupRejectedBeforeClose(
        validBackup: URL,
        name: String,
        directory: URL,
        mutate: (SQLiteDatabase) throws -> Void
    ) throws {
        let backup = directory.appendingPathComponent("\(name).bookatlasbackup")
        try FileManager.default.copyItem(at: validBackup, to: backup)
        let database = try SQLiteDatabase(path: backup.path)
        try mutate(database)
        XCTAssertTrue(try database.integrityCheck(), name)
        XCTAssertEqual(try database.schemaVersion(), BookAtlasSchema.latestVersion, name)
        try database.close()

        let coordinator = LibraryBackupCoordinator(injectFailure: { point in
            if point == .afterConnectionClose {
                XCTFail("\(name) reached the formal-library close boundary")
            }
        })
        XCTAssertThrowsError(try coordinator.inspect(backup), name) {
            XCTAssertEqual($0 as? PortabilityError, .invalidBackupSchema, name)
        }

        let liveURL = directory.appendingPathComponent("\(name)-live.sqlite")
        var live = try BookRepository(databaseURL: liveURL)
        let originalTitle = "《原库 \(name)》"
        _ = try live.create(BookDraft(title: originalTitle, author: "虚构守护者"))
        XCTAssertThrowsError(
            try coordinator.restore(
                backupURL: backup,
                databaseURL: liveURL,
                repository: &live,
                recoveryDirectory: directory.appendingPathComponent("\(name)-recovery")
            ),
            name
        ) {
            XCTAssertEqual($0 as? PortabilityError, .invalidBackupSchema, name)
        }
        XCTAssertEqual(try live.allBooks().map(\.title), [originalTitle], name)
        _ = try live.create(BookDraft(title: "《仍可写 \(name)》", author: "虚构守护者"))
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

private final class CancellationProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var value: Bool {
        lock.withLock { cancelled }
    }

    func cancel() {
        lock.withLock { cancelled = true }
    }
}

private final class RestorePhaseProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var phases: [RestoreProgressPhase] = []

    func append(_ phase: RestoreProgressPhase) {
        lock.withLock { phases.append(phase) }
    }

    func contains(_ phase: RestoreProgressPhase) -> Bool {
        lock.withLock { phases.contains(phase) }
    }
}
