import Foundation

enum DatabaseMigrationError: Error, Equatable {
    case unsupportedFutureVersion(Int)
    case invalidTargetVersion(Int)
    case migrationFailed(version: Int)
}

struct DatabaseMigration: Equatable {
    let version: Int
    let statements: [String]
}

enum BookAtlasSchema {
    static let latestVersion = 2

    static let migrations: [DatabaseMigration] = [
        DatabaseMigration(
            version: 1,
            statements: [
                """
                CREATE TABLE schema_migrations (
                    version INTEGER PRIMARY KEY NOT NULL,
                    applied_at TEXT NOT NULL
                )
                """,
                """
                CREATE TABLE books (
                    id TEXT PRIMARY KEY NOT NULL,
                    title TEXT NOT NULL CHECK (length(trim(title)) > 0),
                    original_title TEXT,
                    author TEXT NOT NULL CHECK (length(trim(author)) > 0),
                    isbn TEXT,
                    publisher TEXT,
                    publication_date TEXT,
                    kind TEXT NOT NULL,
                    reading_status TEXT NOT NULL CHECK (reading_status IN ('wish_to_read', 'reading', 'read', 'paused', 'abandoned', 'reference', 'archived')),
                    priority INTEGER CHECK (priority IS NULL OR priority BETWEEN 1 AND 5),
                    note TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    started_at TEXT,
                    finished_at TEXT
                )
                """,
                "CREATE INDEX idx_books_reading_status ON books(reading_status)",
                "CREATE INDEX idx_books_title ON books(title)",
                "CREATE INDEX idx_books_author ON books(author)",
                "CREATE INDEX idx_books_isbn ON books(isbn)",
                """
                CREATE TABLE tags (
                    id TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK (length(trim(name)) > 0),
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """,
                """
                CREATE TABLE book_tags (
                    book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
                    tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
                    PRIMARY KEY (book_id, tag_id)
                )
                """,
                "CREATE INDEX idx_book_tags_tag_id ON book_tags(tag_id)",
                """
                CREATE TABLE book_collections (
                    id TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK (length(trim(name)) > 0),
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """,
                """
                CREATE TABLE book_collections_books (
                    collection_id TEXT NOT NULL REFERENCES book_collections(id) ON DELETE CASCADE,
                    book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
                    PRIMARY KEY (collection_id, book_id)
                )
                """,
                "CREATE INDEX idx_collection_books_book_id ON book_collections_books(book_id)",
                """
                CREATE TABLE recommendation_sources (
                    id TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK (length(trim(name)) > 0),
                    details TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """,
                """
                CREATE TABLE book_sources (
                    book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
                    source_id TEXT NOT NULL REFERENCES recommendation_sources(id) ON DELETE CASCADE,
                    PRIMARY KEY (book_id, source_id)
                )
                """,
                "CREATE INDEX idx_book_sources_source_id ON book_sources(source_id)",
                """
                CREATE TABLE external_links (
                    id TEXT PRIMARY KEY NOT NULL,
                    book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
                    kind TEXT NOT NULL CHECK (kind IN ('web', 'local_authorization')),
                    label TEXT,
                    value TEXT NOT NULL CHECK (length(trim(value)) > 0),
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    UNIQUE (book_id, kind, value)
                )
                """,
                "CREATE INDEX idx_external_links_book_id ON external_links(book_id)",
                """
                CREATE TABLE manual_book_relations (
                    id TEXT PRIMARY KEY NOT NULL,
                    source_book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
                    target_book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
                    relation_kind TEXT NOT NULL,
                    note TEXT,
                    created_at TEXT NOT NULL,
                    CHECK (source_book_id <> target_book_id),
                    UNIQUE (source_book_id, target_book_id, relation_kind)
                )
                """,
                "CREATE INDEX idx_manual_relations_source ON manual_book_relations(source_book_id)",
                "CREATE INDEX idx_manual_relations_target ON manual_book_relations(target_book_id)"
            ]
        ),
        DatabaseMigration(
            version: 2,
            statements: [
                "ALTER TABLE book_collections ADD COLUMN description TEXT"
            ]
        )
    ]
}

final class DatabaseMigrator {
    private let migrations: [DatabaseMigration]

    init(migrations: [DatabaseMigration] = BookAtlasSchema.migrations) {
        self.migrations = migrations.sorted { $0.version < $1.version }
    }

