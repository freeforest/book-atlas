import XCTest
@testable import BookAtlas

final class PortabilityCSVTests: XCTestCase {
    func testParserSupportsBOMQuotesCommasEmbeddedNewlinesAndColumnOrder() throws {
        let csv = Data([0xEF, 0xBB, 0xBF]) + Data(
            """
            author,title,format_version,note
            "林,雾","《潮汐""档案》",bookatlas-csv/1,"第一行
            第二行"
            """.utf8
        )
        let document = try StreamingCSVParser().parse(data: csv)

        XCTAssertTrue(document.hadByteOrderMark)
        XCTAssertEqual(document.headers, ["author", "title", "format_version", "note"])
        XCTAssertEqual(document.records.count, 1)
        XCTAssertEqual(document.records[0].values[0], "林,雾")
        XCTAssertEqual(document.records[0].values[1], "《潮汐\"档案》")
        XCTAssertEqual(document.records[0].values[3], "第一行\n第二行")
    }

    func testParserRejectsEmptyInvalidUTF8MalformedAndLimits() throws {
        XCTAssertThrowsError(try StreamingCSVParser().parse(data: Data())) {
            XCTAssertEqual($0 as? CSVParserError, .emptyFile)
        }
        XCTAssertThrowsError(
            try StreamingCSVParser().parse(data: Data([0x74, 0x69, 0x74, 0x6C, 0x65, 0x0A, 0xFF]))
        ) {
            XCTAssertEqual($0 as? CSVParserError, .invalidUTF8(line: 2))
        }
        XCTAssertThrowsError(
            try StreamingCSVParser().parse(data: Data("title\n\"broken".utf8))
        ) {
            XCTAssertEqual($0 as? CSVParserError, .malformedRow(line: 2))
        }
        let limits = CSVParserLimits(
            maximumFileBytes: 100,
            maximumRows: 2,
            maximumFieldBytes: 3,
            maximumColumns: 2,
            previewRows: 1
        )
        XCTAssertThrowsError(
            try StreamingCSVParser(limits: limits).parse(data: Data("t\nlong".utf8))
        ) {
            XCTAssertEqual($0 as? CSVParserError, .fieldTooLarge(line: 2))
        }
        XCTAssertThrowsError(
            try StreamingCSVParser(limits: limits).parse(data: Data("a,b,c\n1,2,3".utf8))
        ) {
            XCTAssertEqual($0 as? CSVParserError, .tooManyColumns(line: 1))
        }
        XCTAssertThrowsError(
            try StreamingCSVParser(limits: limits).parse(data: Data(repeating: 0x61, count: 101))
        ) {
            XCTAssertEqual($0 as? CSVParserError, .fileTooLarge)
        }
        XCTAssertThrowsError(
            try StreamingCSVParser(limits: limits).parse(data: Data("h\n1\n2\n3\n".utf8))
        ) {
            XCTAssertEqual($0 as? CSVParserError, .tooManyRows)
        }
    }

    func testPreviewMapsFieldsCountsIssuesAndNeverWrites() throws {
        let repository = try BookRepository.inMemory()
        _ = try repository.create(BookDraft(title: "《雾港》", author: "林雾"))
        let csv = """
        writer,name,version,labels,lists,origins,status,unknown
        林雾,雾港,bookatlas-csv/1,潮汐|潮汐,北岸,纸页,reading,ignored
        ,缺少作者,bookatlas-csv/1,新标签,,,wish_to_read,ignored
        周栩,新生岛,bookatlas-csv/1,新标签,新书单,新来源,read,ignored
        """
        let document = try StreamingCSVParser().parse(data: Data(csv.utf8))
        let mapping = CSVFieldMapping(columns: [
            .formatVersion: "version",
            .title: "name",
            .author: "writer",
            .tags: "labels",
            .collections: "lists",
            .sources: "origins",
            .readingStatus: "status"
        ])

        let preview = try LibraryImportCoordinator().preview(
            document: document,
            mapping: mapping,
            repository: repository
        )

        XCTAssertEqual(preview.totalRows, 3)
        XCTAssertEqual(preview.importableRows, 1)
        XCTAssertEqual(preview.errorRows, 1)
        XCTAssertEqual(preview.warningRows, 1)
        XCTAssertEqual(preview.potentialDuplicateRows, 1)
        XCTAssertEqual(preview.newTagCount, 1)
        XCTAssertEqual(preview.newCollectionCount, 1)
        XCTAssertEqual(preview.newSourceCount, 1)
        XCTAssertEqual(try repository.allBooks().count, 1, "Preview must not write")
    }

