import XCTest
@testable import BookAtlas

final class MigrationTests: XCTestCase {
    func testMigrationFromVersionOnePreservesBookDataAndIsIdempotent() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        let migrator = DatabaseMigrator()

        XCTAssertEqual(try migrator.migrate(database, through: 1), 1)
        let versionOneRepository = try BookRepository(database: database, automaticallyMigrate: false)
        let created = try versionOneRepository.create(
            FictionalLibraryFixtures.draft(),
            at: FictionalLibraryFixtures.timestamp
        )

        XCTAssertEqual(try migrator.migrate(database), BookAtlasSchema.latestVersion)
        XCTAssertEqual(try versionOneRepository.book(id: created.id), created)
        XCTAssertEqual(try migrator.migrate(database), BookAtlasSchema.latestVersion)
        XCTAssertEqual(
            try database.query("SELECT version FROM schema_migrations ORDER BY version") { row in row.integer(at: 0) },
            [1, 2, 3, 4, 5]
        )
    }

    func testVersionThreeAddsQueryIndexesWithoutChangingBooks() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        let migrator = DatabaseMigrator()
        try migrator.migrate(database, through: 2)
        let repository = try BookRepository(database: database, automaticallyMigrate: false)
        let book = try repository.create(
            FictionalLibraryFixtures.draft(),
            at: FictionalLibraryFixtures.timestamp
        )

        XCTAssertEqual(try migrator.migrate(database), BookAtlasSchema.latestVersion)
        XCTAssertEqual(try repository.book(id: book.id), book)
        XCTAssertEqual(
            try database.query(
                """
                SELECT name FROM sqlite_master
                WHERE type = 'index' AND name IN (
                    'idx_books_original_title',
                    'idx_books_created_order',
                    'idx_books_updated_order',
                    'idx_books_priority_order'
                )
                ORDER BY name
                """
            ) { row in row.string(at: 0) },
            [
                "idx_books_created_order",
                "idx_books_original_title",
                "idx_books_priority_order",
                "idx_books_updated_order"
            ]
        )
    }

    func testVersionFourBackfillsDuplicateKeysAndCreatesIgnoreStorage() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        let migrator = DatabaseMigrator()
        try migrator.migrate(database, through: 3)
        let repository = try BookRepository(database: database, automaticallyMigrate: false)
        let book = try repository.create(
            BookDraft(
                title: "《雾港档案：潮汐》",
                originalTitle: "Mist Harbor Files",
                author: "林雾 / 许岸",
                isbn: "978-0-00000-000-2"
            ),
            at: FictionalLibraryFixtures.timestamp
        )

        XCTAssertEqual(try migrator.migrate(database, through: 4), 4)
        let rows = try database.query(
            """
            SELECT valid_isbn, normalized_title, normalized_author, normalized_original_title
            FROM book_duplicate_keys WHERE book_id = ?
            """,
            bindings: [.text(book.id.uuidString)]
        ) { row in
            (
                row.string(at: 0),
                row.string(at: 1),
                row.string(at: 2),
                row.string(at: 3)
            )
        }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].0, "9780000000002")
        XCTAssertEqual(rows[0].1, DuplicateTextNormalizer.titleKey(book.title))
        XCTAssertEqual(rows[0].2, DuplicateTextNormalizer.authorKey(book.author))
        XCTAssertEqual(rows[0].3, DuplicateTextNormalizer.titleKey(book.originalTitle!))
        XCTAssertFalse(
            try database.query(
                "SELECT token FROM book_duplicate_title_tokens WHERE book_id = ?",
                bindings: [.text(book.id.uuidString)]
            ) { row in row.string(at: 0) }.isEmpty
        )
        XCTAssertEqual(
            try database.query(
                "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'ignored_duplicate_pairs'"
            ) { row in row.string(at: 0) },
            ["ignored_duplicate_pairs"]
        )
    }

    func testNewDatabaseCreatesLatestSchemaAndRepeatedMigrationIsSafe() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        let migrator = DatabaseMigrator()

        XCTAssertEqual(try migrator.migrate(database), 5)
        XCTAssertEqual(try migrator.migrate(database), 5)
        XCTAssertEqual(
            try database.query("SELECT version FROM schema_migrations ORDER BY version") { row in row.integer(at: 0) },
            [1, 2, 3, 4, 5]
        )
    }

    func testVersionFiveAddsLocalFileReferencesAndPreservesSchemaFourData() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        let migrator = DatabaseMigrator()
        try migrator.migrate(database, through: 4)
        let repository = try BookRepository(database: database, automaticallyMigrate: false)
        let book = try repository.create(
            FictionalLibraryFixtures.draft(),
            at: FictionalLibraryFixtures.timestamp
        )

        XCTAssertEqual(try migrator.migrate(database), 5)
        XCTAssertEqual(try repository.book(id: book.id), book)
        XCTAssertEqual(
            try database.query(
                """
                SELECT name FROM sqlite_master
                WHERE type = 'table' AND name = 'local_file_references'
                """
            ) { $0.string(at: 0) },
            ["local_file_references"]
        )
        XCTAssertEqual(
            try database.query(
                """
                SELECT name FROM sqlite_master
                WHERE type = 'index' AND name = 'idx_local_file_references_book_id'
                """
            ) { $0.string(at: 0) },
            ["idx_local_file_references_book_id"]
        )
    }

    func testEveryHistoricalSchemaMigratesToFiveWithAllAvailableDomainData() throws {
        for version in 1 ... BookAtlasSchema.latestVersion {
            let database = try SQLiteDatabase(path: ":memory:")
            let migrator = DatabaseMigrator()
            try migrator.migrate(database, through: version)
            let repository = try BookRepository(
                database: database,
                automaticallyMigrate: false
            )
            let timestamp = FictionalLibraryFixtures.timestamp
            let first = try repository.create(
                BookDraft(
                    title: "《迁移矩阵 \(version) 甲》",
                    author: "固定虚构作者",
                    note: "固定虚构备注"
                ),
                id: deterministicID(version: version, suffix: 1),
                at: timestamp
            )
            let second = try repository.create(
                BookDraft(
                    title: "《迁移矩阵 \(version) 乙》",
                    author: "固定虚构作者"
                ),
                id: deterministicID(version: version, suffix: 2),
                at: timestamp.addingTimeInterval(1)
            )
            let tag = try repository.createTag(
                try Tag(
                    id: deterministicID(version: version, suffix: 3),
                    name: "固定迁移标签 \(version)",
                    createdAt: timestamp
                )
            )
            let collection = try BookCollection(
                id: deterministicID(version: version, suffix: 4),
                name: "固定迁移书单 \(version)",
                description: "固定虚构说明",
                createdAt: timestamp
            )
            if version == 1 {
                try database.execute(
                    """
                    INSERT INTO book_collections (id, name, created_at, updated_at)
                    VALUES (?, ?, ?, ?)
                    """,
                    bindings: [
                        .text(collection.id.uuidString),
                        .text(collection.name),
                        .text(StorageDateCodec.encode(collection.createdAt)),
                        .text(StorageDateCodec.encode(collection.updatedAt))
                    ]
                )
            } else {
                _ = try repository.createCollection(collection)
            }
            let source = try repository.createSource(
                try RecommendationSource(
                    id: deterministicID(version: version, suffix: 5),
                    name: "固定迁移来源 \(version)",
                    details: "固定虚构来源说明",
                    createdAt: timestamp
                )
            )
            let link = try repository.addExternalLink(
                try ExternalLink(
                    id: deterministicID(version: version, suffix: 6),
                    bookID: first.id,
                    kind: .web,
                    label: "固定虚构链接",
                    value: "https://example.invalid/migration-\(version)",
                    createdAt: timestamp
                )
            )
            let relation = try repository.addManualRelation(
                try ManualBookRelation(
                    id: deterministicID(version: version, suffix: 7),
                    sourceBookID: first.id,
                    targetBookID: second.id,
                    kind: .related,
                    note: "固定虚构关系说明",
                    createdAt: timestamp
                )
            )
            try repository.attach(tagID: tag.id, toBookID: first.id)
            try repository.add(bookID: first.id, toCollectionID: collection.id)
            try repository.attach(sourceID: source.id, toBookID: first.id)

            if version >= 4 {
                try repository.ignoreDuplicatePair(
                    first.id,
                    second.id,
                    disposition: .separateEdition,
                    at: timestamp
                )
            }
            let localFile: LocalFileReference?
            if version >= 5 {
                let reference = try LocalFileReference(
                    id: deterministicID(version: version, suffix: 8),
                    bookID: first.id,
                    displayName: "固定虚构阅读副本.pdf",
                    bookmarkData: Data("fixed-fictional-bookmark".utf8),
                    createdAt: timestamp
                )
                localFile = try repository.addLocalFileReference(reference)
            } else {
                localFile = nil
            }

            XCTAssertEqual(try migrator.migrate(database), BookAtlasSchema.latestVersion)
            XCTAssertEqual(try migrator.migrate(database), BookAtlasSchema.latestVersion)
            XCTAssertEqual(try repository.book(id: first.id)?.note, "固定虚构备注")
            XCTAssertEqual(try repository.tags(forBookID: first.id), [tag])
            let migratedCollections = try repository.collections(forBookID: first.id)
            XCTAssertEqual(migratedCollections.map(\.id), [collection.id])
            XCTAssertEqual(
                migratedCollections.first?.description,
                version == 1 ? nil : collection.description
            )
            XCTAssertEqual(try repository.sources(forBookID: first.id), [source])
            XCTAssertEqual(try repository.externalLinks(forBookID: first.id), [link])
            XCTAssertEqual(try repository.manualRelations(forBookID: first.id), [relation])
            XCTAssertEqual(
                try repository.ignoredDuplicatePair(between: first.id, and: second.id)?
                    .disposition,
                version >= 4 ? .separateEdition : nil
            )
            XCTAssertEqual(
                try repository.localFileReferences(forBookID: first.id),
                localFile.map { [$0] } ?? []
            )
            XCTAssertEqual(
                try database.query(
                    """
                    SELECT book_id FROM book_duplicate_keys
                    WHERE book_id IN (?, ?)
                    ORDER BY book_id
                    """,
                    bindings: [.text(first.id.uuidString), .text(second.id.uuidString)]
                ) { $0.string(at: 0) },
                [first.id.uuidString, second.id.uuidString].sorted()
            )
            XCTAssertEqual(
                try database.query(
                    "SELECT version FROM schema_migrations ORDER BY version"
                ) { $0.integer(at: 0) },
                [1, 2, 3, 4, 5]
            )
        }
    }

    func testFailedMigrationRollsBackWithoutRebuildingOrDeletingExistingData() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        let baselineMigrator = DatabaseMigrator()
        try baselineMigrator.migrate(database, through: 4)
        let repository = try BookRepository(database: database, automaticallyMigrate: false)
        let existing = try repository.create(FictionalLibraryFixtures.draft(), at: FictionalLibraryFixtures.timestamp)

        let failingMigration = DatabaseMigration(
            version: 5,
            statements: [
                "CREATE TABLE migration_failure_probe (id INTEGER PRIMARY KEY)",
                "NOT VALID SQL"
            ]
        )
        let migrator = DatabaseMigrator(
            migrations: Array(BookAtlasSchema.migrations.prefix(4)) + [failingMigration]
        )

        XCTAssertThrowsError(try migrator.migrate(database)) { error in
            XCTAssertEqual(error as? DatabaseMigrationError, .migrationFailed(version: 5))
        }
        XCTAssertEqual(try database.schemaVersion(), 4)
        XCTAssertEqual(try repository.book(id: existing.id), existing)
        XCTAssertEqual(
            try database.query(
                "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'migration_failure_probe'"
            ) { row in row.string(at: 0) },
            []
        )
        XCTAssertEqual(
            try database.query(
                """
                SELECT name FROM sqlite_master
                WHERE type = 'table' AND name = 'local_file_references'
                """
            ) { row in row.string(at: 0) },
            []
        )
    }

    func testFutureSchemaVersionIsRejectedWithoutResettingTheDatabase() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        let migrator = DatabaseMigrator()
        try migrator.migrate(database)
        try database.execute("PRAGMA user_version = 99")

        XCTAssertThrowsError(try migrator.migrate(database)) { error in
            XCTAssertEqual(error as? DatabaseMigrationError, .unsupportedFutureVersion(99))
        }
        XCTAssertEqual(try database.schemaVersion(), 99)
    }

    private func deterministicID(version: Int, suffix: Int) -> UUID {
        UUID(
            uuidString: String(
                format: "90000000-0000-%04d-0000-%012d",
                version,
                suffix
            )
        )!
    }
}
