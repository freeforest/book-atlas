import SpikeCore
import XCTest

final class SQLiteBookStoreTests: XCTestCase {
    func testCRUDRelationshipsUniqueConstraintAndCascade() throws {
        let store = try SQLiteBookStore()
        let book = SpikeBook(
            id: "book-1",
            title: "雾港档案",
            normalizedTitle: "雾港档案"
        )
        try store.insert(book)
        try store.insert(
            SpikeAuthor(id: "author-1", name: "林汐远"),
            forBookID: book.id
        )

        XCTAssertEqual(try store.book(id: book.id), book)
        XCTAssertEqual(
            try store.authors(forBookID: book.id),
            [SpikeAuthor(id: "author-1", name: "林汐远")]
        )

        try store.updateTitle(id: book.id, title: "雾港档案·修订")
        XCTAssertEqual(try store.book(id: book.id)?.title, "雾港档案·修订")

        XCTAssertThrowsError(
            try store.insert(
                SpikeBook(
                    id: "book-2",
                    title: "重复记录",
                    normalizedTitle: "雾港档案"
                )
            )
        )

        try store.deleteBook(id: book.id)
        XCTAssertNil(try store.book(id: book.id))
        XCTAssertTrue(try store.authors(forBookID: book.id).isEmpty)
    }

    func testTransactionRollback() throws {
        let store = try SQLiteBookStore()
        XCTAssertThrowsError(try store.rollbackProbe())
        XCTAssertEqual(try store.bookCount(), 0)
    }

    func testIndependentInMemoryDatabases() throws {
        let first = try SQLiteBookStore()
        let second = try SQLiteBookStore()
        try first.insert(
            SpikeBook(
                id: "isolated",
                title: "静默算法",
                normalizedTitle: "静默算法"
            )
        )
        XCTAssertEqual(try first.bookCount(), 1)
        XCTAssertEqual(try second.bookCount(), 0)
    }

    func testV1ToV2MigrationAndFailureRollback() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("migration.sqlite").path

        do {
            let v1 = try SQLiteBookStore(path: path, targetVersion: 1)
            try v1.insertV1Fixture(
                SpikeBook(
                    id: "migration",
                    title: "北岸来信",
                    normalizedTitle: "北岸来信"
                )
            )
            XCTAssertEqual(try v1.schemaVersion(), 1)
        }

        let v2 = try SQLiteBookStore(path: path)
        XCTAssertEqual(try v2.book(id: "migration")?.notes, "")
        XCTAssertEqual(try v2.schemaVersion(), 2)

        XCTAssertThrowsError(
            try SQLiteBookStore(path: path, targetVersion: 3, failAtVersion: 3)
        )
        XCTAssertFalse(try v2.hasTable("mustRollBack"))
    }

    func testBackupCanBeOpened() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: folder) }

        let sourcePath = folder.appendingPathComponent("source.sqlite").path
        let backupPath = folder.appendingPathComponent("backup.sqlite").path
        let source = try SQLiteBookStore(path: sourcePath)
        try source.insert(
            SpikeBook(
                id: "backup",
                title: "机器与花园",
                normalizedTitle: "机器与花园"
            )
        )
        try source.backup(to: backupPath)

        let backup = try SQLiteBookStore(path: backupPath)
        XCTAssertEqual(try backup.bookCount(), 1)
        XCTAssertEqual(try backup.book(id: "backup")?.title, "机器与花园")
    }
}
