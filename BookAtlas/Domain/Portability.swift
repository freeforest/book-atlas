import Foundation

enum PortabilityFormat {
    static let csvVersion = "bookatlas-csv/1"
    static let markdownVersion = "bookatlas-markdown/1"
    static let backupVersion = 1
    static let csvColumns = [
        "format_version", "title", "original_title", "author", "isbn", "publisher",
        "publication_date", "kind", "reading_status", "priority", "note",
        "started_at", "finished_at", "tags", "collections", "sources"
    ]
}

enum ImportField: String, CaseIterable, Identifiable, Sendable {
    case formatVersion = "format_version"
    case title
    case originalTitle = "original_title"
    case author
    case isbn
    case publisher
    case publicationDate = "publication_date"
    case kind
    case readingStatus = "reading_status"
    case priority
    case note
    case startedAt = "started_at"
    case finishedAt = "finished_at"
    case tags
    case collections
    case sources

    var id: String { rawValue }
    var isRequired: Bool { self == .title || self == .author }
}

struct CSVFieldMapping: Equatable, Sendable {
    var columns: [ImportField: String]

    static func inferred(from headers: [String]) -> CSVFieldMapping {
        let normalized = Dictionary(
            headers.map { ($0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var columns: [ImportField: String] = [:]
        for field in ImportField.allCases {
            if let header = normalized[field.rawValue] {
                columns[field] = header
            }
        }
        return CSVFieldMapping(columns: columns)
    }
}

struct CSVParserLimits: Equatable, Sendable {
    var maximumFileBytes = 100 * 1_024 * 1_024
    var maximumRows = 100_000
    var maximumFieldBytes = 1 * 1_024 * 1_024
    var maximumColumns = 128
    var previewRows = 20
}

enum CSVParserError: Error, Equatable {
    case notRegularFile
    case symbolicLink
    case emptyFile
    case fileTooLarge
    case invalidUTF8(line: Int)
    case malformedRow(line: Int)
    case fieldTooLarge(line: Int)
    case tooManyColumns(line: Int)
    case tooManyRows
    case missingHeader
}

struct CSVRecord: Equatable, Sendable {
    let lineNumber: Int
    let values: [String]
}

struct CSVDocument: Equatable, Sendable {
    let headers: [String]
    let records: [CSVRecord]
    let hadByteOrderMark: Bool
    let wasTruncated: Bool
}

final class StreamingCSVParser {
    private let limits: CSVParserLimits
    private let fileManager: FileManager

    init(limits: CSVParserLimits = CSVParserLimits(), fileManager: FileManager = .default) {
        self.limits = limits
        self.fileManager = fileManager
    }

    func parse(url: URL) throws -> CSVDocument {
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey
        ])
        guard values.isSymbolicLink != true else { throw CSVParserError.symbolicLink }
        guard values.isRegularFile == true else { throw CSVParserError.notRegularFile }
        guard (values.fileSize ?? 0) <= limits.maximumFileBytes else {
            throw CSVParserError.fileTooLarge
        }
        guard let stream = InputStream(url: url) else { throw CSVParserError.notRegularFile }
        return try parse(stream: stream)
    }

    func parse(data: Data) throws -> CSVDocument {
        guard data.count <= limits.maximumFileBytes else { throw CSVParserError.fileTooLarge }
        return try parse(stream: InputStream(data: data))
    }

    private func parse(stream: InputStream) throws -> CSVDocument {
        stream.open()
        defer { stream.close() }

        var rows: [CSVRecord] = []
        var row: [String] = []
        var field = Data()
        var quoted = false
        var quoteWasClosed = false
        var physicalLine = 1
        var recordStartLine = 1
        var pendingCR = false
        var prefix = Data()
        var hadBOM = false
        var sawAnyByte = false

        func decodedField() throws -> String {
            guard field.count <= limits.maximumFieldBytes else {
                throw CSVParserError.fieldTooLarge(line: recordStartLine)
            }
            guard let value = String(data: field, encoding: .utf8) else {
                throw CSVParserError.invalidUTF8(line: recordStartLine)
            }
            return CSVFormulaSafety.decode(value)
        }

        func finishField() throws {
            row.append(try decodedField())
            field.removeAll(keepingCapacity: true)
            quoteWasClosed = false
            if row.count > limits.maximumColumns {
                throw CSVParserError.tooManyColumns(line: recordStartLine)
            }
        }

        func finishRow() throws {
            try finishField()
            if !(row.count == 1 && row[0].isEmpty && rows.isEmpty) {
                rows.append(CSVRecord(lineNumber: recordStartLine, values: row))
            }
            row.removeAll(keepingCapacity: true)
            if rows.count > limits.maximumRows + 1 {
                throw CSVParserError.tooManyRows
            }
            recordStartLine = physicalLine
        }

        func consume(_ byte: UInt8) throws {
            sawAnyByte = true
            if quoted {
                if byte == 0x22 {
                    quoted = false
                    quoteWasClosed = true
                } else {
                    field.append(byte)
                    if byte == 0x0A { physicalLine += 1 }
                }
                return
            }

            if quoteWasClosed {
                if byte == 0x22 {
                    quoted = true
                    quoteWasClosed = false
                    field.append(0x22)
                    return
                }
                guard byte == 0x2C || byte == 0x0A || byte == 0x0D else {
                    throw CSVParserError.malformedRow(line: recordStartLine)
                }
            } else if byte == 0x22 {
                guard field.isEmpty else { throw CSVParserError.malformedRow(line: recordStartLine) }
                quoted = true
                return
            }

            switch byte {
            case 0x2C:
                try finishField()
            case 0x0D:
                try finishRow()
                physicalLine += 1
                pendingCR = true
            case 0x0A:
                if pendingCR {
                    pendingCR = false
                    recordStartLine = physicalLine
                } else {
                    try finishRow()
                    physicalLine += 1
                    recordStartLine = physicalLine
                }
            default:
                pendingCR = false
                field.append(byte)
                if field.count > limits.maximumFieldBytes {
                    throw CSVParserError.fieldTooLarge(line: recordStartLine)
                }
            }
        }

        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 { throw stream.streamError ?? CSVParserError.notRegularFile }
            if count == 0 { break }
            for byte in buffer.prefix(count) {
                if prefix.count < 3 {
                    prefix.append(byte)
                    if prefix.count == 3 {
                        if prefix == Data([0xEF, 0xBB, 0xBF]) {
                            hadBOM = true
                        } else {
                            for prefixedByte in prefix { try consume(prefixedByte) }
                        }
                    }
                } else {
                    try consume(byte)
                }
            }
        }

        if prefix.count < 3 {
            for byte in prefix { try consume(byte) }
        }
        guard sawAnyByte || hadBOM else { throw CSVParserError.emptyFile }
        guard !quoted else { throw CSVParserError.malformedRow(line: recordStartLine) }
        if !field.isEmpty || !row.isEmpty || quoteWasClosed {
            try finishRow()
        }
        guard let header = rows.first, !header.values.allSatisfy(\.isEmpty) else {
            throw CSVParserError.missingHeader
        }
        let records = Array(rows.dropFirst())
        return CSVDocument(
            headers: header.values,
            records: records,
            hadByteOrderMark: hadBOM,
            wasTruncated: false
        )
    }
}

