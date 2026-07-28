import Foundation
import SQLite3

struct ImportCancellation: Sendable {
    let isCancelled: @Sendable () -> Bool

    static let never = ImportCancellation(isCancelled: { false })
}

private struct StagedCSVRecord: Codable {
    let lineNumber: Int
    let values: [String]

    init(_ record: CSVRecord) {
        lineNumber = record.lineNumber
        values = record.values
    }

    var csvRecord: CSVRecord {
        CSVRecord(lineNumber: lineNumber, values: values)
    }
}

private struct StagedImportIssue: Codable {
    let lineNumber: Int
    let field: String
    let code: String
    let description: String
    let retryable: Bool

    init(_ issue: ImportIssue) {
        lineNumber = issue.lineNumber
        field = issue.field
        code = issue.code
        description = issue.description
        retryable = issue.retryable
    }
}

private struct ImportStagingMetadata: Codable {
    let token: UUID
    let sourceFingerprint: String
    let mappingFingerprint: String
    let headers: [String]
    let rowCount: Int
}

private extension PreparedImportRow {
    var hasBlockingIssue: Bool {
        issues.contains { $0.severity == .error }
    }
}

private final class ImportPreviewAccumulator {
    private let mapping: CSVFieldMapping
    private let headers: [String]
    private let previewLimit: Int
    private let existingTags: Set<String>
    private let existingCollections: Set<String>
    private let existingSources: Set<String>

    private var totalRows = 0
    private var importableRows = 0
    private var warningRows = 0
    private var errorRows = 0
    private var duplicateRows = 0
    private var sampleRows: [PreparedImportRow] = []
    private var sampleIssues: [ImportIssue] = []
    private var issueCount = 0
    private var newTags = Set<String>()
    private var newCollections = Set<String>()
    private var newSources = Set<String>()

    init(
        repository: BookRepository,
        mapping: CSVFieldMapping,
        headers: [String],
        previewLimit: Int
    ) throws {
        self.mapping = mapping
        self.headers = headers
        self.previewLimit = previewLimit
        existingTags = Set(try repository.tagSummaries().map {
            try CatalogNameNormalizer.comparisonKey($0.tag.name)
        })
        existingCollections = Set(try repository.collectionSummaries().map {
            try CatalogNameNormalizer.comparisonKey($0.collection.name)
        })
        existingSources = Set(try repository.sourceSummaries().map {
            try CatalogNameNormalizer.comparisonKey($0.source.name)
        })
    }

    func consume(_ row: PreparedImportRow) throws {
        totalRows += 1
        issueCount += row.issues.count
        if sampleRows.count < previewLimit { sampleRows.append(row) }
        if sampleIssues.count < previewLimit * 4 {
            sampleIssues.append(
                contentsOf: row.issues.prefix(previewLimit * 4 - sampleIssues.count)
            )
        }
        if row.hasBlockingIssue { errorRows += 1 }
        if row.issues.contains(where: { $0.severity == .warning }) { warningRows += 1 }
        if !row.duplicateMatches.isEmpty { duplicateRows += 1 }
        guard !row.hasBlockingIssue, row.duplicateMatches.isEmpty else { return }

        importableRows += 1
        for name in row.tags {
            let key = try CatalogNameNormalizer.comparisonKey(name)
            if !existingTags.contains(key) { newTags.insert(key) }
        }
        for name in row.collections {
            let key = try CatalogNameNormalizer.comparisonKey(name)
            if !existingCollections.contains(key) { newCollections.insert(key) }
        }
        for name in row.sources {
            let key = try CatalogNameNormalizer.comparisonKey(name)
            if !existingSources.contains(key) { newSources.insert(key) }
        }
    }

    func preview(staging: ImportStagingReference) -> ImportPreview {
        ImportPreview(
            totalRows: totalRows,
            importableRows: importableRows,
            warningRows: warningRows,
            errorRows: errorRows,
            potentialDuplicateRows: duplicateRows,
            newTagCount: newTags.count,
            newCollectionCount: newCollections.count,
            newSourceCount: newSources.count,
            sampleRows: sampleRows,
            mapping: mapping,
            availableHeaders: headers,
            wasTruncated: totalRows > previewLimit,
            issues: sampleIssues,
            issuesWereTruncated: issueCount > sampleIssues.count,
            staging: staging
        )
    }
}

private struct StagedCSVRecordReader {
    let url: URL

    func forEach(_ body: (StagedCSVRecord) throws -> Void) throws {
        guard let stream = InputStream(url: url) else {
            throw PortabilityError.staleImportPreview
        }
        stream.open()
        defer { stream.close() }
        var pending = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)

        func consumeLines(final: Bool) throws {
            while let newline = pending.firstIndex(of: 0x0A) {
                let line = pending[..<newline]
                pending.removeSubrange(...newline)
                if !line.isEmpty {
                    try body(try JSONDecoder().decode(StagedCSVRecord.self, from: Data(line)))
                }
            }
            if final, !pending.isEmpty {
                try body(try JSONDecoder().decode(StagedCSVRecord.self, from: pending))
                pending.removeAll()
            }
        }

        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 { throw stream.streamError ?? PortabilityError.staleImportPreview }
            if count == 0 { break }
            pending.append(contentsOf: buffer.prefix(count))
            try consumeLines(final: false)
        }
        try consumeLines(final: true)
    }
}

private final class ImportReportWriter {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let fileURL: URL
    private var handle: FileHandle?
    private(set) var issueCount = 0

    init(fileManager: FileManager) throws {
        self.fileManager = fileManager
        directoryURL = fileManager.temporaryDirectory.appendingPathComponent(
            "BookAtlas-ImportIssues-\(UUID().uuidString)",
            isDirectory: true
        )
        fileURL = directoryURL.appendingPathComponent("issues.jsonl")
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        guard fileManager.createFile(atPath: fileURL.path, contents: nil) else {
            throw PortabilityError.invalidDestination
        }
        handle = try FileHandle(forWritingTo: fileURL)
    }

    func append(_ issue: ImportIssue) throws {
        try handle?.write(contentsOf: JSONEncoder().encode(StagedImportIssue(issue)))
        try handle?.write(contentsOf: Data([0x0A]))
        issueCount += 1
    }

    func append(contentsOf issues: [ImportIssue]) throws {
        for issue in issues { try append(issue) }
    }

    func finish() throws -> ImportErrorReport? {
        try handle?.synchronize()
        try handle?.close()
        handle = nil
        guard issueCount > 0 else {
            try? fileManager.removeItem(at: directoryURL)
            return nil
        }
        return ImportErrorReport(fileURL: fileURL, issueCount: issueCount)
    }

    func discard() {
        try? handle?.close()
        handle = nil
        try? fileManager.removeItem(at: directoryURL)
    }
}

final class LibraryImportCoordinator {
    private let parser: StreamingCSVParser
    private let limits: CSVParserLimits
    private let fileManager: FileManager

    init(
        limits: CSVParserLimits = CSVParserLimits(),
        fileManager: FileManager = .default
    ) {
        self.limits = limits
        self.fileManager = fileManager
        parser = StreamingCSVParser(limits: limits)
    }

    func parse(url: URL) throws -> CSVDocument {
        try parser.parse(url: url)
    }

