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
        XCTAssertEqual(
            preview.sampleRows[0].duplicateMatches.first?.scope,
            .existingLibrary
        )
        XCTAssertTrue(
            preview.sampleRows[0].issues.contains { $0.code == "duplicate_existing_library" }
        )
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
        XCTAssertEqual(preview.staging.rowCount, 21)
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

    func testPreviewDetectsExactAndStrongDuplicatesWithinCurrentBatchInDeterministicOrder() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try BookRepository.inMemory()
        let csvURL = directory.appendingPathComponent("batch-duplicates.csv")
        try Data(
            """
            format_version,title,author,isbn,tags,collections,sources
            bookatlas-csv/1,《ISBN 基准》,虚构甲,978-0-306-40615-7,保留标签,保留书单,保留来源
            bookatlas-csv/1,《ISBN 变化标题》,虚构乙,9780306406157,跳过标签,跳过书单,跳过来源
            bookatlas-csv/1,《强匹配港湾》,虚构丙,,第二标签,第二书单,第二来源
            bookatlas-csv/1,强匹配港湾,虚构丙,,另一个跳过标签,另一个跳过书单,另一个跳过来源
            bookatlas-csv/1,《完全不同》,虚构丁,,第三标签,第三书单,第三来源
            """.utf8
        ).write(to: csvURL)
        let coordinator = LibraryImportCoordinator()
        let preview = try coordinator.prepare(
            url: csvURL,
            mapping: nil,
            repository: repository
        )

        XCTAssertEqual(preview.totalRows, 5)
        XCTAssertEqual(preview.importableRows, 3)
        XCTAssertEqual(preview.warningRows, 2)
        XCTAssertEqual(preview.errorRows, 0)
        XCTAssertEqual(preview.potentialDuplicateRows, 2)
        XCTAssertEqual(preview.newTagCount, 3)
        XCTAssertEqual(preview.newCollectionCount, 3)
        XCTAssertEqual(preview.newSourceCount, 3)
        XCTAssertEqual(try repository.allBooks().count, 0, "Preview must never write")

        let exact = preview.sampleRows[1]
        XCTAssertEqual(
            exact.duplicateMatches,
            [ImportDuplicateMatch(scope: .currentBatch(earlierLine: 2), confidence: .exact)]
        )
        XCTAssertTrue(exact.issues.contains { $0.code == "duplicate_current_batch" })
        let strong = preview.sampleRows[3]
        XCTAssertEqual(
            strong.duplicateMatches,
            [ImportDuplicateMatch(scope: .currentBatch(earlierLine: 4), confidence: .strong)]
        )

        let result = try coordinator.execute(preview: preview, repository: repository)
        XCTAssertEqual(result.imported, preview.importableRows)
        XCTAssertEqual(result.skipped, preview.potentialDuplicateRows)
        XCTAssertEqual(result.duplicateRows, preview.potentialDuplicateRows)
        XCTAssertEqual(try repository.allBooks().count, 3)
        XCTAssertEqual(try repository.tagSummaries().count, 3)
        XCTAssertEqual(try repository.collectionSummaries().count, 3)
        XCTAssertEqual(try repository.sourceSummaries().count, 3)
        XCTAssertFalse(FileManager.default.fileExists(atPath: preview.staging.directoryURL.path))

        let report = try XCTUnwrap(result.errorReport)
        XCTAssertEqual(report.issueCount, 2)
        let stagedIssues = try String(contentsOf: report.fileURL, encoding: .utf8)
        XCTAssertTrue(stagedIssues.contains(#""code":"duplicate_at_execution""#))
        XCTAssertFalse(stagedIssues.hasPrefix("row,field,code"))
        let savedReport = directory.appendingPathComponent("actual-import-errors.csv")
        XCTAssertFalse(FileManager.default.fileExists(atPath: savedReport.path))
        try LibraryExportCoordinator().exportErrorReport(report, to: savedReport)
        let reportText = try String(contentsOf: savedReport, encoding: .utf8)
        XCTAssertEqual(
            reportText.components(separatedBy: "duplicate_at_execution").count - 1,
            2
        )
        XCTAssertFalse(reportText.contains("ISBN 变化标题"))
        XCTAssertFalse(reportText.contains("另一个跳过标签"))
    }

    func testDuplicateIntroducedAfterPreviewIsRecheckedAndIncludedInActualReport() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try BookRepository.inMemory()
        let csvURL = directory.appendingPathComponent("changed-library.csv")
        try Data(
            """
            format_version,title,author,isbn
            bookatlas-csv/1,《预览后变化》,虚构作者,978-0-306-40615-7
            """.utf8
        ).write(to: csvURL)
        let coordinator = LibraryImportCoordinator()
        let preview = try coordinator.prepare(url: csvURL, mapping: nil, repository: repository)

        XCTAssertEqual(preview.importableRows, 1)
        XCTAssertEqual(preview.potentialDuplicateRows, 0)
        XCTAssertTrue(try repository.allBooks().isEmpty)

        _ = try repository.create(
            BookDraft(
                title: "《执行前新增》",
                author: "另一位虚构作者",
                isbn: "9780306406157"
            )
        )
        let result = try coordinator.execute(preview: preview, repository: repository)

        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.duplicateRows, 1)
        XCTAssertEqual(try repository.allBooks().count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: preview.staging.directoryURL.path))

        let report = try XCTUnwrap(result.errorReport)
        XCTAssertEqual(report.issueCount, 1)
        let savedReport = directory.appendingPathComponent("actual-changed-library.csv")
        try LibraryExportCoordinator().exportErrorReport(report, to: savedReport)
        let reportText = try String(contentsOf: savedReport, encoding: .utf8)
        XCTAssertTrue(reportText.contains("duplicate_at_execution"))
        XCTAssertFalse(reportText.contains("预览后变化"))
        XCTAssertFalse(reportText.contains("执行前新增"))
    }

    func testThreeRowBatchMarksOnlyLaterExactRowAndExcludesItsAssociationsFromForecast() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try BookRepository.inMemory()
        let csvURL = directory.appendingPathComponent("three-rows.csv")
        try Data(
            """
            format_version,title,author,isbn,tags,collections,sources
            bookatlas-csv/1,《第一本》,虚构甲,,标签甲,书单甲,来源甲
            bookatlas-csv/1,《第二本》,虚构乙,978-1-4028-9462-6,标签乙,书单乙,来源乙
            bookatlas-csv/1,《第三行重复第二本》,虚构丙,9781402894626,不应新建标签,不应新建书单,不应新建来源
            """.utf8
        ).write(to: csvURL)
        let coordinator = LibraryImportCoordinator()
        let preview = try coordinator.prepare(url: csvURL, mapping: nil, repository: repository)
        defer {
            if FileManager.default.fileExists(atPath: preview.staging.directoryURL.path) {
                coordinator.discard(preview)
            }
        }

        XCTAssertEqual(preview.importableRows, 2)
        XCTAssertEqual(preview.potentialDuplicateRows, 1)
        XCTAssertEqual(preview.newTagCount, 2)
        XCTAssertEqual(preview.newCollectionCount, 2)
        XCTAssertEqual(preview.newSourceCount, 2)
        XCTAssertTrue(preview.sampleRows[0].duplicateMatches.isEmpty)
        XCTAssertTrue(preview.sampleRows[1].duplicateMatches.isEmpty)
        XCTAssertEqual(
            preview.sampleRows[2].duplicateMatches,
            [ImportDuplicateMatch(scope: .currentBatch(earlierLine: 3), confidence: .exact)]
        )
        XCTAssertTrue(try repository.allBooks().isEmpty)
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

    func testPortableExportsExcludePrivateWebLinksBookmarksAndLocalPaths() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try BookRepository.inMemory()
        let book = try repository.create(
            BookDraft(title: "《便携边界》", author: "虚构作者"),
            at: FictionalLibraryFixtures.timestamp
        )
        let privateURL = "https://private.example.invalid/account/secret-token"
        let privatePath = "/Users/fictional/Private/secret.pdf"
        let bookmark = Data("opaque-bookmark-secret".utf8)
        try repository.addExternalLink(
            ExternalLink(
                bookID: book.id,
                kind: .web,
                label: "私人入口",
                value: privateURL,
                createdAt: FictionalLibraryFixtures.timestamp
            )
        )
        try repository.addLocalFileReference(
            LocalFileReference(
                bookID: book.id,
                displayName: "secret.pdf",
                bookmarkData: Data(privatePath.utf8) + bookmark,
                createdAt: FictionalLibraryFixtures.timestamp
            )
        )
        let csvURL = directory.appendingPathComponent("library.csv")
        let markdownURL = directory.appendingPathComponent("library.md")
        let exporter = LibraryExportCoordinator(
            now: { FictionalLibraryFixtures.timestamp }
        )

        try exporter.exportCSV(repository: repository, to: csvURL)
        try exporter.exportMarkdown(repository: repository, to: markdownURL)

        for url in [csvURL, markdownURL] {
            let data = try Data(contentsOf: url)
            let text = try XCTUnwrap(String(data: data, encoding: .utf8))
            XCTAssertFalse(text.contains(privateURL))
            XCTAssertFalse(text.contains(privatePath))
            XCTAssertFalse(text.contains(String(decoding: bookmark, as: UTF8.self)))
        }
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