enum ImportIssueSeverity: String, Sendable {
    case warning
    case error
}

struct ImportIssue: Equatable, Sendable {
    let lineNumber: Int
    let field: String
    let code: String
    let description: String
    let severity: ImportIssueSeverity
    let retryable: Bool
}

struct PreparedImportRow: Equatable, Sendable {
    let lineNumber: Int
    let draft: BookDraft
    let tags: [String]
    let collections: [String]
    let sources: [String]
    let issues: [ImportIssue]
    let duplicateCandidates: [DuplicateCandidate]
}

struct ImportPreview: Equatable, Sendable {
    let totalRows: Int
    let importableRows: Int
    let warningRows: Int
    let errorRows: Int
    let potentialDuplicateRows: Int
    let newTagCount: Int
    let newCollectionCount: Int
    let newSourceCount: Int
    let sampleRows: [PreparedImportRow]
    let mapping: CSVFieldMapping
    let availableHeaders: [String]
    let wasTruncated: Bool
    let preparedRows: [PreparedImportRow]
    let issues: [ImportIssue]
}

enum ImportDuplicatePolicy: String, CaseIterable, Sendable {
    case skipAndReview = "skip_and_review"
}

struct ImportResult: Equatable, Sendable {
    let imported: Int
    let skipped: Int
    let warnings: Int
    let failed: Int
    let duplicateRows: Int
}

struct ExportBookRecord: Equatable, Sendable {
    let book: Book
    let tags: [String]
    let collections: [String]
    let sources: [String]
}

struct BackupPreview: Equatable, Sendable {
    let formatVersion: Int
    let schemaVersion: Int
    let applicationVersion: String
    let createdAt: Date
    let bookCount: Int
}

struct BackupResult: Equatable, Sendable {
    let destination: URL
    let preview: BackupPreview
}

enum PortabilityError: Error, Equatable {
    case unsupportedCSVVersion
    case missingRequiredMapping(ImportField)
    case invalidValue(line: Int, field: ImportField)
    case cancelled
    case destinationExists
    case invalidDestination
    case unsafeFile
    case unsupportedBackupFormat(Int)
    case unsupportedSchemaVersion(Int)
    case invalidManifest
    case corruptDatabase
    case backupFailed
    case insufficientDiskSpace
    case replacementFailed
    case restoreInterrupted
    case restoreFailed
    case reconnectFailed
}

enum CSVFormulaSafety {
    static let dangerousPrefixes: Set<Character> = ["=", "+", "-", "@", "\t", "\r"]