    func prepare(
        url: URL,
        mapping requestedMapping: CSVFieldMapping?,
        repository: BookRepository,
        cancellation: ImportCancellation = .never
    ) throws -> ImportPreview {
        let stagingDirectory = fileManager.temporaryDirectory.appendingPathComponent(
            "BookAtlas-Import-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: true
        )
        let recordsURL = stagingDirectory.appendingPathComponent("records.jsonl")
        guard fileManager.createFile(atPath: recordsURL.path, contents: nil) else {
            try? fileManager.removeItem(at: stagingDirectory)
            throw PortabilityError.invalidDestination
        }
        let writer = try FileHandle(forWritingTo: recordsURL)
        var completed = false
        defer {
            try? writer.close()
            if !completed {
                try? fileManager.removeItem(at: stagingDirectory)
            }
        }

        var state: ImportPreviewAccumulator?
        var effectiveMapping: CSVFieldMapping?
        var headerIndices: [String: Int] = [:]
        var batchLines: [UUID: Int] = [:]
        let batchURL = stagingDirectory.appendingPathComponent("batch.sqlite")
        let batchRepository = try BookRepository(databaseURL: batchURL)
        defer { try? batchRepository.close() }

        let summary = try batchRepository.transaction {
            try parser.stream(
                url: url,
                cancellation: cancellation.isCancelled,
                onHeader: { headers in
                    let mapping = requestedMapping ?? .inferred(from: headers)
                    try Self.validateRequiredMapping(mapping)
                    effectiveMapping = mapping
                    headerIndices = Self.headerIndices(headers)
                    state = try ImportPreviewAccumulator(
                        repository: repository,
                        mapping: mapping,
                        headers: headers,
                        previewLimit: self.limits.previewRows
                    )
                },
                onRecord: { record in
                    if cancellation.isCancelled() { throw PortabilityError.cancelled }
                    let data = try JSONEncoder().encode(StagedCSVRecord(record))
                    try writer.write(contentsOf: data)
                    try writer.write(contentsOf: Data([0x0A]))
                    guard let mapping = effectiveMapping,
                          let accumulator = state
                    else { throw CSVParserError.missingHeader }
                    let prepared = try self.prepare(
                        record,
                        mapping: mapping,
                        headerIndices: headerIndices,
                        repository: repository,
                        batchRepository: batchRepository,
                        batchLines: batchLines
                    )
                    try accumulator.consume(prepared)
                    if !prepared.hasBlockingIssue, prepared.duplicateMatches.isEmpty {
                        let proposedID = Self.stagingBookID(lineNumber: prepared.lineNumber)
                        _ = try batchRepository.create(
                            Self.identityOnlyDraft(prepared.draft),
                            id: proposedID,
                            at: Date(timeIntervalSince1970: TimeInterval(prepared.lineNumber))
                        )
                        batchLines[proposedID] = prepared.lineNumber
                    }
                }
            )
        }
        try writer.synchronize()
        try writer.close()
        try batchRepository.close()
        removeSQLiteFiles(
            at: stagingDirectory.appendingPathComponent("batch.sqlite"),
            fileManager: fileManager
        )

        guard let mapping = effectiveMapping, let accumulator = state else {
            throw CSVParserError.missingHeader
        }
        let token = UUID()
        let mappingFingerprint = Self.mappingFingerprint(mapping)
        let metadata = ImportStagingMetadata(
            token: token,
            sourceFingerprint: summary.contentFingerprint,
            mappingFingerprint: mappingFingerprint,
            headers: summary.headers,
            rowCount: summary.recordCount
        )
        try JSONEncoder().encode(metadata).write(
            to: stagingDirectory.appendingPathComponent("metadata.json"),
            options: .atomic
        )
        completed = true
        return accumulator.preview(
            staging: ImportStagingReference(
                directoryURL: stagingDirectory,
                recordsURL: recordsURL,
                token: token,
                sourceFingerprint: summary.contentFingerprint,
                mappingFingerprint: mappingFingerprint,
                rowCount: summary.recordCount
            )
        )
    }