    func testPreviewLimitIsExplicitWithoutDroppingPreparedRows() throws {
        let repository = try BookRepository.inMemory()
        var csv = "format_version,title,author\n"
        for index in 0 ..< 21 {
            csv += "bookatlas-csv/1,Unique\(index),Author\(index)\n"
        }
        let document = try StreamingCSVParser().parse(data: Data(csv.utf8))
        let preview = try LibraryImportCoordinator().preview(
            document: document,
            mapping: .inferred(from: document.headers),
            repository: repository
        )
        XCTAssertTrue(preview.wasTruncated)
        XCTAssertEqual(preview.sampleRows.count, 20)
        XCTAssertEqual(preview.preparedRows.count, 21)
        XCTAssertTrue(try repository.allBooks().isEmpty)
    }

    func testImportSkipsDuplicatesCreatesAndDeduplicatesAssociations() throws {
        let repository = try BookRepository.inMemory()
        _ = try repository.create(BookDraft(title: "《已有灯塔》", author: "沈遥"))
        let csv = """
        format_version,title,author,tags,collections,sources
        bookatlas-csv/1,已有灯塔,沈遥,海岸,清单,纸刊
        bookatlas-csv/1,新生港湾,周栩,海岸|海岸,清单|清单,纸刊|纸刊
        bookatlas-csv/1,新生港湾,周栩,海岸,清单,纸刊
        """
        let coordinator = LibraryImportCoordinator()
        let document = try StreamingCSVParser().parse(data: Data(csv.utf8))
        let preview = try coordinator.preview(
            document: document,
            mapping: .inferred(from: document.headers),
            repository: repository
        )
        let result = try coordinator.execute(preview: preview, repository: repository)

        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 2)
        XCTAssertEqual(result.duplicateRows, 2)
        XCTAssertEqual(try repository.allBooks().count, 2)
        XCTAssertEqual(try repository.tagSummaries().count, 1)
        XCTAssertEqual(try repository.collectionSummaries().count, 1)
        XCTAssertEqual(try repository.sourceSummaries().count, 1)
        let imported = try XCTUnwrap(repository.allBooks().first { $0.title == "新生港湾" })
        XCTAssertEqual(try repository.tags(forBookID: imported.id).count, 1)
        XCTAssertEqual(try repository.collections(forBookID: imported.id).count, 1)
        XCTAssertEqual(try repository.sources(forBookID: imported.id).count, 1)
    }

    func testFatalInterruptionRollsBackEveryImportedRow() throws {
        enum Injected: Error { case stop }
        let repository = try BookRepository.inMemory()
        let csv = """
        format_version,title,author
        bookatlas-csv/1,虚构甲,作者甲
        bookatlas-csv/1,虚构乙,作者乙
        """
        let coordinator = LibraryImportCoordinator()
        let document = try StreamingCSVParser().parse(data: Data(csv.utf8))
        let preview = try coordinator.preview(
            document: document,
            mapping: .inferred(from: document.headers),
            repository: repository
        )

        XCTAssertThrowsError(
            try coordinator.execute(
                preview: preview,
                repository: repository,
                afterRow: { _ in throw Injected.stop }
            )
        )
        XCTAssertEqual(try repository.allBooks().count, 0)
        XCTAssertEqual(try repository.tagSummaries().count, 0)
    }

    func testCancellationRollsBackWithoutWriting() throws {
        let repository = try BookRepository.inMemory()
        let csv = "format_version,title,author\nbookatlas-csv/1,虚构甲,作者甲\n"
        let coordinator = LibraryImportCoordinator()
        let document = try StreamingCSVParser().parse(data: Data(csv.utf8))
        let preview = try coordinator.preview(
            document: document,
            mapping: .inferred(from: document.headers),
            repository: repository
        )
        XCTAssertThrowsError(
            try coordinator.execute(
                preview: preview,
                repository: repository,
                cancellation: ImportCancellation(isCancelled: { true })
            )
        ) {
            XCTAssertEqual($0 as? PortabilityError, .cancelled)
        }
        XCTAssertTrue(try repository.allBooks().isEmpty)
    }

    func testFormulaSafetyCoversAllPrefixesAndPreservesLeadingApostrophe() throws {
        for value in ["=SUM(1,1)", "+1", "-1", "@cmd", "\tcell", "\rcell", "'literal"] {
            let encoded = CSVFormulaSafety.encode(value)
            XCTAssertTrue(encoded.hasPrefix("'"))
            XCTAssertEqual(CSVFormulaSafety.decode(encoded), value)
        }
    }

    func testCSVExportRoundTripsTextAndUsesStableColumns() throws {
        let book = try Book(
            draft: BookDraft(
                title: "=虚构,书名",
                originalTitle: "\"Quoted\"",
                author: "林雾",
                note: "第一行\n第二行"
            ),
            createdAt: FictionalLibraryFixtures.timestamp
        )
        let data = LibraryCSVExporter.data(records: [
            ExportBookRecord(book: book, tags: ["潮|汐"], collections: ["北岸"], sources: ["纸页"])
        ])
        let document = try StreamingCSVParser().parse(data: data)
        XCTAssertEqual(document.headers, PortabilityFormat.csvColumns)
        XCTAssertEqual(document.records[0].values[1], "=虚构,书名")
        XCTAssertEqual(document.records[0].values[2], "\"Quoted\"")
        XCTAssertEqual(document.records[0].values[10], "第一行\n第二行")
        XCTAssertEqual(DelimitedValueCodec.decode(document.records[0].values[13]), ["潮|汐"])
    }

    func testMarkdownEscapesSyntaxAndExcludesAbsolutePaths() throws {
        let book = try Book(
            draft: BookDraft(
                title: "*虚构* [书]",
                author: "林_雾",
                note: "私有位置 /Users/example/Secret/file.txt 和 /opt/private/file.txt\n下一行"
            )
        )
        let data = LibraryMarkdownExporter.data(
            records: [ExportBookRecord(book: book, tags: [], collections: [], sources: [])],
            exportedAt: FictionalLibraryFixtures.timestamp
        )
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains(#"\*虚构\* \[书\]"#))
        XCTAssertTrue(text.contains("格式版本：bookatlas-markdown/1"))
        XCTAssertTrue(text.contains("本地路径已省略"))
        XCTAssertFalse(text.contains("/Users/"))
        XCTAssertFalse(text.contains("/opt/"))
    }

    func testErrorReportContainsOnlyStructuredRedactedIssueData() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("errors.csv")
        let issue = ImportIssue(
            lineNumber: 7,
            field: "title",
            code: "required",
            description: "必填字段缺失。",
            severity: .error,
            retryable: true
        )
        try LibraryExportCoordinator().exportErrorReport([issue], to: output)
        let text = try String(contentsOf: output, encoding: .utf8)
        XCTAssertTrue(text.contains("7,title,required"))
        XCTAssertFalse(text.contains("原始私密内容"))
        XCTAssertThrowsError(
            try LibraryExportCoordinator().exportErrorReport([issue], to: output)
        ) {
            XCTAssertEqual($0 as? PortabilityError, .destinationExists)
        }
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "BookAtlas-PortabilityTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