    static func encode(_ value: String) -> String {
        guard let first = value.first else { return value }
        if first == "'" { return "'" + value }
        if dangerousPrefixes.contains(first) { return "'" + value }
        return value
    }

    static func decode(_ value: String) -> String {
        guard value.first == "'" else { return value }
        let remainder = String(value.dropFirst())
        if remainder.first == "'" || remainder.first.map(dangerousPrefixes.contains) == true {
            return remainder
        }
        return value
    }
}

enum DelimitedValueCodec {
    static func encode(_ values: [String]) -> String {
        values.map {
            $0.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "|", with: "\\|")
        }.joined(separator: "|")
    }

    static func decode(_ value: String) -> [String] {
        guard !value.isEmpty else { return [] }
        var result: [String] = []
        var current = ""
        var escaped = false
        for character in value {
            if escaped {
                current.append(character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "|" {
                result.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        if escaped { current.append("\\") }
        result.append(current)
        return result
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

enum CSVEncoder {
    static func row(_ values: [String], formulaSafe: Bool = true) -> String {
        values.map { value in
            let safe = formulaSafe ? CSVFormulaSafety.encode(value) : value
            if safe.contains(",") || safe.contains("\"") || safe.contains("\n") || safe.contains("\r") {
                return "\"\(safe.replacingOccurrences(of: "\"", with: "\"\""))\""
            }
            return safe
        }.joined(separator: ",") + "\r\n"
    }
}

enum PortabilityDateCodec {
    static func encode(_ date: Date?) -> String {
        date.map(StorageDateCodec.encode) ?? ""
    }

    static func decode(_ value: String) -> Date? {
        value.isEmpty ? nil : StorageDateCodec.decode(value)
    }
}

enum LibraryCSVExporter {
    static func data(records: [ExportBookRecord]) -> Data {
        var output = CSVEncoder.row(PortabilityFormat.csvColumns, formulaSafe: false)
        for record in records {
            let book = record.book
            output += CSVEncoder.row([
                PortabilityFormat.csvVersion,
                book.title,
                book.originalTitle ?? "",
                book.author,
                book.isbn ?? "",
                book.publisher ?? "",
                book.publicationDate?.storageValue ?? "",
                book.kind.rawValue,
                book.readingStatus.rawValue,
                book.priority.map { String($0.rawValue) } ?? "",
                book.note ?? "",
                PortabilityDateCodec.encode(book.startedAt),
                PortabilityDateCodec.encode(book.finishedAt),
                DelimitedValueCodec.encode(record.tags),
                DelimitedValueCodec.encode(record.collections),
                DelimitedValueCodec.encode(record.sources)
            ])
        }
        return Data(output.utf8)
    }
}

enum MarkdownSafety {
    static func escaped(_ value: String) -> String {
        let redacted = value
            .replacingOccurrences(
                of: #"(?i)(?:file://|/Users/|/Volumes/)[^\s)\]]+|(?<![:\w])/(?:[^/\s]+/)+[^\s)\]]*"#,
                with: "[本地路径已省略]",
                options: .regularExpression
            )
        return redacted
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "*", with: "\\*")
            .replacingOccurrences(of: "_", with: "\\_")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "<br>")
    }
}

enum LibraryMarkdownExporter {
    static func data(records: [ExportBookRecord], exportedAt: Date) -> Data {
        var lines = [
            "# Book Atlas 导出",
            "",
            "- 格式版本：\(PortabilityFormat.markdownVersion)",
            "- 导出时间：\(StorageDateCodec.encode(exportedAt))",
            ""
        ]
        for record in records {
            let book = record.book
            lines.append("## \(MarkdownSafety.escaped(book.title))")
            lines.append("")
            lines.append("- 作者：\(MarkdownSafety.escaped(book.author))")
            lines.append("- 原书名：\(MarkdownSafety.escaped(book.originalTitle ?? ""))")
            lines.append("- ISBN：\(MarkdownSafety.escaped(book.isbn ?? ""))")
            lines.append("- 出版社：\(MarkdownSafety.escaped(book.publisher ?? ""))")
            lines.append("- 出版日期：\(book.publicationDate?.storageValue ?? "")")
            lines.append("- 类型：\(book.kind.rawValue)")
            lines.append("- 阅读状态：\(book.readingStatus.rawValue)")
            lines.append("- 优先级：\(book.priority.map { String($0.rawValue) } ?? "")")
            lines.append("- 开始时间：\(PortabilityDateCodec.encode(book.startedAt))")
            lines.append("- 完成时间：\(PortabilityDateCodec.encode(book.finishedAt))")
            lines.append("- 标签：\(MarkdownSafety.escaped(record.tags.joined(separator: "、")))")
            lines.append("- 书单：\(MarkdownSafety.escaped(record.collections.joined(separator: "、")))")
            lines.append("- 来源：\(MarkdownSafety.escaped(record.sources.joined(separator: "、")))")
            lines.append("")
            lines.append("备注：\(MarkdownSafety.escaped(book.note ?? ""))")
            lines.append("")
        }
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }
}
