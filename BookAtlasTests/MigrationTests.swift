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
            [1, 2, 3, 4]
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

        XCTAssertEqual(try migrator.migrate(database), 4)
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

        XCTAssertEqual(try migrator.migrate(database), 4)
        XCTAssertEqual(try migrator.migrate(database), 4)
        XCTAssertEqual(
            try database.query("SELECT version FROM schema_migrations ORDER BY version") { row in row.integer(at: 0) },
            [1, 2, 3, 4]
        )
    }

    func testFailedMigrationRollsBackWithoutRebuildingOrDeletingExistingData() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        let baselineMigrator = DatabaseMigrator()
        try baselineMigrator.migrate(database)
        let repository = try BookRepository(database: database, automaticallyMigrate: false)
        let existing = try repository.create(FictionalLibraryFixtures.draft(), at: FictionalLibraryFixtures.timestamp)

        let failingMigration = DatabaseMigration(
            version: 5,
            statements: [
                "CREATE TABLE migration_failure_probe (id INTEGER PRIMARY KEY)",
                "NOT VALID SQL"
            ]
        )
        let migrator = DatabaseMigrator(migrations: BookAtlasSchema.migrations + [failingMigration])

        XCTAssertThrowsError(try migrator.migrate(database)) { error in
            XCTAssertEqual(error as? DatabaseMigrationError, .migrationFailed(version: 5))
        }
        XCTAssertEqual(try database.schemaVersion(), BookAtlasSchema.latestVersion)
        XCTAssertEqual(try repository.book(id: existing.id), existing)
        XCTAssertEqual(
            try database.query(
                "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'migration_failure_probe'"
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
}