    func preview(
        document: CSVDocument,
        mapping: CSVFieldMapping,
        repository: BookRepository
    ) throws -> ImportPreview {
        let directory = fileManager.temporaryDirectory.appendingPathComponent(
            "BookAtlas-Import-Document-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let input = directory.appendingPathComponent("input.csv")
        var encoded = CSVEncoder.row(document.headers, formulaSafe: false)
        for record in document.records {
            encoded += CSVEncoder.row(record.values, formulaSafe: false)
        }
        try Data(encoded.utf8).write(to: input)
        defer { try? fileManager.removeItem(at: directory) }
        return try prepare(
            url: input,
            mapping: mapping,
            repository: repository
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
        let metadata = try validateStaging(preview.staging, mapping: preview.mapping)
        guard metadata.rowCount == preview.totalRows else {
            throw PortabilityError.staleImportPreview
        }
        let headerIndices = Self.headerIndices(metadata.headers)
        var imported = 0
        var skipped = 0
        var warningCount = 0
        var failed = 0
        var duplicates = 0
        let reportWriter = try ImportReportWriter(fileManager: fileManager)
        var succeeded = false
        defer {
            discard(preview)
            if !succeeded { reportWriter.discard() }
        }

        let result = try repository.transaction {
            var tags = try nameMap(try repository.tagSummaries().map(\.tag))
            var collections = try nameMap(try repository.collectionSummaries().map(\.collection))
            var sources = try nameMap(try repository.sourceSummaries().map(\.source))

            try StagedCSVRecordReader(url: preview.staging.recordsURL).forEach { record in
                if cancellation.isCancelled() { throw PortabilityError.cancelled }
                let row = try prepare(
                    record.csvRecord,
                    mapping: preview.mapping,
                    headerIndices: headerIndices,
                    repository: repository,
                    batchRepository: nil,
                    batchLines: [:]
                )
                if row.hasBlockingIssue {
                    skipped += 1
                    failed += 1
                    try reportWriter.append(contentsOf: row.issues)
                    return
                }
                warningCount += row.issues.filter {
                    $0.severity == .warning && !$0.code.hasPrefix("duplicate_")
                }.count

                let proposedID = UUID()
                let duplicateSearch = try repository.duplicateCandidateSearch(
                    for: DuplicateProbe(id: proposedID, draft: row.draft),
                    includingPossible: false
                )
                if !duplicateSearch.candidates.isEmpty {
                    skipped += 1
                    duplicates += 1
                    warningCount += 1
                    try reportWriter.append(
                        ImportIssue(
                            lineNumber: row.lineNumber,
                            field: "record",
                            code: "duplicate_at_execution",
                            description: "执行时发现 Exact/Strong 重复；该行已跳过且未覆盖或合并。",
                            severity: .warning,
                            retryable: true
                        )
                    )
                    return
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
                duplicateRows: duplicates,
                errorReport: nil
            )
        }
        let report = try reportWriter.finish()
        succeeded = true
        return ImportResult(
            imported: result.imported,
            skipped: result.skipped,
            warnings: result.warnings,
            failed: result.failed,
            duplicateRows: result.duplicateRows,
            errorReport: report
        )
    }

    func discard(_ preview: ImportPreview) {
        try? fileManager.removeItem(at: preview.staging.directoryURL)
    }

    private func prepare(
        _ record: CSVRecord,
        mapping: CSVFieldMapping,
        headerIndices: [String: Int],
        repository: BookRepository,
        batchRepository: BookRepository?,
        batchLines: [UUID: Int]
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
        let existingDuplicates: [DuplicateCandidate]
        let batchDuplicates: [DuplicateCandidate]
        if issues.contains(where: { $0.severity == .error }) {
            existingDuplicates = []
            batchDuplicates = []
        } else {
            existingDuplicates = try repository.duplicateCandidates(
                for: DuplicateProbe(id: UUID(), draft: draft),
                includingPossible: false
            )
            batchDuplicates = try batchRepository?.duplicateCandidates(
                for: DuplicateProbe(id: UUID(), draft: Self.identityOnlyDraft(draft)),
                includingPossible: false
            ) ?? []
        }
        var matches = existingDuplicates.map {
            ImportDuplicateMatch(scope: .existingLibrary, confidence: $0.confidence)
        }
        matches.append(contentsOf: batchDuplicates.map {
            ImportDuplicateMatch(
                scope: .currentBatch(earlierLine: batchLines[$0.existingBook.id] ?? 0),
                confidence: $0.confidence
            )
        })
        if !existingDuplicates.isEmpty {
            issues.append(ImportIssue(
                lineNumber: record.lineNumber,
                field: "record",
                code: "duplicate_existing_library",
                description: "与当前书库中的记录形成 Exact/Strong 重复；预计跳过。",
                severity: .warning,
                retryable: true
            ))
        }
        if let earlierLine = matches.compactMap({ match -> Int? in
            if case let .currentBatch(line) = match.scope { return line }
            return nil
        }).min() {
            issues.append(ImportIssue(
                lineNumber: record.lineNumber,
                field: "record",
                code: "duplicate_current_batch",
                description: "与本批次更早的第 \(earlierLine) 行形成 Exact/Strong 重复；预计跳过。",
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
            duplicateCandidates: existingDuplicates + batchDuplicates,
            duplicateMatches: matches
        )
    }

    private func validateStaging(
        _ reference: ImportStagingReference,
        mapping: CSVFieldMapping
    ) throws -> ImportStagingMetadata {
        let metadataURL = reference.directoryURL.appendingPathComponent("metadata.json")
        guard fileManager.fileExists(atPath: reference.recordsURL.path),
              fileManager.fileExists(atPath: metadataURL.path)
        else { throw PortabilityError.staleImportPreview }
        let metadata = try JSONDecoder().decode(
            ImportStagingMetadata.self,
            from: Data(contentsOf: metadataURL)
        )
        guard metadata.token == reference.token,
              metadata.sourceFingerprint == reference.sourceFingerprint,
              metadata.mappingFingerprint == reference.mappingFingerprint,
              metadata.mappingFingerprint == Self.mappingFingerprint(mapping),
              metadata.rowCount == reference.rowCount
        else { throw PortabilityError.staleImportPreview }
        return metadata
    }

    private static func validateRequiredMapping(_ mapping: CSVFieldMapping) throws {
        for required in ImportField.allCases where required.isRequired {
            guard mapping.columns[required] != nil else {
                throw PortabilityError.missingRequiredMapping(required)
            }
        }
        guard mapping.columns[.formatVersion] != nil else {
            throw PortabilityError.missingRequiredMapping(.formatVersion)
        }
    }

    private static func headerIndices(_ headers: [String]) -> [String: Int] {
        Dictionary(
            headers.enumerated().map { ($0.element, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private static func mappingFingerprint(_ mapping: CSVFieldMapping) -> String {
        let value = mapping.columns
            .map { ($0.key.rawValue, $0.value) }
            .sorted { $0.0 < $1.0 }
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "\n")
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private static func stagingBookID(lineNumber: Int) -> UUID {
        let suffix = String(format: "%012d", max(0, lineNumber))
        return UUID(uuidString: "00000000-0000-0000-0000-\(suffix)")!
    }

    private static func identityOnlyDraft(_ draft: BookDraft) -> BookDraft {
        BookDraft(
            title: draft.title,
            originalTitle: draft.originalTitle,
            author: draft.author,
            isbn: draft.isbn,
            publisher: draft.publisher,
            publicationDate: draft.publicationDate,
            kind: draft.kind,
            readingStatus: draft.readingStatus
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

    func exportErrorReport(_ report: ImportErrorReport, to destination: URL) throws {
        guard destination.isFileURL else { throw PortabilityError.invalidDestination }
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw PortabilityError.destinationExists
        }
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(
            ".bookatlas-\(UUID().uuidString).tmp",
            isDirectory: false
        )
        guard fileManager.createFile(atPath: temporary.path, contents: nil) else {
            throw PortabilityError.invalidDestination
        }
        do {
            let output = try FileHandle(forWritingTo: temporary)
            defer { try? output.close() }
            try output.write(contentsOf: Data(CSVEncoder.row(
                ["row", "field", "code", "description", "retryable"],
                formulaSafe: false
            ).utf8))
            try forEachStagedIssue(at: report.fileURL) { issue in
                try output.write(contentsOf: Data(CSVEncoder.row([
                    String(issue.lineNumber),
                    issue.field,
                    issue.code,
                    issue.description,
                    issue.retryable ? "true" : "false"
                ]).utf8))
            }
            try output.synchronize()
            try output.close()
            try fileManager.moveItem(at: temporary, to: destination)
            try? fileManager.removeItem(at: report.fileURL.deletingLastPathComponent())
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }

    func discardErrorReport(_ report: ImportErrorReport) {
        try? fileManager.removeItem(at: report.fileURL.deletingLastPathComponent())
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

    private func forEachStagedIssue(
        at url: URL,
        _ body: (StagedImportIssue) throws -> Void
    ) throws {
        guard let stream = InputStream(url: url) else {
            throw PortabilityError.staleImportPreview
        }
        stream.open()
        defer { stream.close() }
        var pending = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)

        func consume(final: Bool) throws {
            while let newline = pending.firstIndex(of: 0x0A) {
                let line = pending[..<newline]
                pending.removeSubrange(...newline)
                if !line.isEmpty {
                    try body(try JSONDecoder().decode(StagedImportIssue.self, from: Data(line)))
                }
            }
            if final, !pending.isEmpty {
                try body(try JSONDecoder().decode(StagedImportIssue.self, from: pending))
                pending.removeAll()
            }
        }

        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 { throw stream.streamError ?? PortabilityError.staleImportPreview }
            if count == 0 { break }
            pending.append(contentsOf: buffer.prefix(count))
            try consume(final: false)
        }
        try consume(final: true)
    }
}

struct BookAtlasSchemaValidationResult: Equatable, Sendable {
    let schemaVersion: Int
    let bookCount: Int
}

final class BookAtlasSchemaValidator {
    func validate(
        database: SQLiteDatabase,
        expectedVersion: Int
    ) throws -> BookAtlasSchemaValidationResult {
        do {
            guard (1 ... BookAtlasSchema.latestVersion).contains(expectedVersion),
                  try database.schemaVersion() == expectedVersion,
                  try database.integrityCheck(),
                  try database.foreignKeyCheck()
            else { throw PortabilityError.invalidBackupSchema }

            try validateMigrationHistory(database, version: expectedVersion)
            try validateStructure(database, version: expectedVersion)
            let books = try validateDomainRows(database, version: expectedVersion)
            return BookAtlasSchemaValidationResult(
                schemaVersion: expectedVersion,
                bookCount: books
            )
        } catch let error as PortabilityError {
            throw error
        } catch {
            throw PortabilityError.invalidBackupSchema
        }
    }

    func validateFile(_ url: URL, expectedVersion: Int) throws -> BookAtlasSchemaValidationResult {
        let database = try SQLiteDatabase(path: url.path, readOnly: true)
        defer { try? database.close() }
        return try validate(database: database, expectedVersion: expectedVersion)
    }

    private func validateMigrationHistory(_ database: SQLiteDatabase, version: Int) throws {
        let rows = try database.query(
            "SELECT version, applied_at FROM schema_migrations ORDER BY version"
        ) { row in
            (Int(row.integer(at: 0)), row.string(at: 1))
        }
        guard rows.map(\.0) == Array(1 ... version),
              rows.allSatisfy({ StorageDateCodec.decode($0.1) != nil })
        else { throw PortabilityError.invalidBackupSchema }
    }

    private func validateStructure(_ database: SQLiteDatabase, version: Int) throws {
        var expectations = Self.versionOneTables
        if version >= 2 {
            var collections = expectations["book_collections"]!
            collections.columns.append("description")
            expectations["book_collections"] = collections
        }
        if version >= 4 {
            expectations.merge(Self.versionFourTables) { current, _ in current }
        }

        let existingTables = Set(try database.query(
            "SELECT name FROM sqlite_master WHERE type = 'table'"
        ) { $0.string(at: 0) }.compactMap { $0 })
        guard Set(expectations.keys).isSubset(of: existingTables) else {
            throw PortabilityError.invalidBackupSchema
        }

        for (table, expectation) in expectations {
            let columns = try database.query("PRAGMA table_info(\(table))") { row in
                (
                    name: row.string(at: 1) ?? "",
                    notNull: row.integer(at: 3) == 1,
                    primaryKeyOrder: Int(row.integer(at: 5))
                )
            }
            let names = Set(columns.map(\.name))
            guard Set(expectation.columns).isSubset(of: names) else {
                throw PortabilityError.invalidBackupSchema
            }
            let primaryKey = columns
                .filter { $0.primaryKeyOrder > 0 }
                .sorted { $0.primaryKeyOrder < $1.primaryKeyOrder }
                .map(\.name)
            guard primaryKey == expectation.primaryKey else {
                throw PortabilityError.invalidBackupSchema
            }
            let nonNullNames = Set(columns.filter(\.notNull).map(\.name))
            guard Set(expectation.requiredNonNull).isSubset(of: nonNullNames) else {
                throw PortabilityError.invalidBackupSchema
            }

            let sql = try database.query(
                "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
                bindings: [.text(table)]
            ) { $0.string(at: 0) }.first ?? nil
            let normalizedSQL = Self.normalizedSQL(sql ?? "")
            guard expectation.constraintFragments.allSatisfy({
                normalizedSQL.contains(Self.normalizedSQL($0))
            }) else { throw PortabilityError.invalidBackupSchema }

            let foreignKeys = try database.query("PRAGMA foreign_key_list(\(table))") { row in
                ForeignKeyDefinition(
                    referencedTable: row.string(at: 2) ?? "",
                    sourceColumn: row.string(at: 3) ?? "",
                    targetColumn: row.string(at: 4) ?? "",
                    deleteAction: (row.string(at: 6) ?? "").uppercased()
                )
            }
            guard Set(expectation.foreignKeys).isSubset(of: Set(foreignKeys)) else {
                throw PortabilityError.invalidBackupSchema
            }
            try validateUniqueKeys(
                database,
                table: table,
                expected: expectation.uniqueKeys
            )
        }
    }

    private func validateUniqueKeys(
        _ database: SQLiteDatabase,
        table: String,
        expected: [[String]]
    ) throws {
        guard !expected.isEmpty else { return }
        let indexes = try database.query("PRAGMA index_list(\(table))") { row in
            (name: row.string(at: 1) ?? "", unique: row.integer(at: 2) == 1)
        }
        var actual = Set<[String]>()
        for index in indexes where index.unique {
            let columns = try database.query("PRAGMA index_info(\(index.name))") {
                (order: Int($0.integer(at: 0)), name: $0.string(at: 2) ?? "")
            }.sorted { $0.order < $1.order }.map(\.name)
            actual.insert(columns)
        }
        guard Set(expected).isSubset(of: actual) else {
            throw PortabilityError.invalidBackupSchema
        }
    }

    private func validateDomainRows(_ database: SQLiteDatabase, version: Int) throws -> Int {
        let books = try database.query(
            """
            SELECT id, title, original_title, author, isbn, publisher, publication_date,
                   kind, reading_status, priority, note, created_at, updated_at,
                   started_at, finished_at
            FROM books ORDER BY id
            """
        ) { row -> Book in
            guard let id = UUID(uuidString: row.string(at: 0) ?? ""),
                  let title = row.string(at: 1),
                  let author = row.string(at: 3),
                  let kind = BookKind(rawValue: row.string(at: 7) ?? ""),
                  let status = ReadingStatus(rawValue: row.string(at: 8) ?? ""),
                  let createdAt = StorageDateCodec.decode(row.string(at: 11)),
                  let updatedAt = StorageDateCodec.decode(row.string(at: 12))
            else { throw PortabilityError.invalidBackupSchema }
            let priority: BookPriority?
            if let raw = row.string(at: 9) {
                guard let value = Int(raw), let parsed = BookPriority(rawValue: value) else {
                    throw PortabilityError.invalidBackupSchema
                }
                priority = parsed
            } else {
                priority = nil
            }
            let publicationDate = try row.string(at: 6).map(PublicationDate.init(storageValue:))
            let startedAt = try validatedOptionalDate(row.string(at: 13))
            let finishedAt = try validatedOptionalDate(row.string(at: 14))
            return try Book(
                id: id,
                draft: BookDraft(
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
                    startedAt: startedAt,
                    finishedAt: finishedAt
                ),
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
        let bookIDs = Set(books.map(\.id))

        _ = try database.query(
            "SELECT id, name, created_at, updated_at FROM tags"
        ) { row in
            try Tag(
                id: try requiredUUID(row.string(at: 0)),
                name: try requiredString(row.string(at: 1)),
                createdAt: try requiredDate(row.string(at: 2)),
                updatedAt: try requiredDate(row.string(at: 3))
            )
        }
        let collectionColumns = version >= 2
            ? "id, name, description, created_at, updated_at"
            : "id, name, NULL, created_at, updated_at"
        _ = try database.query("SELECT \(collectionColumns) FROM book_collections") { row in
            try BookCollection(
                id: try requiredUUID(row.string(at: 0)),
                name: try requiredString(row.string(at: 1)),
                description: row.string(at: 2),
                createdAt: try requiredDate(row.string(at: 3)),
                updatedAt: try requiredDate(row.string(at: 4))
            )
        }
        _ = try database.query(
            "SELECT id, name, details, created_at, updated_at FROM recommendation_sources"
        ) { row in
            try RecommendationSource(
                id: try requiredUUID(row.string(at: 0)),
                name: try requiredString(row.string(at: 1)),
                details: row.string(at: 2),
                createdAt: try requiredDate(row.string(at: 3)),
                updatedAt: try requiredDate(row.string(at: 4))
            )
        }
        for tableAndColumns in [
            ("book_tags", ["book_id", "tag_id"]),
            ("book_collections_books", ["collection_id", "book_id"]),
            ("book_sources", ["book_id", "source_id"])
        ] {
            _ = try database.query(
                "SELECT \(tableAndColumns.1.joined(separator: ", ")) FROM \(tableAndColumns.0)"
            ) { row in
                (try requiredUUID(row.string(at: 0)), try requiredUUID(row.string(at: 1)))
            }
        }
        _ = try database.query(
            "SELECT id, book_id, kind, label, value, created_at, updated_at FROM external_links"
        ) { row in
            guard let kind = ExternalLinkKind(rawValue: row.string(at: 2) ?? "") else {
                throw PortabilityError.invalidBackupSchema
            }
            return try ExternalLink(
                id: try requiredUUID(row.string(at: 0)),
                bookID: try requiredUUID(row.string(at: 1)),
                kind: kind,
                label: row.string(at: 3),
                value: try requiredString(row.string(at: 4)),
                createdAt: try requiredDate(row.string(at: 5)),
                updatedAt: try requiredDate(row.string(at: 6))
            )
        }
        _ = try database.query(
            """
            SELECT id, source_book_id, target_book_id, relation_kind, note, created_at
            FROM manual_book_relations
            """
        ) { row in
            guard let kind = ManualRelationKind(rawValue: row.string(at: 3) ?? "") else {
                throw PortabilityError.invalidBackupSchema
            }
            return try ManualBookRelation(
                id: try requiredUUID(row.string(at: 0)),
                sourceBookID: try requiredUUID(row.string(at: 1)),
                targetBookID: try requiredUUID(row.string(at: 2)),
                kind: kind,
                note: row.string(at: 4),
                createdAt: try requiredDate(row.string(at: 5))
            )
        }

        if version >= 4 {
            try validateDuplicateRows(database, books: books, bookIDs: bookIDs)
        }
        return books.count
    }

    private func validateDuplicateRows(
        _ database: SQLiteDatabase,
        books: [Book],
        bookIDs: Set<UUID>
    ) throws {
        let keys = try database.query(
            """
            SELECT book_id, valid_isbn, normalized_title, normalized_author,
                   normalized_original_title
            FROM book_duplicate_keys
            """
        ) { row in
            DuplicateValidationKey(
                bookID: try requiredUUID(row.string(at: 0)),
                validISBN: row.string(at: 1),
                title: try requiredPresentString(row.string(at: 2)),
                author: try requiredPresentString(row.string(at: 3)),
                originalTitle: row.string(at: 4)
            )
        }
        guard Set(keys.map(\.bookID)) == bookIDs else {
            throw PortabilityError.invalidBackupSchema
        }
        let keysByID = Dictionary(uniqueKeysWithValues: keys.map { ($0.bookID, $0) })
        for book in books {
            guard let key = keysByID[book.id],
                  key.validISBN == DuplicateISBNNormalizer.validate(book.isbn).validIdentifier,
                  key.title == DuplicateTextNormalizer.titleKey(book.title),
                  key.author == DuplicateTextNormalizer.authorKey(book.author),
                  key.originalTitle == book.originalTitle.map(DuplicateTextNormalizer.titleKey)
                    .flatMap({ $0.isEmpty ? nil : $0 })
            else { throw PortabilityError.invalidBackupSchema }
        }
        let tokenRows = try database.query(
            "SELECT book_id, token FROM book_duplicate_title_tokens"
        ) { row in
            (try requiredUUID(row.string(at: 0)), try requiredString(row.string(at: 1)))
        }
        let groupedTokens = Dictionary(grouping: tokenRows, by: \.0)
            .mapValues { Set($0.map(\.1)) }
        for book in books {
            guard groupedTokens[book.id, default: []]
                == DuplicateTextNormalizer.titleTokens(book.title)
            else { throw PortabilityError.invalidBackupSchema }
        }
        _ = try database.query(
            """
            SELECT first_book_id, second_book_id, disposition, created_at
            FROM ignored_duplicate_pairs
            """
        ) { row in
            let first = try requiredUUID(row.string(at: 0))
            let second = try requiredUUID(row.string(at: 1))
            guard first.uuidString < second.uuidString,
                  bookIDs.contains(first),
                  bookIDs.contains(second),
                  let disposition = DuplicatePairDisposition(rawValue: row.string(at: 2) ?? "")
            else { throw PortabilityError.invalidBackupSchema }
            return IgnoredDuplicatePair(
                firstBookID: first,
                secondBookID: second,
                disposition: disposition,
                createdAt: try requiredDate(row.string(at: 3))
            )
        }
    }

    private static func normalizedSQL(_ value: String) -> String {
        value.lowercased().filter { !$0.isWhitespace && $0 != "\"" && $0 != "`" }
    }

    private static let versionOneTables: [String: TableExpectation] = [
        "schema_migrations": TableExpectation(
            columns: ["version", "applied_at"],
            primaryKey: ["version"],
            requiredNonNull: ["version", "applied_at"]
        ),
        "books": TableExpectation(
            columns: [
                "id", "title", "original_title", "author", "isbn", "publisher",
                "publication_date", "kind", "reading_status", "priority", "note",
                "created_at", "updated_at", "started_at", "finished_at"
            ],
            primaryKey: ["id"],
            requiredNonNull: [
                "id", "title", "author", "kind", "reading_status", "created_at", "updated_at"
            ],
            constraintFragments: [
                "CHECK (length(trim(title)) > 0)",
                "CHECK (length(trim(author)) > 0)",
                "reading_status IN ('wish_to_read', 'reading', 'read', 'paused', 'abandoned', 'reference', 'archived')",
                "priority BETWEEN 1 AND 5"
            ]
        ),
        "tags": TableExpectation(
            columns: ["id", "name", "created_at", "updated_at"],
            primaryKey: ["id"],
            requiredNonNull: ["id", "name", "created_at", "updated_at"],
            uniqueKeys: [["name"]],
            constraintFragments: ["CHECK (length(trim(name)) > 0)"]
        ),
        "book_tags": joinExpectation(
            primaryKey: ["book_id", "tag_id"],
            first: ("book_id", "books"),
            second: ("tag_id", "tags")
        ),
        "book_collections": TableExpectation(
            columns: ["id", "name", "created_at", "updated_at"],
            primaryKey: ["id"],
            requiredNonNull: ["id", "name", "created_at", "updated_at"],
            uniqueKeys: [["name"]],
            constraintFragments: ["CHECK (length(trim(name)) > 0)"]
        ),
        "book_collections_books": joinExpectation(
            primaryKey: ["collection_id", "book_id"],
            first: ("collection_id", "book_collections"),
            second: ("book_id", "books")
        ),
        "recommendation_sources": TableExpectation(
            columns: ["id", "name", "details", "created_at", "updated_at"],
            primaryKey: ["id"],
            requiredNonNull: ["id", "name", "created_at", "updated_at"],
            uniqueKeys: [["name"]],
            constraintFragments: ["CHECK (length(trim(name)) > 0)"]
        ),
        "book_sources": joinExpectation(
            primaryKey: ["book_id", "source_id"],
            first: ("book_id", "books"),
            second: ("source_id", "recommendation_sources")
        ),
        "external_links": TableExpectation(
            columns: ["id", "book_id", "kind", "label", "value", "created_at", "updated_at"],
            primaryKey: ["id"],
            requiredNonNull: ["id", "book_id", "kind", "value", "created_at", "updated_at"],
            foreignKeys: [ForeignKeyDefinition(
                referencedTable: "books",
                sourceColumn: "book_id",
                targetColumn: "id",
                deleteAction: "CASCADE"
            )],
            uniqueKeys: [["book_id", "kind", "value"]],
            constraintFragments: [
                "kind IN ('web', 'local_authorization')",
                "CHECK (length(trim(value)) > 0)"
            ]
        ),
        "manual_book_relations": TableExpectation(
            columns: [
                "id", "source_book_id", "target_book_id", "relation_kind", "note", "created_at"
            ],
            primaryKey: ["id"],
            requiredNonNull: [
                "id", "source_book_id", "target_book_id", "relation_kind", "created_at"
            ],
            foreignKeys: [
                ForeignKeyDefinition(
                    referencedTable: "books",
                    sourceColumn: "source_book_id",
                    targetColumn: "id",
                    deleteAction: "CASCADE"
                ),
                ForeignKeyDefinition(
                    referencedTable: "books",
                    sourceColumn: "target_book_id",
                    targetColumn: "id",
                    deleteAction: "CASCADE"
                )
            ],
            uniqueKeys: [["source_book_id", "target_book_id", "relation_kind"]],
            constraintFragments: ["CHECK (source_book_id <> target_book_id)"]
        )
    ]

    private static let versionFourTables: [String: TableExpectation] = [
        "book_duplicate_keys": TableExpectation(
            columns: [
                "book_id", "valid_isbn", "normalized_title", "normalized_author",
                "normalized_original_title"
            ],
            primaryKey: ["book_id"],
            requiredNonNull: ["book_id", "normalized_title", "normalized_author"],
            foreignKeys: [ForeignKeyDefinition(
                referencedTable: "books",
                sourceColumn: "book_id",
                targetColumn: "id",
                deleteAction: "CASCADE"
            )]
        ),
        "book_duplicate_title_tokens": TableExpectation(
            columns: ["book_id", "token"],
            primaryKey: ["book_id", "token"],
            requiredNonNull: ["book_id", "token"],
            foreignKeys: [ForeignKeyDefinition(
                referencedTable: "books",
                sourceColumn: "book_id",
                targetColumn: "id",
                deleteAction: "CASCADE"
            )]
        ),
        "ignored_duplicate_pairs": TableExpectation(
            columns: ["first_book_id", "second_book_id", "disposition", "created_at"],
            primaryKey: ["first_book_id", "second_book_id"],
            requiredNonNull: [
                "first_book_id", "second_book_id", "disposition", "created_at"
            ],
            foreignKeys: [
                ForeignKeyDefinition(
                    referencedTable: "books",
                    sourceColumn: "first_book_id",
                    targetColumn: "id",
                    deleteAction: "CASCADE"
                ),
                ForeignKeyDefinition(
                    referencedTable: "books",
                    sourceColumn: "second_book_id",
                    targetColumn: "id",
                    deleteAction: "CASCADE"
                )
            ],
            constraintFragments: [
                "first_book_id < second_book_id",
                "disposition IN ('not_duplicate', 'separate_edition', 'separate_translation')"
            ]
        )
    ]

    private static func joinExpectation(
        primaryKey: [String],
        first: (String, String),
        second: (String, String)
    ) -> TableExpectation {
        TableExpectation(
            columns: primaryKey,
            primaryKey: primaryKey,
            requiredNonNull: primaryKey,
            foreignKeys: [
                ForeignKeyDefinition(
                    referencedTable: first.1,
                    sourceColumn: first.0,
                    targetColumn: "id",
                    deleteAction: "CASCADE"
                ),
                ForeignKeyDefinition(
                    referencedTable: second.1,
                    sourceColumn: second.0,
                    targetColumn: "id",
                    deleteAction: "CASCADE"
                )
            ]
        )
    }
}

private struct TableExpectation {
    var columns: [String]
    let primaryKey: [String]
    let requiredNonNull: [String]
    let foreignKeys: [ForeignKeyDefinition]
    let uniqueKeys: [[String]]
    let constraintFragments: [String]

    init(
        columns: [String],
        primaryKey: [String],
        requiredNonNull: [String],
        foreignKeys: [ForeignKeyDefinition] = [],
        uniqueKeys: [[String]] = [],
        constraintFragments: [String] = []
    ) {
        self.columns = columns
        self.primaryKey = primaryKey
        self.requiredNonNull = requiredNonNull
        self.foreignKeys = foreignKeys
        self.uniqueKeys = uniqueKeys
        self.constraintFragments = constraintFragments
    }
}

private struct ForeignKeyDefinition: Hashable {
    let referencedTable: String
    let sourceColumn: String
    let targetColumn: String
    let deleteAction: String
}

private struct DuplicateValidationKey {
    let bookID: UUID
    let validISBN: String?
    let title: String
    let author: String
    let originalTitle: String?
}

private func requiredUUID(_ value: String?) throws -> UUID {
    guard let value, let id = UUID(uuidString: value) else {
        throw PortabilityError.invalidBackupSchema
    }
    return id
}

private func requiredString(_ value: String?) throws -> String {
    guard let value, !value.isEmpty else {
        throw PortabilityError.invalidBackupSchema
    }
    return value
}

private func requiredPresentString(_ value: String?) throws -> String {
    guard let value else {
        throw PortabilityError.invalidBackupSchema
    }
    return value
}

private func requiredDate(_ value: String?) throws -> Date {
    guard let date = StorageDateCodec.decode(value) else {
        throw PortabilityError.invalidBackupSchema
    }
    return date
}

private func validatedOptionalDate(_ value: String?) throws -> Date? {
    guard let value else { return nil }
    guard let date = StorageDateCodec.decode(value) else {
        throw PortabilityError.invalidBackupSchema
    }
    return date
}

enum RestoreInjectionPoint: Equatable, Sendable {
    case afterRecoveryCopy
    case afterConnectionClose
    case afterOriginalPreparedForReplacement
    case afterReplacement
    case beforeReconnect
    case beforeRollbackReconnect
}

enum BackupFileOperation: Equatable, Sendable {
    case backupSnapshot
    case recoverySnapshot
    case stageRestore
    case installReplacement
}

struct RestoreCancellation: Sendable {
    let isCancelled: @Sendable () -> Bool

    static let never = RestoreCancellation(isCancelled: { false })
}

private struct RestoreState: Codable, Equatable {
    let formatVersion: Int
    let token: UUID
    let oldFilename: String
    let newFilename: String
    let schemaVersion: Int
}

private struct SimulatedRestoreTermination: Error {}

final class LibraryBackupCoordinator {
    static let backupExtension = "bookatlasbackup"
    static let manifestTable = "_bookatlas_backup_manifest"
    static let maximumBackupBytes: Int64 = 4 * 1_024 * 1_024 * 1_024
    static let diskSafetyReserveBytes: Int64 = 16 * 1_024 * 1_024
    static let restoreStateFilename = ".book-atlas-restore-state.json"

    private let fileManager: FileManager
    private let applicationVersion: String
    private let now: () -> Date
    private let injectFailure: (RestoreInjectionPoint) throws -> Void
    private let availableCapacity: (URL) -> Int64?
    private let injectedSystemError: (BackupFileOperation) -> Error?
    private let simulatedTerminationPoint: RestoreInjectionPoint?
    private let schemaValidator = BookAtlasSchemaValidator()

    init(
        fileManager: FileManager = .default,
        applicationVersion: String = "1.0",
        now: @escaping () -> Date = Date.init,
        injectFailure: @escaping (RestoreInjectionPoint) throws -> Void = { _ in },
        availableCapacity: @escaping (URL) -> Int64? = { url in
            try? url.resourceValues(
                forKeys: [.volumeAvailableCapacityForImportantUsageKey]
            ).volumeAvailableCapacityForImportantUsage
        },
        injectedSystemError: @escaping (BackupFileOperation) -> Error? = { _ in nil },
        simulatedTerminationPoint: RestoreInjectionPoint? = nil
    ) {
        self.fileManager = fileManager
        self.applicationVersion = applicationVersion
        self.now = now
        self.injectFailure = injectFailure
        self.availableCapacity = availableCapacity
        self.injectedSystemError = injectedSystemError
        self.simulatedTerminationPoint = simulatedTerminationPoint
    }

    func backup(
        repository: BookRepository,
        to destination: URL,
        cancellation: RestoreCancellation = .never,
        operation: BackupFileOperation = .backupSnapshot
    ) throws -> BackupResult {
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
            removeSQLiteFiles(at: temporaryBackup, fileManager: fileManager)
        }

        do {
            let sourceBytes = try repository.storageBytes()
            guard sourceBytes <= Self.maximumBackupBytes else {
                throw PortabilityError.backupTooLarge
            }
            try requireCapacity(
                at: destination.deletingLastPathComponent(),
                bytes: sourceBytes + Self.diskSafetyReserveBytes
            )
            try checkCancellation(cancellation)
            if let error = injectedSystemError(operation) { throw error }
            try repository.onlineBackup(to: temporaryBackup) {
                try self.checkCancellation(cancellation)
            }
            let database = try SQLiteDatabase(path: temporaryBackup.path)
            defer { try? database.close() }
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
            _ = try schemaValidator.validate(
                database: database,
                expectedVersion: repository.schemaVersion
            )
            try checkCancellation(cancellation)
            try database.close()
            let fileSize = try resourceFileSize(temporaryBackup)
            guard fileSize <= Self.maximumBackupBytes else {
                throw PortabilityError.backupTooLarge
            }
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
            throw mapped(error, fallback: .backupFailed)
        }
    }

    func inspect(
        _ backupURL: URL,
        cancellation: RestoreCancellation = .never
    ) throws -> BackupPreview {
        try checkCancellation(cancellation)
        try validateFile(backupURL)
        let database: SQLiteDatabase
        do {
            database = try SQLiteDatabase(path: backupURL.path, readOnly: true)
        } catch {
            throw PortabilityError.corruptDatabase
        }
        defer { try? database.close() }
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
        try checkCancellation(cancellation)
        let validation = try schemaValidator.validate(
            database: database,
            expectedVersion: rows[0].1
        )
        try checkCancellation(cancellation)
        return BackupPreview(
            formatVersion: rows[0].0,
            schemaVersion: rows[0].1,
            applicationVersion: appVersion,
            createdAt: createdAt,
            bookCount: validation.bookCount
        )
    }

    func restore(
        backupURL: URL,
        databaseURL: URL,
        repository: inout BookRepository,
        recoveryDirectory: URL,
        cancellation: RestoreCancellation = .never,
        progress: @escaping @Sendable (RestoreProgressPhase) -> Void = { _ in }
    ) throws -> BackupPreview {
        progress(.inspecting)
        let preview = try inspect(backupURL, cancellation: cancellation)
        try checkCancellation(cancellation)
        let backupBytes = try resourceFileSize(backupURL)
        let liveBytes = try repository.storageBytes()
        try requireCapacity(
            at: databaseURL.deletingLastPathComponent(),
            bytes: backupBytes * 2 + liveBytes + Self.diskSafetyReserveBytes
        )
        try requireCapacity(
            at: recoveryDirectory.deletingLastPathComponent(),
            bytes: liveBytes + Self.diskSafetyReserveBytes
        )

        progress(.creatingRecoveryCopy)
        try fileManager.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
        let recoveryURL = recoveryDirectory.appendingPathComponent(
            "BookAtlas-before-restore-\(UUID().uuidString).\(Self.backupExtension)"
        )
        _ = try backup(
            repository: repository,
            to: recoveryURL,
            cancellation: cancellation,
            operation: .recoverySnapshot
        )
        _ = try inspect(recoveryURL, cancellation: cancellation)
        try checkCancellation(cancellation)
        try injected(.afterRecoveryCopy)

        let token = UUID()
        let directory = databaseURL.deletingLastPathComponent()
        let newURL = directory.appendingPathComponent(
            ".book-atlas-restore-new-\(token.uuidString).sqlite"
        )
        let oldURL = directory.appendingPathComponent(
            ".book-atlas-restore-old-\(token.uuidString).sqlite"
        )
        let stateURL = directory.appendingPathComponent(Self.restoreStateFilename)
        guard !fileManager.fileExists(atPath: stateURL.path) else {
            throw PortabilityError.recoveryRequired
        }
        var stateWritten = false
        var processTerminated = false
        var connectionClosed = false
        defer {
            if !processTerminated {
                removeSQLiteFiles(at: newURL, fileManager: fileManager)
                if !stateWritten { try? fileManager.removeItem(at: stateURL) }
            }
        }

        do {
            progress(.staging)
            try checkCancellation(cancellation)
            if let error = injectedSystemError(.stageRestore) { throw error }
            let source = try SQLiteDatabase(path: backupURL.path, readOnly: true)
            defer { try? source.close() }
            try source.onlineBackup(to: newURL.path) {
                try self.checkCancellation(cancellation)
            }
            try source.close()
            try checkCancellation(cancellation)

            progress(.migrating)
            let staged = try SQLiteDatabase(path: newURL.path)
            defer { try? staged.close() }
            try staged.execute("DROP TABLE \(Self.manifestTable)")
            try checkCancellation(cancellation)
            _ = try DatabaseMigrator().migrate(staged)
            try checkCancellation(cancellation)
            _ = try schemaValidator.validate(
                database: staged,
                expectedVersion: BookAtlasSchema.latestVersion
            )
            _ = try staged.query("PRAGMA journal_mode = DELETE") { $0.string(at: 0) }
            try staged.close()
            try requireCapacity(
                at: directory,
                bytes: try resourceFileSize(newURL) + liveBytes + Self.diskSafetyReserveBytes
            )
            try checkCancellation(cancellation)

            progress(.safeReplacement)
            try repository.checkpointWAL()
            let state = RestoreState(
                formatVersion: 1,
                token: token,
                oldFilename: oldURL.lastPathComponent,
                newFilename: newURL.lastPathComponent,
                schemaVersion: BookAtlasSchema.latestVersion
            )
            try writeRestoreState(state, to: stateURL)
            stateWritten = true
            try repository.close()
            connectionClosed = true
            removeSQLiteSidecars(at: databaseURL)
            try injected(.afterConnectionClose)
            if fileManager.fileExists(atPath: databaseURL.path) {
                try fileManager.moveItem(at: databaseURL, to: oldURL)
            }
            try injected(.afterOriginalPreparedForReplacement)
            if let error = injectedSystemError(.installReplacement) { throw error }
            try fileManager.moveItem(at: newURL, to: databaseURL)
            try injected(.afterReplacement)
            _ = try schemaValidator.validateFile(
                databaseURL,
                expectedVersion: BookAtlasSchema.latestVersion
            )
            progress(.reconnecting)
            try injected(.beforeReconnect)
            repository = try BookRepository(databaseURL: databaseURL)
            connectionClosed = false
            try cleanupRestoreState(
                stateURL: stateURL,
                oldURL: oldURL,
                newURL: newURL
            )
            return preview
        } catch is SimulatedRestoreTermination {
            processTerminated = true
            throw PortabilityError.restoreInterrupted
        } catch {
            if stateWritten {
                do {
                    try rollbackToOldLibrary(
                        databaseURL: databaseURL,
                        oldURL: oldURL,
                        newURL: newURL,
                        stateURL: stateURL
                    )
                } catch {
                    throw PortabilityError.recoveryRequired
                }
            }
            if connectionClosed || stateWritten {
                do {
                    try injected(.beforeRollbackReconnect)
                    repository = try BookRepository(databaseURL: databaseURL)
                } catch {
                    throw PortabilityError.reconnectFailed
                }
            }
            throw mapped(error, fallback: .restoreFailed)
        }
    }

    func recoverInterruptedRestore(databaseURL: URL) throws {
        let directory = databaseURL.deletingLastPathComponent()
        let stateURL = directory.appendingPathComponent(Self.restoreStateFilename)
        guard fileManager.fileExists(atPath: stateURL.path) else { return }
        let state: RestoreState
        do {
            state = try JSONDecoder().decode(
                RestoreState.self,
                from: Data(contentsOf: stateURL)
            )
        } catch {
            throw PortabilityError.recoveryRequired
        }
        guard state.formatVersion == 1,
              state.schemaVersion == BookAtlasSchema.latestVersion,
              Self.safeRelativeFilename(state.oldFilename),
              Self.safeRelativeFilename(state.newFilename)
        else { throw PortabilityError.recoveryRequired }

        let oldURL = directory.appendingPathComponent(state.oldFilename)
        let newURL = directory.appendingPathComponent(state.newFilename)
        removeSQLiteSidecars(at: databaseURL)
        if isValidLibrary(databaseURL, version: state.schemaVersion) {
            try cleanupRestoreState(stateURL: stateURL, oldURL: oldURL, newURL: newURL)
            return
        }
        if isValidLibrary(oldURL, version: state.schemaVersion) {
            removeSQLiteFiles(at: databaseURL, fileManager: fileManager)
            try fileManager.moveItem(at: oldURL, to: databaseURL)
        } else if isValidLibrary(newURL, version: state.schemaVersion) {
            removeSQLiteFiles(at: databaseURL, fileManager: fileManager)
            try fileManager.moveItem(at: newURL, to: databaseURL)
        } else {
            throw PortabilityError.recoveryRequired
        }
        _ = try schemaValidator.validateFile(
            databaseURL,
            expectedVersion: state.schemaVersion
        )
        try cleanupRestoreState(stateURL: stateURL, oldURL: oldURL, newURL: newURL)
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
        let size = Int64(values.fileSize ?? 0)
        guard size <= Self.maximumBackupBytes else { throw PortabilityError.backupTooLarge }
        guard size >= 16 else { throw PortabilityError.corruptDatabase }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let magic = try handle.read(upToCount: 16) ?? Data()
        guard magic == Data("SQLite format 3\u{0}".utf8) else {
            throw PortabilityError.corruptDatabase
        }
    }

    private func checkCancellation(_ cancellation: RestoreCancellation) throws {
        if cancellation.isCancelled() { throw PortabilityError.cancelled }
    }

    private func injected(_ point: RestoreInjectionPoint) throws {
        if simulatedTerminationPoint == point { throw SimulatedRestoreTermination() }
        try injectFailure(point)
    }

    private func requireCapacity(at directory: URL, bytes: Int64) throws {
        guard let capacity = availableCapacity(directory) else { return }
        guard capacity >= max(0, bytes) else {
            throw PortabilityError.insufficientDiskSpace
        }
    }

    private func resourceFileSize(_ url: URL) throws -> Int64 {
        Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
    }

    private func mapped(
        _ error: Error,
        fallback: PortabilityError
    ) -> PortabilityError {
        if let portability = error as? PortabilityError { return portability }
        let nsError = error as NSError
        if (nsError.domain == NSCocoaErrorDomain
            && nsError.code == CocoaError.Code.fileWriteOutOfSpace.rawValue)
            || (nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(ENOSPC))
        {
            return .insufficientDiskSpace
        }
        switch error {
        case SQLiteDatabaseError.executionFailed(SQLITE_FULL),
             SQLiteDatabaseError.backupFailed(SQLITE_FULL),
             SQLiteDatabaseError.openFailed(SQLITE_FULL):
            return .insufficientDiskSpace
        default:
            return fallback
        }
    }

    private func writeRestoreState(_ state: RestoreState, to stateURL: URL) throws {
        let temporary = stateURL.deletingLastPathComponent().appendingPathComponent(
            ".book-atlas-restore-state-\(state.token.uuidString).tmp"
        )
        defer { try? fileManager.removeItem(at: temporary) }
        let data = try JSONEncoder().encode(state)
        guard fileManager.createFile(atPath: temporary.path, contents: data) else {
            throw PortabilityError.replacementFailed
        }
        let handle = try FileHandle(forWritingTo: temporary)
        try handle.synchronize()
        try handle.close()
        try fileManager.moveItem(at: temporary, to: stateURL)
    }

    private func rollbackToOldLibrary(
        databaseURL: URL,
        oldURL: URL,
        newURL: URL,
        stateURL: URL
    ) throws {
        if isValidLibrary(oldURL, version: BookAtlasSchema.latestVersion) {
            removeSQLiteFiles(at: databaseURL, fileManager: fileManager)
            try fileManager.moveItem(at: oldURL, to: databaseURL)
        } else if !isValidLibrary(databaseURL, version: BookAtlasSchema.latestVersion) {
            throw PortabilityError.recoveryRequired
        }
        _ = try schemaValidator.validateFile(
            databaseURL,
            expectedVersion: BookAtlasSchema.latestVersion
        )
        try cleanupRestoreState(stateURL: stateURL, oldURL: oldURL, newURL: newURL)
    }

    private func cleanupRestoreState(
        stateURL: URL,
        oldURL: URL,
        newURL: URL
    ) throws {
        removeSQLiteFiles(at: oldURL, fileManager: fileManager)
        removeSQLiteFiles(at: newURL, fileManager: fileManager)
        if fileManager.fileExists(atPath: stateURL.path) {
            try fileManager.removeItem(at: stateURL)
        }
    }

    private func isValidLibrary(_ url: URL, version: Int) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return false }
        return (try? schemaValidator.validateFile(url, expectedVersion: version)) != nil
    }

    private func removeSQLiteSidecars(at url: URL) {
        try? fileManager.removeItem(atPath: url.path + "-wal")
        try? fileManager.removeItem(atPath: url.path + "-shm")
    }

    private static func safeRelativeFilename(_ value: String) -> Bool {
        !value.isEmpty
            && !value.contains("/")
            && !value.contains("\\")
            && value != "."
            && value != ".."
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

private func removeSQLiteFiles(at url: URL, fileManager: FileManager) {
    try? fileManager.removeItem(at: url)
    try? fileManager.removeItem(atPath: url.path + "-wal")
    try? fileManager.removeItem(atPath: url.path + "-shm")
}
