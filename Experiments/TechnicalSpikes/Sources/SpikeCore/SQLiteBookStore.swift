import Foundation
import SQLite3

public struct SpikeBook: Equatable, Sendable {
    public let id: String
    public var title: String
    public var normalizedTitle: String
    public var notes: String

    public init(
        id: String,
        title: String,
        normalizedTitle: String,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.normalizedTitle = normalizedTitle
        self.notes = notes
    }
}

public struct SpikeAuthor: Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public enum SpikeStoreError: Error {
    case openFailed
    case sqliteFailure
    case intentionalRollback
    case intentionalMigrationFailure
}

public final class SQLiteBookStore: @unchecked Sendable {
    private let connection: OpaquePointer
    private let lock = NSLock()

    public init(
        path: String? = nil,
        targetVersion: Int = 2,
        failAtVersion: Int? = nil
    ) throws {
        var database: OpaquePointer?
        let location = path ?? ":memory:"
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(location, &database, flags, nil) == SQLITE_OK,
              let database else {
            throw SpikeStoreError.openFailed
        }
        connection = database
        try execute("PRAGMA foreign_keys = ON")
        try migrate(to: targetVersion, failAtVersion: failAtVersion)
    }

    deinit {
        sqlite3_close(connection)
    }

    public func insert(_ book: SpikeBook) throws {
        try withConnection {
            try execute(
                """
                INSERT INTO book (id, title, normalizedTitle, notes)
                VALUES (?, ?, ?, ?)
                """,
                arguments: [book.id, book.title, book.normalizedTitle, book.notes]
            )
        }
    }

    public func insertV1Fixture(_ book: SpikeBook) throws {
        try withConnection {
            try execute(
                """
                INSERT INTO book (id, title, normalizedTitle)
                VALUES (?, ?, ?)
                """,
                arguments: [book.id, book.title, book.normalizedTitle]
            )
        }
    }

    public func insert(_ author: SpikeAuthor, forBookID bookID: String) throws {
        try withConnection {
            try execute(
                "INSERT INTO author (id, name) VALUES (?, ?)",
                arguments: [author.id, author.name]
            )
            try execute(
                "INSERT INTO bookAuthor (bookID, authorID) VALUES (?, ?)",
                arguments: [bookID, author.id]
            )
        }
    }

    public func book(id: String) throws -> SpikeBook? {
        try withConnection {
            let statement = try prepare(
                "SELECT id, title, normalizedTitle, notes FROM book WHERE id = ?",
                arguments: [id]
            )
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return SpikeBook(
                id: stringColumn(statement, at: 0),
                title: stringColumn(statement, at: 1),
                normalizedTitle: stringColumn(statement, at: 2),
                notes: stringColumn(statement, at: 3)
            )
        }
    }

