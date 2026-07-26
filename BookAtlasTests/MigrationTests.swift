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
            [1, 2]
        )
    }

    func testFailedMigrationRollsBackWithoutRebuildingOrDeletingExistingData() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        let baselineMigrator = DatabaseMigrator()
        try baselineMigrator.migrate(database)
        let repository = try BookRepository(database: database, automaticallyMigrate: false)
        let existing = try repository.create(FictionalLibraryFixtures.draft(), at: FictionalLibraryFixtures.timestamp)

        let failingMigration = DatabaseMigration(
            version: 3,
            statements: [
                "CREATE TABLE migration_failure_probe (id INTEGER PRIMARY KEY)",
                "NOT VALID SQL"
            ]
        )
        let migrator = DatabaseMigrator(migrations: BookAtlasSchema.migrations + [failingMigration])

        XCTAssertThrowsError(try migrator.migrate(database)) { error in
            XCTAssertEqual(error as? DatabaseMigrationError, .migrationFailed(version: 3))
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
