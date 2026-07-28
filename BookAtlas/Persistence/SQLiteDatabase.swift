import Foundation
import SQLite3

enum SQLiteDatabaseError: Error, Equatable {
    case closed
    case openFailed(Int32)
    case preparationFailed(Int32)
    case bindingFailed(Int32)
    case executionFailed(Int32)
    case unexpectedResult(Int32)
}

enum SQLiteValue {
    case integer(Int64)
    case text(String)
    case null
}

final class SQLiteDatabase {
    private var handle: OpaquePointer?
    private var transactionDepth = 0

    init(path: String) throws {
        var database: OpaquePointer?
        let result = sqlite3_open_v2(
            path,
            &database,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard result == SQLITE_OK, let database else {
            if let database {
                sqlite3_close_v2(database)
            }
            throw SQLiteDatabaseError.openFailed(result)
        }

        handle = database
        try execute("PRAGMA foreign_keys = ON")
    }

    deinit {
        if let handle {
            sqlite3_close_v2(handle)
        }
    }

    func execute(_ sql: String, bindings: [SQLiteValue] = []) throws {
        let statement = try preparedStatement(sql)
        try statement.bind(bindings)
        let result = sqlite3_step(statement.pointer)
        guard result == SQLITE_DONE else {
            throw SQLiteDatabaseError.executionFailed(result)
        }
    }

    func query<T>(
        _ sql: String,
        bindings: [SQLiteValue] = [],
        row: (SQLiteRow) throws -> T
    ) throws -> [T] {
        let statement = try preparedStatement(sql)
        try statement.bind(bindings)

        var values: [T] = []
        while true {
            let result = sqlite3_step(statement.pointer)
            switch result {
            case SQLITE_ROW:
                values.append(try row(SQLiteRow(pointer: statement.pointer)))
            case SQLITE_DONE:
                return values
            default:
                throw SQLiteDatabaseError.executionFailed(result)
            }
        }
    }

    func scalarInt(_ sql: String, bindings: [SQLiteValue] = []) throws -> Int64? {
        try query(sql, bindings: bindings) { row in row.integer(at: 0) }.first
    }

    func schemaVersion() throws -> Int {
        Int(try scalarInt("PRAGMA user_version") ?? 0)
    }

    func changes() throws -> Int {
        guard let handle else {
            throw SQLiteDatabaseError.closed
        }
        return Int(sqlite3_changes(handle))
    }

    func transaction<T>(_ operation: () throws -> T) throws -> T {
        let level = transactionDepth
        let savepoint = "bookatlas_nested_\(level)"
        if level == 0 {
            try execute("BEGIN IMMEDIATE TRANSACTION")
        } else {
            try execute("SAVEPOINT \(savepoint)")
        }
        transactionDepth += 1

        do {
            let value = try operation()
            if level == 0 {
                try execute("COMMIT")
            } else {
                try execute("RELEASE SAVEPOINT \(savepoint)")
            }
            transactionDepth = level
            return value
        } catch {
            transactionDepth = level
            if level == 0 {
                try? execute("ROLLBACK")
            } else {
                try? execute("ROLLBACK TO SAVEPOINT \(savepoint)")
                try? execute("RELEASE SAVEPOINT \(savepoint)")
            }
            throw error
        }
    }

    private func preparedStatement(_ sql: String) throws -> SQLiteStatement {
        guard let handle else {
            throw SQLiteDatabaseError.closed
        }
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard result == SQLITE_OK, let statement else {
            throw SQLiteDatabaseError.preparationFailed(result)
        }
        return SQLiteStatement(pointer: statement)
    }
}

struct SQLiteRow {
    fileprivate let pointer: OpaquePointer

    func integer(at index: Int32) -> Int64 {
        sqlite3_column_int64(pointer, index)
    }

    func string(at index: Int32) -> String? {
        guard sqlite3_column_type(pointer, index) != SQLITE_NULL,
              let value = sqlite3_column_text(pointer, index)
        else {
            return nil
        }
        return String(cString: value)
    }
}

private final class SQLiteStatement {
    let pointer: OpaquePointer

    init(pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        sqlite3_finalize(pointer)
    }

    func bind(_ values: [SQLiteValue]) throws {
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case let .integer(value):
                result = sqlite3_bind_int64(pointer, index, value)
            case let .text(value):
                result = sqlite3_bind_text(pointer, index, value, -1, sqliteTransient)
            case .null:
                result = sqlite3_bind_null(pointer, index)
            }
            guard result == SQLITE_OK else {
                throw SQLiteDatabaseError.bindingFailed(result)
            }
        }
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum BookAtlasDatabaseLocation {
    static func defaultURL(fileManager: FileManager = .default) throws -> URL {
        let supportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        return supportDirectory
            .appendingPathComponent("BookAtlas", isDirectory: true)
            .appendingPathComponent("book-atlas.sqlite", isDirectory: false)
    }
}