    public func authors(forBookID bookID: String) throws -> [SpikeAuthor] {
        try withConnection {
            let statement = try prepare(
                """
                SELECT author.id, author.name
                FROM author
                JOIN bookAuthor ON bookAuthor.authorID = author.id
                WHERE bookAuthor.bookID = ?
                ORDER BY author.name
                """,
                arguments: [bookID]
            )
            defer { sqlite3_finalize(statement) }
            var authors: [SpikeAuthor] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                authors.append(
                    SpikeAuthor(
                        id: stringColumn(statement, at: 0),
                        name: stringColumn(statement, at: 1)
                    )
                )
            }
            return authors
        }
    }

    public func updateTitle(id: String, title: String) throws {
        try withConnection {
            try execute(
                "UPDATE book SET title = ? WHERE id = ?",
                arguments: [title, id]
            )
        }
    }

    public func deleteBook(id: String) throws {
        try withConnection {
            try execute("DELETE FROM book WHERE id = ?", arguments: [id])
        }
    }

    public func bookCount() throws -> Int {
        try withConnection {
            let statement = try prepare("SELECT COUNT(*) FROM book")
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW else {
                throw SpikeStoreError.sqliteFailure
            }
            return Int(sqlite3_column_int(statement, 0))
        }
    }

    public func insertBatch(count: Int) throws {
        try withConnection {
            try execute("BEGIN IMMEDIATE")
            do {
                for index in 0..<count {
                    try execute(
                        """
                        INSERT INTO book (id, title, normalizedTitle, notes)
                        VALUES (?, ?, ?, '')
                        """,
                        arguments: [
                            "fiction-\(index)",
                            "虚构图书 \(index)",
                            "fictional-book-\(index)"
                        ]
                    )
                }
                try execute("COMMIT")
            } catch {
                try? execute("ROLLBACK")
                throw error
            }
        }
    }

    public func rollbackProbe() throws {
        try withConnection {
            try execute("BEGIN IMMEDIATE")
            do {
                try execute(
                    """
                    INSERT INTO book (id, title, normalizedTitle, notes)
                    VALUES ('rollback', '回滚测试', 'rollback-test', '')
                    """
                )
                throw SpikeStoreError.intentionalRollback
            } catch {
                try? execute("ROLLBACK")
                throw error
            }
        }
    }

    public func backup(to destinationPath: String) throws {
        try withConnection {
            var destination: OpaquePointer?
            defer {
                if let destination {
                    sqlite3_close(destination)
                }
            }
            guard sqlite3_open_v2(
                destinationPath,
                &destination,
                SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
                nil
            ) == SQLITE_OK, let destination else {
                throw SpikeStoreError.openFailed
            }
            guard let backup = sqlite3_backup_init(
                destination,
                "main",
                connection,
                "main"
            ) else {
                throw SpikeStoreError.sqliteFailure
            }
            let stepResult = sqlite3_backup_step(backup, -1)
            let finishResult = sqlite3_backup_finish(backup)
            guard stepResult == SQLITE_DONE, finishResult == SQLITE_OK else {
                throw SpikeStoreError.sqliteFailure
            }
        }
    }

    public func schemaVersion() throws -> Int {
        try withConnection {
            let statement = try prepare("PRAGMA user_version")
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW else {
                throw SpikeStoreError.sqliteFailure
            }
            return Int(sqlite3_column_int(statement, 0))
        }
    }

    public func hasTable(_ table: String) throws -> Bool {
        try withConnection {
            let statement = try prepare(
                "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?",
                arguments: [table]
            )
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW else {
                throw SpikeStoreError.sqliteFailure
            }
            return sqlite3_column_int(statement, 0) == 1
        }
    }

    private func migrate(to targetVersion: Int, failAtVersion: Int?) throws {
        guard (1...3).contains(targetVersion) else {
            throw SpikeStoreError.sqliteFailure
        }
        var version = try schemaVersion()
        while version < targetVersion {
            let nextVersion = version + 1
            try execute("BEGIN IMMEDIATE")
            do {
                switch nextVersion {
                case 1:
                    try execute(
                        """
                        CREATE TABLE book (
                            id TEXT PRIMARY KEY,
                            title TEXT NOT NULL,
                            normalizedTitle TEXT NOT NULL UNIQUE
                        )
                        """
                    )
                    try execute("CREATE INDEX book_on_title ON book(title)")
                    try execute(
                        """
                        CREATE TABLE author (
                            id TEXT PRIMARY KEY,
                            name TEXT NOT NULL
                        )
                        """
                    )
                    try execute(
                        """
                        CREATE TABLE bookAuthor (
                            bookID TEXT NOT NULL REFERENCES book(id) ON DELETE CASCADE,
                            authorID TEXT NOT NULL REFERENCES author(id) ON DELETE CASCADE,
                            PRIMARY KEY (bookID, authorID)
                        )
                        """
                    )
                case 2:
                    try execute(
                        "ALTER TABLE book ADD COLUMN notes TEXT NOT NULL DEFAULT ''"
                    )
                    try execute(
                        """
                        CREATE TABLE source (
                            id INTEGER PRIMARY KEY,
                            bookID TEXT NOT NULL REFERENCES book(id) ON DELETE CASCADE,
                            kind TEXT NOT NULL
                        )
                        """
                    )
                    try execute("CREATE INDEX source_on_book ON source(bookID)")
                case 3:
                    try execute("CREATE TABLE mustRollBack (id INTEGER PRIMARY KEY)")
                    if failAtVersion == nextVersion {
                        throw SpikeStoreError.intentionalMigrationFailure
                    }
                default:
                    throw SpikeStoreError.sqliteFailure
                }
                try execute("PRAGMA user_version = \(nextVersion)")
                try execute("COMMIT")
                version = nextVersion
            } catch {
                try? execute("ROLLBACK")
                throw error
            }
        }
    }

    private func withConnection<T>(_ operation: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }

    private func execute(_ sql: String, arguments: [String] = []) throws {
        let statement = try prepare(sql, arguments: arguments)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SpikeStoreError.sqliteFailure
        }
    }

    private func prepare(
        _ sql: String,
        arguments: [String] = []
    ) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw SpikeStoreError.sqliteFailure
        }
        for (offset, argument) in arguments.enumerated() {
            let result = argument.withCString {
                sqlite3_bind_text(
                    statement,
                    Int32(offset + 1),
                    $0,
                    -1,
                    sqliteTransientDestructor
                )
            }
            guard result == SQLITE_OK else {
                sqlite3_finalize(statement)
                throw SpikeStoreError.sqliteFailure
            }
        }
        return statement
    }

    private func stringColumn(_ statement: OpaquePointer, at index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: text)
    }
}

private let sqliteTransientDestructor = unsafeBitCast(
    -1,
    to: sqlite3_destructor_type.self
)

