import Foundation

struct ImportCancellation: Sendable {
    let isCancelled: @Sendable () -> Bool

    static let never = ImportCancellation(isCancelled: { false })
}

final class LibraryImportCoordinator {
    private let parser: StreamingCSVParser
    private let limits: CSVParserLimits

    init(limits: CSVParserLimits = CSVParserLimits()) {
        self.limits = limits
        parser = StreamingCSVParser(limits: limits)
    }

    func parse(url: URL) throws -> CSVDocument {
        try parser.parse(url: url)
    }

    func preview(
        document: CSVDocument,
        mapping: CSVFieldMapping,
        repository: BookRepository
    ) throws -> ImportPreview {
        for required in ImportField.allCases where required.isRequired {
            guard mapping.columns[required] != nil else {
                throw PortabilityError.missingRequiredMapping(required)
            }
        }
        guard mapping.columns[.formatVersion] != nil else {
            throw PortabilityError.missingRequiredMapping(.formatVersion)
        }

        let headerIndices = Dictionary(
            document.headers.enumerated().map { ($0.element, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
        let existingTags = Set(try repository.tagSummaries().map {
            try CatalogNameNormalizer.comparisonKey($0.tag.name)
        })
        let existingCollections = Set(try repository.collectionSummaries().map {
            try CatalogNameNormalizer.comparisonKey($0.collection.name)
        })
        let existingSources = Set(try repository.sourceSummaries().map {
            try CatalogNameNormalizer.comparisonKey($0.source.name)
        })

        var rows: [PreparedImportRow] = []
        var allIssues: [ImportIssue] = []
        var newTags = Set<String>()
        var newCollections = Set<String>()
        var newSources = Set<String>()

        for record in document.records {
            let parsed = try prepare(
                record,
                mapping: mapping,
                headerIndices: headerIndices,
                repository: repository
            )
            rows.append(parsed)
            allIssues.append(contentsOf: parsed.issues)
            if !parsed.issues.contains(where: { $0.severity == .error }),
               parsed.duplicateCandidates.isEmpty
            {
                for name in parsed.tags {
                    let key = try CatalogNameNormalizer.comparisonKey(name)
                    if !existingTags.contains(key) { newTags.insert(key) }
                }
                for name in parsed.collections {
                    let key = try CatalogNameNormalizer.comparisonKey(name)
                    if !existingCollections.contains(key) { newCollections.insert(key) }
                }
                for name in parsed.sources {
                    let key = try CatalogNameNormalizer.comparisonKey(name)
                    if !existingSources.contains(key) { newSources.insert(key) }
                }
            }
        }

        return ImportPreview(
            totalRows: rows.count,
            importableRows: rows.filter {
                !$0.issues.contains(where: { $0.severity == .error })
                    && $0.duplicateCandidates.isEmpty
            }.count,
            warningRows: rows.filter { $0.issues.contains(where: { $0.severity == .warning }) }.count,
            errorRows: rows.filter { $0.issues.contains(where: { $0.severity == .error }) }.count,
            potentialDuplicateRows: rows.filter { !$0.duplicateCandidates.isEmpty }.count,
            newTagCount: newTags.count,
            newCollectionCount: newCollections.count,
            newSourceCount: newSources.count,
            sampleRows: Array(rows.prefix(limits.previewRows)),
            mapping: mapping,
            availableHeaders: document.headers,
            wasTruncated: document.wasTruncated || rows.count > limits.previewRows,
            preparedRows: rows,
            issues: allIssues
        )
    }

    func execute(
        preview: ImportPreview,
        repository: BookRepository,
        duplicatePolicy: ImportDuplicatePolicy = .skipAndReview,
        at date: Date = Date(),
        cancellation: ImportCancellation = .never,
        afterRow: ((Int) throws -> Void)? = nil
    ) throws -> ImportResult {
        guard duplicatePolicy == .skipAndReview else { throw PortabilityError.restoreFailed }
        var imported = 0
        var skipped = 0
        var warningCount = 0
        var failed = 0
        var duplicates = 0

        return try repository.transaction {
            var tags = try nameMap(try repository.tagSummaries().map(\.tag))
            var collections = try nameMap(try repository.collectionSummaries().map(\.collection))
            var sources = try nameMap(try repository.sourceSummaries().map(\.source))

            for row in preview.preparedRows {
                if cancellation.isCancelled() { throw PortabilityError.cancelled }
                if row.issues.contains(where: { $0.severity == .error }) {
                    skipped += 1
                    failed += 1
                    continue
                }
                warningCount += row.issues.filter { $0.severity == .warning }.count

                let proposedID = UUID()
                let duplicateSearch = try repository.duplicateCandidateSearch(
                    for: DuplicateProbe(id: proposedID, draft: row.draft),
                    includingPossible: false
                )
                if !duplicateSearch.candidates.isEmpty {
                    skipped += 1
                    duplicates += 1
                    continue
                }

                let book = try repository.create(row.draft, id: proposedID, at: date)
                for name in row.tags {
                    let key = try CatalogNameNormalizer.comparisonKey(name)
                    let tag: Tag
                    if let existing = tags[key] {
                        tag = existing
                    } else {
                        tag = try repository.createTag(Tag(name: name, createdAt: date))
                        tags[key] = tag
                    }
                    try repository.attach(tagID: tag.id, toBookID: book.id)
                }
                for name in row.collections {
                    let key = try CatalogNameNormalizer.comparisonKey(name)
                    let collection: BookCollection
                    if let existing = collections[key] {
                        collection = existing
                    } else {
                        collection = try repository.createCollection(
                            BookCollection(name: name, createdAt: date)
                        )
                        collections[key] = collection
                    }
                    try repository.add(bookID: book.id, toCollectionID: collection.id)
                }
                for name in row.sources {
                    let key = try CatalogNameNormalizer.comparisonKey(name)
                    let source: RecommendationSource
                    if let existing = sources[key] {
                        source = existing
                    } else {
                        source = try repository.createSource(
                            RecommendationSource(name: name, createdAt: date)
                        )
                        sources[key] = source
                    }
                    try repository.attach(sourceID: source.id, toBookID: book.id)
                }
                imported += 1
                try afterRow?(row.lineNumber)
            }
            return ImportResult(
                imported: imported,
                skipped: skipped,
                warnings: warningCount,
                failed: failed,
                duplicateRows: duplicates
            )
        }
    }

    private func prepare(
        _ record: CSVRecord,
        mapping: CSVFieldMapping,
        headerIndices: [String: Int],
        repository: BookRepository
    ) throws -> PreparedImportRow {
        func value(_ field: ImportField) -> String {
            guard let header = mapping.columns[field],
                  let index = headerIndices[header],
                  index < record.values.count
            else { return "" }
            return record.values[index].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var issues: [ImportIssue] = []
        func addError(_ field: ImportField, _ code: String, _ description: String) {
            issues.append(ImportIssue(
                lineNumber: record.lineNumber,
                field: field.rawValue,
                code: code,
                description: description,
                severity: .error,
                retryable: true
            ))
        }

        if value(.formatVersion) != PortabilityFormat.csvVersion {
            addError(.formatVersion, "unsupported_format", "格式版本不受支持。")
        }
        let title = value(.title)
        let author = value(.author)
        if title.isEmpty { addError(.title, "required", "必填字段缺失。") }
        if author.isEmpty { addError(.author, "required", "必填字段缺失。") }

        let publicationDate: PublicationDate?
        if value(.publicationDate).isEmpty {
            publicationDate = nil
        } else {
            do {
                publicationDate = try PublicationDate(storageValue: value(.publicationDate))
            } catch {
                publicationDate = nil
                addError(.publicationDate, "invalid_date", "日期格式无效。")
            }
        }
        let kind: BookKind
        if value(.kind).isEmpty {
            kind = .book
        } else if let parsed = BookKind(rawValue: value(.kind)) {
            kind = parsed
        } else {
            kind = .book
            addError(.kind, "invalid_kind", "书籍类型无效。")
        }
        let status: ReadingStatus
        if value(.readingStatus).isEmpty {
            status = .wishToRead
        } else if let parsed = ReadingStatus(rawValue: value(.readingStatus)) {
            status = parsed
        } else {
            status = .wishToRead
            addError(.readingStatus, "invalid_status", "阅读状态无效。")
        }
        let priority: BookPriority?
        if value(.priority).isEmpty {
            priority = nil
        } else if let raw = Int(value(.priority)), let parsed = BookPriority(rawValue: raw) {
            priority = parsed
        } else {
            priority = nil
            addError(.priority, "invalid_priority", "优先级无效。")
        }
        let started = PortabilityDateCodec.decode(value(.startedAt))
        if !value(.startedAt).isEmpty, started == nil {
            addError(.startedAt, "invalid_timestamp", "时间格式无效。")
        }
        let finished = PortabilityDateCodec.decode(value(.finishedAt))
        if !value(.finishedAt).isEmpty, finished == nil {
            addError(.finishedAt, "invalid_timestamp", "时间格式无效。")
        }

        let draft = BookDraft(
            title: title.isEmpty ? "无效占位" : title,
            originalTitle: optional(value(.originalTitle)),
            author: author.isEmpty ? "无效占位" : author,
            isbn: optional(value(.isbn)).map(ISBNNormalizer.normalize),
            publisher: optional(value(.publisher)),
            publicationDate: publicationDate,
            kind: kind,
            readingStatus: status,
            priority: priority,
            note: optional(value(.note)),
            startedAt: started,
            finishedAt: finished
        )
        let duplicates: [DuplicateCandidate]
        if issues.contains(where: { $0.severity == .error }) {
            duplicates = []
        } else {
            duplicates = try repository.duplicateCandidates(
                for: DuplicateProbe(id: UUID(), draft: draft),
                includingPossible: false
            )
        }
        if !duplicates.isEmpty {
            issues.append(ImportIssue(
                lineNumber: record.lineNumber,
                field: "record",
                code: "potential_duplicate",
                description: "发现潜在重复；该行不会自动覆盖或合并。",
                severity: .warning,
                retryable: true
            ))
        }
        return PreparedImportRow(
            lineNumber: record.lineNumber,
            draft: draft,
            tags: uniqueNames(DelimitedValueCodec.decode(value(.tags))),
            collections: uniqueNames(DelimitedValueCodec.decode(value(.collections))),
            sources: uniqueNames(DelimitedValueCodec.decode(value(.sources))),
            issues: issues,
            duplicateCandidates: duplicates
        )
    }
}

final class LibraryExportCoordinator {
    private let fileManager: FileManager
    private let now: () -> Date

    init(fileManager: FileManager = .default, now: @escaping () -> Date = Date.init) {
        self.fileManager = fileManager
        self.now = now
    }

    func exportCSV(repository: BookRepository, to destination: URL) throws {
        try write(
            LibraryCSVExporter.data(records: repository.exportRecords()),
            to: destination
        )
    }

    func exportMarkdown(repository: BookRepository, to destination: URL) throws {
        try write(
            LibraryMarkdownExporter.data(
                records: repository.exportRecords(),
                exportedAt: now()
            ),
            to: destination
        )
    }

    func exportErrorReport(_ issues: [ImportIssue], to destination: URL) throws {
        var output = CSVEncoder.row(
            ["row", "field", "code", "description", "retryable"],
            formulaSafe: false
        )
        for issue in issues {
            output += CSVEncoder.row([
                String(issue.lineNumber),
                issue.field,
                issue.code,
                issue.description,
                issue.retryable ? "true" : "false"
            ])
        }
        try write(Data(output.utf8), to: destination)
    }

    private func write(_ data: Data, to destination: URL) throws {
        guard destination.isFileURL else { throw PortabilityError.invalidDestination }
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw PortabilityError.destinationExists
        }
        let directory = destination.deletingLastPathComponent()
        let temporary = directory.appendingPathComponent(
            ".bookatlas-\(UUID().uuidString).tmp",
            isDirectory: false
        )
        do {
            try data.write(to: temporary, options: [.atomic])
            try fileManager.moveItem(at: temporary, to: destination)
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }
}

enum RestoreInjectionPoint: Equatable, Sendable {
    case afterRecoveryCopy
    case afterConnectionClose
    case afterReplacement
    case beforeReconnect
    case beforeRollbackReconnect
}

final class LibraryBackupCoordinator {
    static let backupExtension = "bookatlasbackup"
    static let manifestTable = "_bookatlas_backup_manifest"

    private let fileManager: FileManager
    private let applicationVersion: String
    private let now: () -> Date
    private let injectFailure: (RestoreInjectionPoint) throws -> Void

    init(
        fileManager: FileManager = .default,
        applicationVersion: String = "1.0",
        now: @escaping () -> Date = Date.init,
        injectFailure: @escaping (RestoreInjectionPoint) throws -> Void = { _ in }
    ) {
        self.fileManager = fileManager
        self.applicationVersion = applicationVersion
        self.now = now
        self.injectFailure = injectFailure
    }

    func backup(repository: BookRepository, to destination: URL) throws -> BackupResult {
        guard destination.isFileURL,
              destination.pathExtension.lowercased() == Self.backupExtension
        else { throw PortabilityError.invalidDestination }
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw PortabilityError.destinationExists
        }

        let temporaryBackup = destination.deletingLastPathComponent().appendingPathComponent(
            ".bookatlas-backup-\(UUID().uuidString).tmp",
            isDirectory: false
        )
        defer {
            try? fileManager.removeItem(at: temporaryBackup)
            try? fileManager.removeItem(atPath: temporaryBackup.path + "-wal")
            try? fileManager.removeItem(atPath: temporaryBackup.path + "-shm")
        }

        do {
            try repository.onlineBackup(to: temporaryBackup)
            let database = try SQLiteDatabase(path: temporaryBackup.path)
            _ = try database.query("PRAGMA journal_mode = DELETE") { row in
                row.string(at: 0)
            }
            let createdAt = now()
            try database.execute(
                """
                CREATE TABLE \(Self.manifestTable) (
                    format_version INTEGER NOT NULL,
                    schema_version INTEGER NOT NULL,
                    application_version TEXT NOT NULL,
                    created_at TEXT NOT NULL
                )
                """
            )
            try database.execute(
                "INSERT INTO \(Self.manifestTable) VALUES (?, ?, ?, ?)",
                bindings: [
                    .integer(Int64(PortabilityFormat.backupVersion)),
                    .integer(Int64(repository.schemaVersion)),
                    .text(applicationVersion),
                    .text(StorageDateCodec.encode(createdAt))
                ]
            )
            guard try database.integrityCheck() else { throw PortabilityError.corruptDatabase }
            try database.close()
            try fileManager.moveItem(at: temporaryBackup, to: destination)
            return BackupResult(
                destination: destination,
                preview: BackupPreview(
                    formatVersion: PortabilityFormat.backupVersion,
                    schemaVersion: repository.schemaVersion,
                    applicationVersion: applicationVersion,
                    createdAt: createdAt,
                    bookCount: try repository.allBooks().count
                )
            )
        } catch let error as PortabilityError {
            throw error
        } catch {
            throw PortabilityError.backupFailed
        }
    }

    func inspect(_ backupURL: URL) throws -> BackupPreview {
        try validateFile(backupURL)
        let database: SQLiteDatabase
        do {
            database = try SQLiteDatabase(path: backupURL.path, readOnly: true)
        } catch {
            throw PortabilityError.corruptDatabase
        }
        defer { try? database.close() }
        guard try database.integrityCheck() else { throw PortabilityError.corruptDatabase }
        let rows: [(Int, Int, String?, String?)]
        do {
            rows = try database.query(
                """
                SELECT format_version, schema_version, application_version, created_at
                FROM \(Self.manifestTable)
                """
            ) { row in
                (
                    Int(row.integer(at: 0)),
                    Int(row.integer(at: 1)),
                    row.string(at: 2),
                    row.string(at: 3)
                )
            }
        } catch {
            throw PortabilityError.invalidManifest
        }
        guard rows.count == 1,
              let appVersion = rows[0].2,
              let createdAt = StorageDateCodec.decode(rows[0].3)
        else { throw PortabilityError.invalidManifest }
        guard rows[0].0 == PortabilityFormat.backupVersion else {
            throw PortabilityError.unsupportedBackupFormat(rows[0].0)
        }
        guard (1 ... BookAtlasSchema.latestVersion).contains(rows[0].1) else {
            throw PortabilityError.unsupportedSchemaVersion(rows[0].1)
        }
        guard try database.schemaVersion() == rows[0].1 else {
            throw PortabilityError.invalidManifest
        }
        let count = Int(try database.scalarInt("SELECT COUNT(*) FROM books") ?? 0)
        return BackupPreview(
            formatVersion: rows[0].0,
            schemaVersion: rows[0].1,
            applicationVersion: appVersion,
            createdAt: createdAt,
            bookCount: count
        )
    }

    func restore(
        backupURL: URL,
        databaseURL: URL,
        repository: inout BookRepository,
        recoveryDirectory: URL
    ) throws -> BackupPreview {
        let preview = try inspect(backupURL)
        try fileManager.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
        let recoveryURL = recoveryDirectory.appendingPathComponent(
            "BookAtlas-before-restore-\(UUID().uuidString).\(Self.backupExtension)"
        )
        _ = try backup(repository: repository, to: recoveryURL)
        _ = try inspect(recoveryURL)
        try injectFailure(.afterRecoveryCopy)

        let workingDirectory = databaseURL.deletingLastPathComponent()
            .appendingPathComponent(".BookAtlas-Restore-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workingDirectory) }
        let stagedURL = workingDirectory.appendingPathComponent("restored.sqlite")
        let source = try SQLiteDatabase(path: backupURL.path, readOnly: true)
        try source.onlineBackup(to: stagedURL.path)
        try source.close()
        let staged = try SQLiteDatabase(path: stagedURL.path)
        try staged.execute("DROP TABLE \(Self.manifestTable)")
        _ = try DatabaseMigrator().migrate(staged)
        guard try staged.integrityCheck() else { throw PortabilityError.corruptDatabase }
        try staged.close()

        let rollbackURL = workingDirectory.appendingPathComponent("original.sqlite")
        var originalMoved = false
        var replacementInstalled = false
        do {
            try repository.checkpointWAL()
            try repository.close()
            try injectFailure(.afterConnectionClose)
            if fileManager.fileExists(atPath: databaseURL.path) {
                try fileManager.moveItem(at: databaseURL, to: rollbackURL)
                originalMoved = true
            }
            try fileManager.moveItem(at: stagedURL, to: databaseURL)
            replacementInstalled = true
            try injectFailure(.afterReplacement)
            try injectFailure(.beforeReconnect)
            repository = try BookRepository(databaseURL: databaseURL)
            guard try repository.integrityCheck() else { throw PortabilityError.corruptDatabase }
            if originalMoved { try? fileManager.removeItem(at: rollbackURL) }
            return preview
        } catch {
            try? repository.close()
            if replacementInstalled, fileManager.fileExists(atPath: databaseURL.path) {
                try? fileManager.removeItem(at: databaseURL)
            }
            if originalMoved, fileManager.fileExists(atPath: rollbackURL.path) {
                try? fileManager.moveItem(at: rollbackURL, to: databaseURL)
            }
            do {
                try injectFailure(.beforeRollbackReconnect)
                repository = try BookRepository(databaseURL: databaseURL)
            } catch {
                throw PortabilityError.reconnectFailed
            }
            if let portabilityError = error as? PortabilityError {
                throw portabilityError
            }
            throw PortabilityError.restoreFailed
        }
    }

    private func validateFile(_ url: URL) throws {
        guard url.isFileURL,
              url.pathExtension.lowercased() == Self.backupExtension
        else { throw PortabilityError.unsafeFile }
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey
        ])
        guard values.isSymbolicLink != true, values.isRegularFile == true else {
            throw PortabilityError.unsafeFile
        }
        guard (values.fileSize ?? 0) >= 16 else { throw PortabilityError.corruptDatabase }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let magic = try handle.read(upToCount: 16) ?? Data()
        guard magic == Data("SQLite format 3\u{0}".utf8) else {
            throw PortabilityError.corruptDatabase
        }
    }
}

private func optional(_ value: String) -> String? {
    value.isEmpty ? nil : value
}

private func uniqueNames(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values.filter {
        let key = $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return seen.insert(key).inserted
    }
}

private func nameMap<T>(_ values: [T]) throws -> [String: T] {
    var result: [String: T] = [:]
    for value in values {
        let name: String
        if let tag = value as? Tag {
            name = tag.name
        } else if let collection = value as? BookCollection {
            name = collection.name
        } else if let source = value as? RecommendationSource {
            name = source.name
        } else {
            continue
        }
        result[try CatalogNameNormalizer.comparisonKey(name)] = value
    }
    return result
}