    @discardableResult
    func migrate(_ database: SQLiteDatabase, through targetVersion: Int? = nil) throws -> Int {
        let currentVersion = try database.schemaVersion()
        let latestVersion = migrations.last?.version ?? 0
        let requestedVersion = targetVersion ?? latestVersion

        guard currentVersion <= latestVersion else {
            throw DatabaseMigrationError.unsupportedFutureVersion(currentVersion)
        }
        guard requestedVersion >= currentVersion, requestedVersion <= latestVersion else {
            throw DatabaseMigrationError.invalidTargetVersion(requestedVersion)
        }

        for migration in migrations where migration.version > currentVersion && migration.version <= requestedVersion {
            do {
                try database.transaction {
                    for statement in migration.statements {
                        try database.execute(statement)
                    }
                    try database.execute(
                        "INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)",
                        bindings: [.integer(Int64(migration.version)), .text(StorageDateCodec.encode(Date()))]
                    )
                    try database.execute("PRAGMA user_version = \(migration.version)")
                }
            } catch {
                throw DatabaseMigrationError.migrationFailed(version: migration.version)
            }
        }

        return try database.schemaVersion()
    }
}

enum BookRepositoryError: Error, Equatable {
    case invalidStoredRecord
    case bookNotFound
}

final class BookRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase, automaticallyMigrate: Bool = true) throws {
        self.database = database
        if automaticallyMigrate {
            try DatabaseMigrator().migrate(database)
        }
    }

    convenience init(databaseURL: URL) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try self.init(database: SQLiteDatabase(path: databaseURL.path))
    }

    static func inMemory() throws -> BookRepository {
        try BookRepository(database: SQLiteDatabase(path: ":memory:"))
    }

    var schemaVersion: Int {
        (try? database.schemaVersion()) ?? 0
    }

    func transaction<T>(_ operation: () throws -> T) throws -> T {
        try database.transaction(operation)
    }

    @discardableResult
    func create(_ draft: BookDraft, id: UUID = UUID(), at date: Date = Date()) throws -> Book {
        let book = try Book(id: id, draft: draft, createdAt: date)
        try insert(book)
        return book
    }

    func insert(_ book: Book) throws {
        try database.execute(
            """
            INSERT INTO books (
                id, title, original_title, author, isbn, publisher, publication_date,
                kind, reading_status, priority, note, created_at, updated_at, started_at, finished_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: bookBindings(book)
        )
    }

    func book(id: UUID) throws -> Book? {
        try database.query(
            "SELECT \(bookColumns) FROM books WHERE id = ?",
            bindings: [.text(id.uuidString)],
            row: decodeBook
        ).first
    }

    func update(_ book: Book) throws {
        try database.execute(
            """
            UPDATE books SET
                title = ?, original_title = ?, author = ?, isbn = ?, publisher = ?, publication_date = ?,
                kind = ?, reading_status = ?, priority = ?, note = ?, updated_at = ?, started_at = ?, finished_at = ?
            WHERE id = ?
            """,
            bindings: [
                .text(book.title), nullable(book.originalTitle), .text(book.author), nullable(book.isbn),
                nullable(book.publisher), nullable(book.publicationDate?.storageValue), .text(book.kind.rawValue),
                .text(book.readingStatus.rawValue), nullable(book.priority.map { Int64($0.rawValue) }),
                nullable(book.note), .text(StorageDateCodec.encode(book.updatedAt)),
                nullable(book.startedAt.map(StorageDateCodec.encode)), nullable(book.finishedAt.map(StorageDateCodec.encode)),
                .text(book.id.uuidString)
            ]
        )
        guard try database.changes() == 1 else {
            throw BookRepositoryError.bookNotFound
        }
    }

    func deleteBook(id: UUID) throws {
        try database.execute("DELETE FROM books WHERE id = ?", bindings: [.text(id.uuidString)])
        guard try database.changes() == 1 else {
            throw BookRepositoryError.bookNotFound
        }
    }

    func list(limit: Int = 100) throws -> [Book] {
        try list(readingStatus: nil, limit: limit)
    }

    func list(readingStatus: ReadingStatus, limit: Int = 100) throws -> [Book] {
        try list(readingStatus: Optional(readingStatus), limit: limit)
    }

    func search(_ keyword: String, limit: Int = 100) throws -> [Book] {
        let limit = try checkedLimit(limit)
        let query = "%\(escapeLike(keyword.trimmingCharacters(in: .whitespacesAndNewlines)))%"
        return try database.query(
            """
            SELECT \(bookColumns) FROM books
            WHERE title LIKE ? ESCAPE '\\' COLLATE NOCASE
               OR original_title LIKE ? ESCAPE '\\' COLLATE NOCASE
               OR author LIKE ? ESCAPE '\\' COLLATE NOCASE
               OR isbn LIKE ? ESCAPE '\\' COLLATE NOCASE
               OR publisher LIKE ? ESCAPE '\\' COLLATE NOCASE
            ORDER BY updated_at DESC, id ASC
            LIMIT ?
            """,
            bindings: [.text(query), .text(query), .text(query), .text(query), .text(query), .integer(Int64(limit))],
            row: decodeBook
        )
    }

    @discardableResult
    func createTag(_ tag: Tag) throws -> Tag {
        try database.execute(
            "INSERT INTO tags (id, name, created_at, updated_at) VALUES (?, ?, ?, ?)",
            bindings: [.text(tag.id.uuidString), .text(tag.name), .text(StorageDateCodec.encode(tag.createdAt)), .text(StorageDateCodec.encode(tag.updatedAt))]
        )
        return tag
    }

    func attach(tagID: UUID, toBookID bookID: UUID) throws {
        try database.execute(
            "INSERT OR IGNORE INTO book_tags (book_id, tag_id) VALUES (?, ?)",
            bindings: [.text(bookID.uuidString), .text(tagID.uuidString)]
        )
    }

    func detach(tagID: UUID, fromBookID bookID: UUID) throws {
        try database.execute(
            "DELETE FROM book_tags WHERE book_id = ? AND tag_id = ?",
            bindings: [.text(bookID.uuidString), .text(tagID.uuidString)]
        )
    }

    func tags(forBookID bookID: UUID) throws -> [Tag] {
        try database.query(
            """
            SELECT tags.id, tags.name, tags.created_at, tags.updated_at
            FROM tags
            INNER JOIN book_tags ON book_tags.tag_id = tags.id
            WHERE book_tags.book_id = ?
            ORDER BY tags.name COLLATE NOCASE, tags.id
            """,
            bindings: [.text(bookID.uuidString)],
            row: decodeTag
        )
    }

    @discardableResult
    func createCollection(_ collection: BookCollection) throws -> BookCollection {
        try database.execute(
            "INSERT INTO book_collections (id, name, description, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
            bindings: [
                .text(collection.id.uuidString), .text(collection.name), nullable(collection.description),
                .text(StorageDateCodec.encode(collection.createdAt)), .text(StorageDateCodec.encode(collection.updatedAt))
            ]
        )
        return collection
    }

    func add(bookID: UUID, toCollectionID collectionID: UUID) throws {
        try database.execute(
            "INSERT OR IGNORE INTO book_collections_books (collection_id, book_id) VALUES (?, ?)",
            bindings: [.text(collectionID.uuidString), .text(bookID.uuidString)]
        )
    }

    func remove(bookID: UUID, fromCollectionID collectionID: UUID) throws {
        try database.execute(
            "DELETE FROM book_collections_books WHERE collection_id = ? AND book_id = ?",
            bindings: [.text(collectionID.uuidString), .text(bookID.uuidString)]
        )
    }

    func collections(forBookID bookID: UUID) throws -> [BookCollection] {
        try database.query(
            """
            SELECT book_collections.id, book_collections.name, book_collections.description,
                   book_collections.created_at, book_collections.updated_at
            FROM book_collections
            INNER JOIN book_collections_books ON book_collections_books.collection_id = book_collections.id
            WHERE book_collections_books.book_id = ?
            ORDER BY book_collections.name COLLATE NOCASE, book_collections.id
            """,
            bindings: [.text(bookID.uuidString)],
            row: decodeCollection
        )
    }

    @discardableResult
    func createSource(_ source: RecommendationSource) throws -> RecommendationSource {
        try database.execute(
            "INSERT INTO recommendation_sources (id, name, details, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
            bindings: [
                .text(source.id.uuidString), .text(source.name), nullable(source.details),
                .text(StorageDateCodec.encode(source.createdAt)), .text(StorageDateCodec.encode(source.updatedAt))
            ]
        )
        return source
    }

    func attach(sourceID: UUID, toBookID bookID: UUID) throws {
        try database.execute(
            "INSERT OR IGNORE INTO book_sources (book_id, source_id) VALUES (?, ?)",
            bindings: [.text(bookID.uuidString), .text(sourceID.uuidString)]
        )
    }

    func detach(sourceID: UUID, fromBookID bookID: UUID) throws {
        try database.execute(
            "DELETE FROM book_sources WHERE book_id = ? AND source_id = ?",
            bindings: [.text(bookID.uuidString), .text(sourceID.uuidString)]
        )
    }

    func sources(forBookID bookID: UUID) throws -> [RecommendationSource] {
        try database.query(
            """
            SELECT recommendation_sources.id, recommendation_sources.name, recommendation_sources.details,
                   recommendation_sources.created_at, recommendation_sources.updated_at
            FROM recommendation_sources
            INNER JOIN book_sources ON book_sources.source_id = recommendation_sources.id
            WHERE book_sources.book_id = ?
            ORDER BY recommendation_sources.name COLLATE NOCASE, recommendation_sources.id
            """,
            bindings: [.text(bookID.uuidString)],
            row: decodeSource
        )
    }

    @discardableResult
    func addExternalLink(_ link: ExternalLink) throws -> ExternalLink {
        try database.execute(
            """
            INSERT INTO external_links (id, book_id, kind, label, value, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(link.id.uuidString), .text(link.bookID.uuidString), .text(link.kind.rawValue),
                nullable(link.label), .text(link.value), .text(StorageDateCodec.encode(link.createdAt)),
                .text(StorageDateCodec.encode(link.updatedAt))
            ]
        )
        return link
    }

    func externalLinks(forBookID bookID: UUID) throws -> [ExternalLink] {
        try database.query(
            """
            SELECT id, book_id, kind, label, value, created_at, updated_at
            FROM external_links WHERE book_id = ? ORDER BY created_at ASC, id ASC
            """,
            bindings: [.text(bookID.uuidString)],
            row: decodeExternalLink
        )
    }

    @discardableResult
    func addManualRelation(_ relation: ManualBookRelation) throws -> ManualBookRelation {
        try database.execute(
            """
            INSERT INTO manual_book_relations (
                id, source_book_id, target_book_id, relation_kind, note, created_at
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(relation.id.uuidString), .text(relation.sourceBookID.uuidString),
                .text(relation.targetBookID.uuidString), .text(relation.kind.rawValue),
                nullable(relation.note), .text(StorageDateCodec.encode(relation.createdAt))
            ]
        )
        return relation
    }

    func manualRelations(forBookID bookID: UUID) throws -> [ManualBookRelation] {
        try database.query(
            """
            SELECT id, source_book_id, target_book_id, relation_kind, note, created_at
            FROM manual_book_relations
            WHERE source_book_id = ? OR target_book_id = ?
            ORDER BY created_at ASC, id ASC
            """,
            bindings: [.text(bookID.uuidString), .text(bookID.uuidString)],
            row: decodeRelation
        )
    }

    private func list(readingStatus: ReadingStatus?, limit: Int) throws -> [Book] {
        let limit = try checkedLimit(limit)
        if let readingStatus {
            return try database.query(
                "SELECT \(bookColumns) FROM books WHERE reading_status = ? ORDER BY updated_at DESC, id ASC LIMIT ?",
                bindings: [.text(readingStatus.rawValue), .integer(Int64(limit))],
                row: decodeBook
            )
        }
        return try database.query(
            "SELECT \(bookColumns) FROM books ORDER BY updated_at DESC, id ASC LIMIT ?",
            bindings: [.integer(Int64(limit))],
            row: decodeBook
        )
    }

    private func checkedLimit(_ limit: Int) throws -> Int {
        guard (1 ... 500).contains(limit) else {
            throw BookRepositoryError.invalidStoredRecord
        }
        return limit
    }

    private var bookColumns: String {
        "id, title, original_title, author, isbn, publisher, publication_date, kind, reading_status, priority, note, created_at, updated_at, started_at, finished_at"
    }

    private func bookBindings(_ book: Book) -> [SQLiteValue] {
        [
            .text(book.id.uuidString), .text(book.title), nullable(book.originalTitle), .text(book.author),
            nullable(book.isbn), nullable(book.publisher), nullable(book.publicationDate?.storageValue),
            .text(book.kind.rawValue), .text(book.readingStatus.rawValue),
            nullable(book.priority.map { Int64($0.rawValue) }), nullable(book.note),
            .text(StorageDateCodec.encode(book.createdAt)), .text(StorageDateCodec.encode(book.updatedAt)),
            nullable(book.startedAt.map(StorageDateCodec.encode)), nullable(book.finishedAt.map(StorageDateCodec.encode))
        ]
    }

    private func decodeBook(_ row: SQLiteRow) throws -> Book {
        guard let id = UUID(uuidString: row.string(at: 0) ?? ""),
              let title = row.string(at: 1),
              let author = row.string(at: 3),
              let kind = BookKind(rawValue: row.string(at: 7) ?? ""),
              let status = ReadingStatus(rawValue: row.string(at: 8) ?? ""),
              let createdAt = StorageDateCodec.decode(row.string(at: 11)),
              let updatedAt = StorageDateCodec.decode(row.string(at: 12))
        else {
            throw BookRepositoryError.invalidStoredRecord
        }

        let priority = row.string(at: 9).flatMap { Int($0) }.flatMap(BookPriority.init(rawValue:))
        let publicationDate = try row.string(at: 6).map(PublicationDate.init(storageValue:))
        let draft = BookDraft(
            title: title,
            originalTitle: row.string(at: 2),
            author: author,
            isbn: row.string(at: 4),
            publisher: row.string(at: 5),
            publicationDate: publicationDate,
            kind: kind,
            readingStatus: status,
            priority: priority,
            note: row.string(at: 10),
            startedAt: StorageDateCodec.decode(row.string(at: 13)),
            finishedAt: StorageDateCodec.decode(row.string(at: 14))
        )
        return try Book(id: id, draft: draft, createdAt: createdAt, updatedAt: updatedAt)
    }

    private func decodeTag(_ row: SQLiteRow) throws -> Tag {
        guard let id = UUID(uuidString: row.string(at: 0) ?? ""),
              let name = row.string(at: 1),
              let createdAt = StorageDateCodec.decode(row.string(at: 2)),
              let updatedAt = StorageDateCodec.decode(row.string(at: 3))
        else {
            throw BookRepositoryError.invalidStoredRecord
        }
        return try Tag(id: id, name: name, createdAt: createdAt, updatedAt: updatedAt)
    }

    private func decodeCollection(_ row: SQLiteRow) throws -> BookCollection {
        guard let id = UUID(uuidString: row.string(at: 0) ?? ""),
              let name = row.string(at: 1),
              let createdAt = StorageDateCodec.decode(row.string(at: 3)),
              let updatedAt = StorageDateCodec.decode(row.string(at: 4))
        else {
            throw BookRepositoryError.invalidStoredRecord
        }
        return try BookCollection(id: id, name: name, description: row.string(at: 2), createdAt: createdAt, updatedAt: updatedAt)
    }

    private func decodeSource(_ row: SQLiteRow) throws -> RecommendationSource {
        guard let id = UUID(uuidString: row.string(at: 0) ?? ""),
              let name = row.string(at: 1),
              let createdAt = StorageDateCodec.decode(row.string(at: 3)),
              let updatedAt = StorageDateCodec.decode(row.string(at: 4))
        else {
            throw BookRepositoryError.invalidStoredRecord
        }
        return try RecommendationSource(id: id, name: name, details: row.string(at: 2), createdAt: createdAt, updatedAt: updatedAt)
    }

    private func decodeExternalLink(_ row: SQLiteRow) throws -> ExternalLink {
        guard let id = UUID(uuidString: row.string(at: 0) ?? ""),
              let bookID = UUID(uuidString: row.string(at: 1) ?? ""),
              let kind = ExternalLinkKind(rawValue: row.string(at: 2) ?? ""),
              let value = row.string(at: 4),
              let createdAt = StorageDateCodec.decode(row.string(at: 5)),
              let updatedAt = StorageDateCodec.decode(row.string(at: 6))
        else {
            throw BookRepositoryError.invalidStoredRecord
        }
        return try ExternalLink(id: id, bookID: bookID, kind: kind, label: row.string(at: 3), value: value, createdAt: createdAt, updatedAt: updatedAt)
    }

    private func decodeRelation(_ row: SQLiteRow) throws -> ManualBookRelation {
        guard let id = UUID(uuidString: row.string(at: 0) ?? ""),
              let sourceBookID = UUID(uuidString: row.string(at: 1) ?? ""),
              let targetBookID = UUID(uuidString: row.string(at: 2) ?? ""),
              let kind = ManualRelationKind(rawValue: row.string(at: 3) ?? ""),
              let createdAt = StorageDateCodec.decode(row.string(at: 5))
        else {
            throw BookRepositoryError.invalidStoredRecord
        }
        return try ManualBookRelation(id: id, sourceBookID: sourceBookID, targetBookID: targetBookID, kind: kind, note: row.string(at: 4), createdAt: createdAt)
    }
}

private enum StorageDateCodec {
    private static func formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    static func encode(_ value: Date) -> String {
        formatter().string(from: value)
    }

    static func decode(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }
        return formatter().date(from: value)
    }
}

private func nullable(_ value: String?) -> SQLiteValue {
    value.map(SQLiteValue.text) ?? .null
}

private func nullable(_ value: Int64?) -> SQLiteValue {
    value.map(SQLiteValue.integer) ?? .null
}

private func escapeLike(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "%", with: "\\%")
        .replacingOccurrences(of: "_", with: "\\_")
}
