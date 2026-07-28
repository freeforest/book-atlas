import Foundation

enum DatabaseMigrationError: Error, Equatable {
    case unsupportedFutureVersion(Int)
    case invalidTargetVersion(Int)
    case migrationFailed(version: Int)
}

struct DatabaseMigration: @unchecked Sendable {
    let version: Int
    let statements: [String]
    let dataTransform: ((SQLiteDatabase) throws -> Void)?

    init(
        version: Int,
        statements: [String],
        dataTransform: ((SQLiteDatabase) throws -> Void)? = nil
    ) {
        self.version = version
        self.statements = statements
        self.dataTransform = dataTransform
    }
}

enum BookAtlasSchema {
    static let latestVersion = 4

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
        ),
        DatabaseMigration(
            version: 3,
            statements: [
                "CREATE INDEX idx_books_original_title ON books(original_title)",
                "CREATE INDEX idx_books_created_order ON books(created_at, id)",
                "CREATE INDEX idx_books_updated_order ON books(updated_at, id)",
                "CREATE INDEX idx_books_priority_order ON books(priority, id)"
            ]
        ),
        DatabaseMigration(
            version: 4,
            statements: [
                """
                CREATE TABLE book_duplicate_keys (
                    book_id TEXT PRIMARY KEY NOT NULL REFERENCES books(id) ON DELETE CASCADE,
                    valid_isbn TEXT,
                    normalized_title TEXT NOT NULL,
                    normalized_author TEXT NOT NULL,
                    normalized_original_title TEXT
                )
                """,
                "CREATE INDEX idx_duplicate_keys_isbn ON book_duplicate_keys(valid_isbn)",
                """
                CREATE INDEX idx_duplicate_keys_title_author
                ON book_duplicate_keys(normalized_title, normalized_author)
                """,
                """
                CREATE INDEX idx_duplicate_keys_original_title
                ON book_duplicate_keys(normalized_original_title)
                """,
                """
                CREATE TABLE book_duplicate_title_tokens (
                    book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
                    token TEXT NOT NULL,
                    PRIMARY KEY (book_id, token)
                )
                """,
                "CREATE INDEX idx_duplicate_title_tokens_token ON book_duplicate_title_tokens(token, book_id)",
                """
                CREATE TABLE ignored_duplicate_pairs (
                    first_book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
                    second_book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
                    disposition TEXT NOT NULL CHECK (
                        disposition IN ('not_duplicate', 'separate_edition', 'separate_translation')
                    ),
                    created_at TEXT NOT NULL,
                    CHECK (first_book_id < second_book_id),
                    PRIMARY KEY (first_book_id, second_book_id)
                )
                """,
                "CREATE INDEX idx_ignored_duplicate_pairs_second ON ignored_duplicate_pairs(second_book_id)",
                """
                CREATE TRIGGER invalidate_ignored_duplicate_pairs_after_identity_update
                AFTER UPDATE OF title, original_title, author, isbn, publisher, publication_date ON books
                WHEN OLD.title IS NOT NEW.title
                  OR OLD.original_title IS NOT NEW.original_title
                  OR OLD.author IS NOT NEW.author
                  OR OLD.isbn IS NOT NEW.isbn
                  OR OLD.publisher IS NOT NEW.publisher
                  OR OLD.publication_date IS NOT NEW.publication_date
                BEGIN
                    DELETE FROM ignored_duplicate_pairs
                    WHERE first_book_id = NEW.id OR second_book_id = NEW.id;
                END
                """
            ],
            dataTransform: backfillDuplicateKeys
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
                    try migration.dataTransform?(database)
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
    case entityNotFound
    case invalidMerge
    case invalidQuery
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
        try database.transaction {
            try database.execute(
                """
                INSERT INTO books (
                    id, title, original_title, author, isbn, publisher, publication_date,
                    kind, reading_status, priority, note, created_at, updated_at, started_at, finished_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                bindings: bookBindings(book)
            )
            if try database.schemaVersion() >= 4 {
                try replaceDuplicateKeys(for: book, in: database)
            }
        }
    }

    func book(id: UUID) throws -> Book? {
        try database.query(
            "SELECT \(bookColumns) FROM books WHERE id = ?",
            bindings: [.text(id.uuidString)],
            row: decodeBook
        ).first
    }

    func update(_ book: Book) throws {
        try database.transaction {
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
            if try database.schemaVersion() >= 4 {
                try replaceDuplicateKeys(for: book, in: database)
            }
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
        try query(LibraryQuery(searchText: keyword, limit: limit))
    }

    func query(_ query: LibraryQuery) throws -> [Book] {
        let limit = try checkedLimit(query.limit)
        guard query.offset >= 0 else {
            throw BookRepositoryError.invalidQuery
        }

        var predicates: [String] = []
        var bindings: [SQLiteValue] = []

        let searchText = query.normalizedSearchText
        if !searchText.isEmpty {
            let textPattern = "%\(escapeLike(searchText))%"
            let normalizedISBN = ISBNNormalizer.normalize(searchText)
            let isbnPattern = "%\(escapeLike(normalizedISBN))%"
            predicates.append(
                """
                (
                    title LIKE ? ESCAPE '\\' COLLATE NOCASE
                    OR original_title LIKE ? ESCAPE '\\' COLLATE NOCASE
                    OR author LIKE ? ESCAPE '\\' COLLATE NOCASE
                    OR replace(replace(isbn, '-', ''), ' ', '') LIKE ? ESCAPE '\\' COLLATE NOCASE
                )
                """
            )
            bindings.append(contentsOf: [.text(textPattern), .text(textPattern), .text(textPattern), .text(isbnPattern)])
        }

        if !query.readingStatuses.isEmpty {
            let statuses = query.readingStatuses.sorted { $0.rawValue < $1.rawValue }
            predicates.append("reading_status IN (\(placeholders(count: statuses.count)))")
            bindings.append(contentsOf: statuses.map { .text($0.rawValue) })
        }

        appendAssociationPredicates(
            ids: query.tagIDs,
            table: "book_tags",
            bookColumn: "book_id",
            associationColumn: "tag_id",
            predicates: &predicates,
            bindings: &bindings
        )
        appendAssociationPredicates(
            ids: query.collectionIDs,
            table: "book_collections_books",
            bookColumn: "book_id",
            associationColumn: "collection_id",
            predicates: &predicates,
            bindings: &bindings
        )
        appendAssociationPredicates(
            ids: query.sourceIDs,
            table: "book_sources",
            bookColumn: "book_id",
            associationColumn: "source_id",
            predicates: &predicates,
            bindings: &bindings
        )

        let whereClause = predicates.isEmpty ? "" : "WHERE " + predicates.joined(separator: " AND ")
        let direction = query.sortDirection == .ascending ? "ASC" : "DESC"
        let orderClause: String
        switch query.sortField {
        case .createdAt:
            orderClause = "created_at \(direction), id ASC"
        case .updatedAt:
            orderClause = "updated_at \(direction), id ASC"
        case .priority:
            orderClause = "priority IS NULL ASC, priority \(direction), id ASC"
        }

        bindings.append(.integer(Int64(limit)))
        bindings.append(.integer(Int64(query.offset)))
        return try database.query(
            """
            SELECT \(bookColumns) FROM books
            \(whereClause)
            ORDER BY \(orderClause)
            LIMIT ? OFFSET ?
            """,
            bindings: bindings,
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

    func tagSummaries() throws -> [TagSummary] {
        try database.query(
            """
            SELECT tags.id, tags.name, tags.created_at, tags.updated_at, COUNT(book_tags.book_id)
            FROM tags
            LEFT JOIN book_tags ON book_tags.tag_id = tags.id
            GROUP BY tags.id, tags.name, tags.created_at, tags.updated_at
            ORDER BY tags.name COLLATE NOCASE, tags.id
            """
        ) { row in
            TagSummary(tag: try decodeTag(row), bookCount: Int(row.integer(at: 4)))
        }
    }

    func updateTag(_ tag: Tag) throws {
        try database.execute(
            "UPDATE tags SET name = ?, updated_at = ? WHERE id = ?",
            bindings: [
                .text(tag.name),
                .text(StorageDateCodec.encode(tag.updatedAt)),
                .text(tag.id.uuidString)
            ]
        )
        guard try database.changes() == 1 else {
            throw BookRepositoryError.entityNotFound
        }
    }

    func deleteTag(id: UUID) throws {
        try database.execute("DELETE FROM tags WHERE id = ?", bindings: [.text(id.uuidString)])
        guard try database.changes() == 1 else {
            throw BookRepositoryError.entityNotFound
        }
    }

    func mergeTag(sourceID: UUID, into targetID: UUID) throws {
        guard sourceID != targetID else {
            throw BookRepositoryError.invalidMerge
        }

        try database.transaction {
            guard try entityExists(table: "tags", id: sourceID),
                  try entityExists(table: "tags", id: targetID)
            else {
                throw BookRepositoryError.entityNotFound
            }
            try database.execute(
                """
                INSERT OR IGNORE INTO book_tags (book_id, tag_id)
                SELECT book_id, ? FROM book_tags WHERE tag_id = ?
                """,
                bindings: [.text(targetID.uuidString), .text(sourceID.uuidString)]
            )
            try database.execute("DELETE FROM tags WHERE id = ?", bindings: [.text(sourceID.uuidString)])
            guard try database.changes() == 1 else {
                throw BookRepositoryError.entityNotFound
            }
        }
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

    func collectionSummaries() throws -> [CollectionSummary] {
        try database.query(
            """
            SELECT book_collections.id, book_collections.name, book_collections.description,
                   book_collections.created_at, book_collections.updated_at,
                   COUNT(book_collections_books.book_id)
            FROM book_collections
            LEFT JOIN book_collections_books
              ON book_collections_books.collection_id = book_collections.id
            GROUP BY book_collections.id, book_collections.name, book_collections.description,
                     book_collections.created_at, book_collections.updated_at
            ORDER BY book_collections.name COLLATE NOCASE, book_collections.id
            """
        ) { row in
            CollectionSummary(collection: try decodeCollection(row), bookCount: Int(row.integer(at: 5)))
        }
    }

    func updateCollection(_ collection: BookCollection) throws {
        try database.execute(
            """
            UPDATE book_collections
            SET name = ?, description = ?, updated_at = ?
            WHERE id = ?
            """,
            bindings: [
                .text(collection.name),
                nullable(collection.description),
                .text(StorageDateCodec.encode(collection.updatedAt)),
                .text(collection.id.uuidString)
            ]
        )
        guard try database.changes() == 1 else {
            throw BookRepositoryError.entityNotFound
        }
    }

    func deleteCollection(id: UUID) throws {
        try database.execute(
            "DELETE FROM book_collections WHERE id = ?",
            bindings: [.text(id.uuidString)]
        )
        guard try database.changes() == 1 else {
            throw BookRepositoryError.entityNotFound
        }
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

    func sourceSummaries() throws -> [SourceSummary] {
        try database.query(
            """
            SELECT recommendation_sources.id, recommendation_sources.name,
                   recommendation_sources.details, recommendation_sources.created_at,
                   recommendation_sources.updated_at, COUNT(book_sources.book_id)
            FROM recommendation_sources
            LEFT JOIN book_sources ON book_sources.source_id = recommendation_sources.id
            GROUP BY recommendation_sources.id, recommendation_sources.name,
                     recommendation_sources.details, recommendation_sources.created_at,
                     recommendation_sources.updated_at
            ORDER BY recommendation_sources.name COLLATE NOCASE, recommendation_sources.id
            """
        ) { row in
            SourceSummary(source: try decodeSource(row), bookCount: Int(row.integer(at: 5)))
        }
    }

    func updateSource(_ source: RecommendationSource) throws {
        try database.execute(
            """
            UPDATE recommendation_sources
            SET name = ?, details = ?, updated_at = ?
            WHERE id = ?
            """,
            bindings: [
                .text(source.name),
                nullable(source.details),
                .text(StorageDateCodec.encode(source.updatedAt)),
                .text(source.id.uuidString)
            ]
        )
        guard try database.changes() == 1 else {
            throw BookRepositoryError.entityNotFound
        }
    }

    func deleteSource(id: UUID) throws {
        try database.execute(
            "DELETE FROM recommendation_sources WHERE id = ?",
            bindings: [.text(id.uuidString)]
        )
        guard try database.changes() == 1 else {
            throw BookRepositoryError.entityNotFound
        }
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

    func membership(forBookID bookID: UUID) throws -> BookMembership {
        BookMembership(
            tagIDs: Set(try tags(forBookID: bookID).map(\.id)),
            collectionIDs: Set(try collections(forBookID: bookID).map(\.id)),
            sourceIDs: Set(try sources(forBookID: bookID).map(\.id))
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

    func duplicateCandidates(
        for probe: DuplicateProbe,
        includingPossible: Bool = true
    ) throws -> [DuplicateCandidate] {
        let candidateIDs = try duplicateCandidateIDs(for: probe)
        var candidates: [DuplicateCandidate] = []

        for id in candidateIDs where id != probe.id {
            guard let existing = try book(id: id) else {
                continue
            }
            if let incomingID = probe.id,
               try ignoredDuplicatePair(between: incomingID, and: existing.id) != nil
            {
                continue
            }

            let candidate = DuplicateDetectionEngine.evaluate(probe, against: existing)
            guard candidate.confidence != .notDuplicate,
                  includingPossible || candidate.confidence != .possible
            else {
                continue
            }
            candidates.append(candidate)
        }

        return candidates.sorted {
            let lhsRank = duplicateConfidenceRank($0.confidence)
            let rhsRank = duplicateConfidenceRank($1.confidence)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            return $0.existingBook.id.uuidString < $1.existingBook.id.uuidString
        }
    }

    func ignoreDuplicatePair(
        _ firstBookID: UUID,
        _ secondBookID: UUID,
        disposition: DuplicatePairDisposition,
        at date: Date
    ) throws {
        guard firstBookID != secondBookID else {
            throw BookRepositoryError.invalidMerge
        }
        let pair = canonicalPair(firstBookID, secondBookID)
        try database.transaction {
            guard try entityExists(table: "books", id: pair.0),
                  try entityExists(table: "books", id: pair.1)
            else {
                throw BookRepositoryError.bookNotFound
            }
            try database.execute(
                """
                INSERT INTO ignored_duplicate_pairs (
                    first_book_id, second_book_id, disposition, created_at
                ) VALUES (?, ?, ?, ?)
                ON CONFLICT(first_book_id, second_book_id) DO UPDATE SET
                    disposition = excluded.disposition,
                    created_at = excluded.created_at
                """,
                bindings: [
                    .text(pair.0.uuidString),
                    .text(pair.1.uuidString),
                    .text(disposition.rawValue),
                    .text(StorageDateCodec.encode(date))
                ]
            )
        }
    }

    func ignoredDuplicatePair(
        between firstBookID: UUID,
        and secondBookID: UUID
    ) throws -> IgnoredDuplicatePair? {
        guard firstBookID != secondBookID else {
            return nil
        }
        let pair = canonicalPair(firstBookID, secondBookID)
        return try database.query(
            """
            SELECT first_book_id, second_book_id, disposition, created_at
            FROM ignored_duplicate_pairs
            WHERE first_book_id = ? AND second_book_id = ?
            """,
            bindings: [.text(pair.0.uuidString), .text(pair.1.uuidString)],
            row: decodeIgnoredPair
        ).first
    }

    func ignoredDuplicatePairs() throws -> [IgnoredDuplicatePair] {
        try database.query(
            """
            SELECT first_book_id, second_book_id, disposition, created_at
            FROM ignored_duplicate_pairs
            ORDER BY first_book_id, second_book_id
            """,
            row: decodeIgnoredPair
        )
    }

    func mergePreview(targetID: UUID, sourceID: UUID) throws -> BookMergePreview {
        guard targetID != sourceID else {
            throw BookMergeError.sameBook
        }
        guard let target = try book(id: targetID),
              let source = try book(id: sourceID)
        else {
            throw BookMergeError.bookNotFound
        }
        return try mergePreview(target: target, source: source, sourceIsPersisted: true)
    }

    func mergePreview(targetID: UUID, transientSource: Book) throws -> BookMergePreview {
        guard targetID != transientSource.id else {
            throw BookMergeError.sameBook
        }
        guard let target = try book(id: targetID) else {
            throw BookMergeError.bookNotFound
        }
        return try mergePreview(target: target, source: transientSource, sourceIsPersisted: false)
    }

    func mergeBooks(
        targetID: UUID,
        sourceID: UUID,
        selections: BookMergeSelections,
        at mergeDate: Date
    ) throws -> BookMergeResult {
        guard targetID != sourceID else {
            throw BookMergeError.sameBook
        }

        return try database.transaction {
            guard let target = try book(id: targetID),
                  let source = try book(id: sourceID)
            else {
                throw BookMergeError.bookNotFound
            }

            let preview = try mergePreview(target: target, source: source, sourceIsPersisted: true)
            let relationMoves = try plannedRelationMoves(
                sourceID: sourceID,
                targetID: targetID
            )
            let merged = try BookMergePolicy.mergedBook(
                preview: preview,
                selections: selections,
                at: mergeDate
            )

            try update(merged)
            try copyMemberships(from: sourceID, to: targetID)
            try moveExternalLinks(from: sourceID, to: targetID)
            try applyRelationMoves(relationMoves)
            try migrateIgnoredPairs(from: sourceID, to: targetID)

            try database.execute(
                "DELETE FROM books WHERE id = ?",
                bindings: [.text(sourceID.uuidString)]
            )
            guard try database.changes() == 1 else {
                throw BookMergeError.bookNotFound
            }
            return BookMergeResult(retainedBook: merged, removedBookID: sourceID)
        }
    }

    private func duplicateCandidateIDs(for probe: DuplicateProbe) throws -> Set<UUID> {
        var ids = Set<UUID>()

        func appendIDs(_ sql: String, bindings: [SQLiteValue]) throws {
            let values = try database.query(sql, bindings: bindings) { row in
                row.string(at: 0).flatMap(UUID.init(uuidString:))
            }
            ids.formUnion(values.compactMap { $0 })
        }

        if let validISBN = DuplicateISBNNormalizer.validate(probe.isbn).validIdentifier {
            try appendIDs(
                """
                SELECT book_id FROM book_duplicate_keys
                WHERE valid_isbn = ?
                LIMIT 250
                """,
                bindings: [.text(validISBN)]
            )
        }

        let titleKey = DuplicateTextNormalizer.titleKey(probe.title)
        let authorKey = DuplicateTextNormalizer.authorKey(probe.author)
        try appendIDs(
            """
            SELECT book_id FROM book_duplicate_keys
            WHERE normalized_title = ? AND normalized_author = ?
            LIMIT 250
            """,
            bindings: [.text(titleKey), .text(authorKey)]
        )

        if let originalTitle = probe.originalTitle {
            let originalKey = DuplicateTextNormalizer.titleKey(originalTitle)
            if !originalKey.isEmpty {
                try appendIDs(
                    """
                    SELECT book_id FROM book_duplicate_keys
                    WHERE normalized_original_title = ?
                    LIMIT 250
                    """,
                    bindings: [.text(originalKey)]
                )
            }
        }

        let tokens = DuplicateTextNormalizer.titleTokens(probe.title)
            .sorted()
            .prefix(32)
        if !tokens.isEmpty {
            try appendIDs(
                """
                SELECT DISTINCT book_id FROM book_duplicate_title_tokens
                WHERE token IN (\(placeholders(count: tokens.count)))
                LIMIT 250
                """,
                bindings: tokens.map(SQLiteValue.text)
            )
        }
        return ids
    }

    private func mergePreview(
        target: Book,
        source: Book,
        sourceIsPersisted: Bool
    ) throws -> BookMergePreview {
        let targetRelations = try manualRelations(forBookID: target.id)
        let sourceRelations = sourceIsPersisted ? try manualRelations(forBookID: source.id) : []
        let relationsByID = Dictionary(
            (targetRelations + sourceRelations).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let associations = BookMergeAssociationSummary(
            targetTags: try tags(forBookID: target.id),
            sourceTags: sourceIsPersisted ? try tags(forBookID: source.id) : [],
            targetCollections: try collections(forBookID: target.id),
            sourceCollections: sourceIsPersisted ? try collections(forBookID: source.id) : [],
            targetSources: try sources(forBookID: target.id),
            sourceSources: sourceIsPersisted ? try sources(forBookID: source.id) : [],
            targetLinks: try externalLinks(forBookID: target.id),
            sourceLinks: sourceIsPersisted ? try externalLinks(forBookID: source.id) : [],
            manualRelations: relationsByID.values.sorted {
                if $0.createdAt != $1.createdAt {
                    return $0.createdAt < $1.createdAt
                }
                return $0.id.uuidString < $1.id.uuidString
            }
        )
        return BookMergePolicy.preview(
            target: target,
            source: source,
            associations: associations
        )
    }

    private func copyMemberships(from sourceID: UUID, to targetID: UUID) throws {
        try database.execute(
            """
            INSERT OR IGNORE INTO book_tags (book_id, tag_id)
            SELECT ?, tag_id FROM book_tags WHERE book_id = ?
            """,
            bindings: [.text(targetID.uuidString), .text(sourceID.uuidString)]
        )
        try database.execute(
            """
            INSERT OR IGNORE INTO book_collections_books (collection_id, book_id)
            SELECT collection_id, ? FROM book_collections_books WHERE book_id = ?
            """,
            bindings: [.text(targetID.uuidString), .text(sourceID.uuidString)]
        )
        try database.execute(
            """
            INSERT OR IGNORE INTO book_sources (book_id, source_id)
            SELECT ?, source_id FROM book_sources WHERE book_id = ?
            """,
            bindings: [.text(targetID.uuidString), .text(sourceID.uuidString)]
        )
    }

    private func moveExternalLinks(from sourceID: UUID, to targetID: UUID) throws {
        for link in try externalLinks(forBookID: sourceID) {
            let duplicate = try database.query(
                """
                SELECT id, book_id, kind, label, value, created_at, updated_at
                FROM external_links
                WHERE book_id = ? AND kind = ? AND value = ?
                """,
                bindings: [
                    .text(targetID.uuidString),
                    .text(link.kind.rawValue),
                    .text(link.value)
                ],
                row: decodeExternalLink
            ).first

            if let duplicate {
                if duplicate.label == nil, let sourceLabel = link.label {
                    try database.execute(
                        "UPDATE external_links SET label = ? WHERE id = ?",
                        bindings: [.text(sourceLabel), .text(duplicate.id.uuidString)]
                    )
                }
            } else {
                try database.execute(
                    "UPDATE external_links SET book_id = ? WHERE id = ?",
                    bindings: [.text(targetID.uuidString), .text(link.id.uuidString)]
                )
                guard try database.changes() == 1 else {
                    throw BookMergeError.mergeFailed
                }
            }
        }
    }

    private func plannedRelationMoves(
        sourceID: UUID,
        targetID: UUID
    ) throws -> [PlannedRelationMove] {
        try manualRelations(forBookID: sourceID).map { relation in
            let newSourceID = relation.sourceBookID == sourceID ? targetID : relation.sourceBookID
            let newTargetID = relation.targetBookID == sourceID ? targetID : relation.targetBookID
            guard newSourceID != newTargetID else {
                throw BookMergeError.selfRelationConflict
            }

            let duplicate = try existingRelation(
                sourceID: newSourceID,
                targetID: newTargetID,
                kind: relation.kind,
                excluding: relation.id
            )
            if let duplicate,
               let existingNote = duplicate.note,
               let sourceNote = relation.note,
               existingNote != sourceNote
            {
                throw BookMergeError.relationNoteConflict
            }
            return PlannedRelationMove(
                relation: relation,
                newSourceID: newSourceID,
                newTargetID: newTargetID,
                duplicate: duplicate
            )
        }
    }

    private func applyRelationMoves(_ moves: [PlannedRelationMove]) throws {
        for move in moves {
            if let duplicate = move.duplicate {
                if duplicate.note == nil, let sourceNote = move.relation.note {
                    try database.execute(
                        "UPDATE manual_book_relations SET note = ? WHERE id = ?",
                        bindings: [.text(sourceNote), .text(duplicate.id.uuidString)]
                    )
                }
                try database.execute(
                    "DELETE FROM manual_book_relations WHERE id = ?",
                    bindings: [.text(move.relation.id.uuidString)]
                )
            } else {
                try database.execute(
                    """
                    UPDATE manual_book_relations
                    SET source_book_id = ?, target_book_id = ?
                    WHERE id = ?
                    """,
                    bindings: [
                        .text(move.newSourceID.uuidString),
                        .text(move.newTargetID.uuidString),
                        .text(move.relation.id.uuidString)
                    ]
                )
                guard try database.changes() == 1 else {
                    throw BookMergeError.mergeFailed
                }
            }
        }
    }

    private func existingRelation(
        sourceID: UUID,
        targetID: UUID,
        kind: ManualRelationKind,
        excluding relationID: UUID
    ) throws -> ManualBookRelation? {
        try database.query(
            """
            SELECT id, source_book_id, target_book_id, relation_kind, note, created_at
            FROM manual_book_relations
            WHERE source_book_id = ? AND target_book_id = ?
              AND relation_kind = ? AND id <> ?
            LIMIT 1
            """,
            bindings: [
                .text(sourceID.uuidString),
                .text(targetID.uuidString),
                .text(kind.rawValue),
                .text(relationID.uuidString)
            ],
            row: decodeRelation
        ).first
    }

    private func migrateIgnoredPairs(from sourceID: UUID, to targetID: UUID) throws {
        let pairs = try database.query(
            """
            SELECT first_book_id, second_book_id, disposition, created_at
            FROM ignored_duplicate_pairs
            WHERE first_book_id = ? OR second_book_id = ?
            """,
            bindings: [.text(sourceID.uuidString), .text(sourceID.uuidString)],
            row: decodeIgnoredPair
        )

        for pair in pairs {
            let otherID = pair.firstBookID == sourceID ? pair.secondBookID : pair.firstBookID
            guard otherID != targetID else {
                continue
            }
            let migrated = canonicalPair(targetID, otherID)
            try database.execute(
                """
                INSERT OR IGNORE INTO ignored_duplicate_pairs (
                    first_book_id, second_book_id, disposition, created_at
                ) VALUES (?, ?, ?, ?)
                """,
                bindings: [
                    .text(migrated.0.uuidString),
                    .text(migrated.1.uuidString),
                    .text(pair.disposition.rawValue),
                    .text(StorageDateCodec.encode(pair.createdAt))
                ]
            )
        }
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

    private func appendAssociationPredicates(
        ids: Set<UUID>,
        table: String,
        bookColumn: String,
        associationColumn: String,
        predicates: inout [String],
        bindings: inout [SQLiteValue]
    ) {
        for id in ids.sorted(by: { $0.uuidString < $1.uuidString }) {
            predicates.append(
                """
                EXISTS (
                    SELECT 1 FROM \(table) association
                    WHERE association.\(bookColumn) = books.id
                      AND association.\(associationColumn) = ?
                )
                """
            )
            bindings.append(.text(id.uuidString))
        }
    }

    private func entityExists(table: String, id: UUID) throws -> Bool {
        try database.scalarInt(
            "SELECT COUNT(*) FROM \(table) WHERE id = ?",
            bindings: [.text(id.uuidString)]
        ) == 1
    }

    private func checkedLimit(_ limit: Int) throws -> Int {
        guard (1 ... 1_000).contains(limit) else {
            throw BookRepositoryError.invalidQuery
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

    private func decodeIgnoredPair(_ row: SQLiteRow) throws -> IgnoredDuplicatePair {
        guard let firstBookID = UUID(uuidString: row.string(at: 0) ?? ""),
              let secondBookID = UUID(uuidString: row.string(at: 1) ?? ""),
              let disposition = DuplicatePairDisposition(rawValue: row.string(at: 2) ?? ""),
              let createdAt = StorageDateCodec.decode(row.string(at: 3))
        else {
            throw BookRepositoryError.invalidStoredRecord
        }
        return IgnoredDuplicatePair(
            firstBookID: firstBookID,
            secondBookID: secondBookID,
            disposition: disposition,
            createdAt: createdAt
        )
    }
}

private struct PlannedRelationMove {
    let relation: ManualBookRelation
    let newSourceID: UUID
    let newTargetID: UUID
    let duplicate: ManualBookRelation?
}

private struct DuplicateKeySource {
    let id: UUID
    let title: String
    let originalTitle: String?
    let author: String
    let isbn: String?
}

private func backfillDuplicateKeys(_ database: SQLiteDatabase) throws {
    let sources = try database.query(
        "SELECT id, title, original_title, author, isbn FROM books ORDER BY id"
    ) { row in
        guard let id = UUID(uuidString: row.string(at: 0) ?? ""),
              let title = row.string(at: 1),
              let author = row.string(at: 3)
        else {
            throw BookRepositoryError.invalidStoredRecord
        }
        return DuplicateKeySource(
            id: id,
            title: title,
            originalTitle: row.string(at: 2),
            author: author,
            isbn: row.string(at: 4)
        )
    }

    for source in sources {
        try replaceDuplicateKeys(for: source, in: database)
    }
}

private func replaceDuplicateKeys(for book: Book, in database: SQLiteDatabase) throws {
    try replaceDuplicateKeys(
        for: DuplicateKeySource(
            id: book.id,
            title: book.title,
            originalTitle: book.originalTitle,
            author: book.author,
            isbn: book.isbn
        ),
        in: database
    )
}

private func replaceDuplicateKeys(
    for source: DuplicateKeySource,
    in database: SQLiteDatabase
) throws {
    let originalTitleKey = source.originalTitle.map(DuplicateTextNormalizer.titleKey)
        .flatMap { $0.isEmpty ? nil : $0 }
    try database.execute(
        """
        INSERT INTO book_duplicate_keys (
            book_id, valid_isbn, normalized_title, normalized_author, normalized_original_title
        ) VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(book_id) DO UPDATE SET
            valid_isbn = excluded.valid_isbn,
            normalized_title = excluded.normalized_title,
            normalized_author = excluded.normalized_author,
            normalized_original_title = excluded.normalized_original_title
        """,
        bindings: [
            .text(source.id.uuidString),
            nullable(DuplicateISBNNormalizer.validate(source.isbn).validIdentifier),
            .text(DuplicateTextNormalizer.titleKey(source.title)),
            .text(DuplicateTextNormalizer.authorKey(source.author)),
            nullable(originalTitleKey)
        ]
    )
    try database.execute(
        "DELETE FROM book_duplicate_title_tokens WHERE book_id = ?",
        bindings: [.text(source.id.uuidString)]
    )
    for token in DuplicateTextNormalizer.titleTokens(source.title).sorted() {
        try database.execute(
            "INSERT INTO book_duplicate_title_tokens (book_id, token) VALUES (?, ?)",
            bindings: [.text(source.id.uuidString), .text(token)]
        )
    }
}

private func canonicalPair(_ first: UUID, _ second: UUID) -> (UUID, UUID) {
    first.uuidString < second.uuidString ? (first, second) : (second, first)
}

private func duplicateConfidenceRank(_ confidence: DuplicateConfidence) -> Int {
    switch confidence {
    case .exact: 0
    case .strong: 1
    case .possible: 2
    case .notDuplicate: 3
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

private func placeholders(count: Int) -> String {
    Array(repeating: "?", count: count).joined(separator: ", ")
}
