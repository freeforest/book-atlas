import XCTest
@testable import BookAtlas

final class LibraryQueryBenchmarkTests: XCTestCase {
    @MainActor
    func testRepeatableQueryBaselinesAtOneFiveAndTenThousandBooks() throws {
        for size in [1_000, 5_000, 10_000] {
            let repository = try BookRepository.inMemory()
            let tag = try repository.createTag(
                try Tag(name: "BaselineTag", createdAt: FictionalLibraryFixtures.timestamp)
            )

            let insertionStart = ContinuousClock.now
            try repository.transaction {
                for index in 0 ..< size {
                    _ = try repository.create(
                        BookDraft(
                            title: String(format: "Fictional Volume %05d", index),
                            originalTitle: String(format: "Archive %05d", index),
                            author: "Author \(index % 97)",
                            isbn: String(format: "978%010d", index),
                            readingStatus: index.isMultiple(of: 3) ? .reading : .wishToRead,
                            priority: BookPriority(rawValue: (index % 5) + 1)
                        ),
                        id: deterministicID(index),
                        at: FictionalLibraryFixtures.timestamp.addingTimeInterval(TimeInterval(index))
                    )
                }
            }
            let insertionDuration = insertionStart.duration(to: .now)

            let associationStart = ContinuousClock.now
            try repository.transaction {
                for index in stride(from: 0, to: size, by: 10) {
                    try repository.attach(tagID: tag.id, toBookID: deterministicID(index))
                }
            }
            let associationDuration = associationStart.duration(to: .now)

            let queryConstructionStart = ContinuousClock.now
            let searchQuery = LibraryQuery(searchText: "Volume 00042", limit: 100)
            let filterQuery = LibraryQuery(
                readingStatuses: [.reading],
                tagIDs: [tag.id],
                sortField: .priority,
                sortDirection: .descending,
                limit: 100
            )
            let sortQuery = LibraryQuery(
                sortField: .createdAt,
                sortDirection: .ascending,
                limit: 100
            )
            let queryConstructionDuration = queryConstructionStart.duration(to: .now)

            let searchStart = ContinuousClock.now
            let searchResult = try repository.query(searchQuery)
            let searchDuration = searchStart.duration(to: .now)

            let filterStart = ContinuousClock.now
            let filtered = try repository.query(filterQuery)
            let filterDuration = filterStart.duration(to: .now)

            let sortStart = ContinuousClock.now
            let sorted = try repository.query(sortQuery)
            let sortDuration = sortStart.duration(to: .now)

            XCTAssertFalse(searchResult.isEmpty)
            XCTAssertLessThanOrEqual(filtered.count, 100)
            XCTAssertEqual(sorted.count, min(size, 100))
            print(
                """
                QUERY_BASELINE_\(size)=insert:\(insertionDuration.secondsValue),\
                tag_write:\(associationDuration.secondsValue),\
                query_build:\(queryConstructionDuration.secondsValue),\
                search:\(searchDuration.secondsValue),\
                filter:\(filterDuration.secondsValue),\
                sort:\(sortDuration.secondsValue)
                """
            )
            XCTContext.runActivity(named: "Baseline \(size) fictional books") { activity in
                let attachment = XCTAttachment(
                    string: """
                    count=\(size)
                    insert=\(insertionDuration)
                    query_construction=\(queryConstructionDuration)
                    tag_associations=\(size / 10)
                    tag_association_write=\(associationDuration)
                    search=\(searchDuration)
                    multi_filter=\(filterDuration)
                    sort=\(sortDuration)
                    """
                )
                attachment.lifetime = .keepAlways
                activity.add(attachment)
            }
        }
    }

    func testPromptTenOpenInitialLoadTagCountAndHistoricalMigrationBaselines() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "BookAtlas-Prompt10-Missing-Performance-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        for size in [1_000, 5_000, 10_000] {
            let currentURL = root.appendingPathComponent("current-\(size).sqlite")
            try makeCurrentPerformanceDatabase(at: currentURL, size: size)

            for run in 1 ... 3 {
                let openStart = ContinuousClock.now
                let database = try SQLiteDatabase(path: currentURL.path)
                let repository = try BookRepository(database: database)
                let openDuration = openStart.duration(to: .now)

                let listStart = ContinuousClock.now
                let books = try repository.query(LibraryQuery())
                let listDuration = listStart.duration(to: .now)

                let tagStart = ContinuousClock.now
                let tags = try repository.tagSummaries()
                let tagDuration = tagStart.duration(to: .now)

                XCTAssertEqual(books.count, 500)
                XCTAssertEqual(tags.count, 32)
                XCTAssertEqual(tags.reduce(0) { $0 + $1.bookCount }, size)
                try database.close()

                print(
                    """
                    P10_STORAGE_BASELINE configuration=\(buildConfiguration) \
                    books=\(size) run=\(run) open=\(openDuration.secondsValue) \
                    initial_list=\(listDuration.secondsValue) \
                    tag_usage=\(tagDuration.secondsValue)
                    """
                )
            }

            for sourceVersion in 1 ..< BookAtlasSchema.latestVersion {
                let sourceURL = root.appendingPathComponent(
                    "schema-\(sourceVersion)-\(size).sqlite"
                )
                try makeHistoricalPerformanceDatabase(
                    at: sourceURL,
                    size: size,
                    schemaVersion: sourceVersion
                )

                for run in 1 ... 3 {
                    let runURL = root.appendingPathComponent(
                        "schema-\(sourceVersion)-\(size)-run-\(run).sqlite"
                    )
                    try FileManager.default.copyItem(at: sourceURL, to: runURL)
                    defer { try? FileManager.default.removeItem(at: runURL) }

                    let database = try SQLiteDatabase(path: runURL.path)
                    let migrationStart = ContinuousClock.now
                    let migratedVersion = try DatabaseMigrator().migrate(database)
                    let migrationDuration = migrationStart.duration(to: .now)

                    XCTAssertEqual(migratedVersion, BookAtlasSchema.latestVersion)
                    XCTAssertEqual(
                        try database.scalarInt("SELECT COUNT(*) FROM books"),
                        Int64(size)
                    )
                    XCTAssertTrue(try database.foreignKeyCheck())
                    try database.close()

                    print(
                        """
                        P10_MIGRATION_BASELINE configuration=\(buildConfiguration) \
                        source_schema=\(sourceVersion) books=\(size) run=\(run) \
                        migrate=\(migrationDuration.secondsValue)
                        """
                    )
                }
            }
        }
    }

    private var buildConfiguration: String {
        Bundle(for: LibraryQueryBenchmarkTests.self).bundleURL.pathComponents
            .contains("Debug") ? "Debug" : "Release"
    }

    private func makeCurrentPerformanceDatabase(at url: URL, size: Int) throws {
        let repository = try BookRepository(databaseURL: url)
        let tags = try (0 ..< 32).map { index in
            try repository.createTag(
                Tag(
                    id: deterministicID(namespace: 1, index: index),
                    name: String(format: "固定性能标签 %02d", index),
                    createdAt: FictionalLibraryFixtures.timestamp
                )
            )
        }
        try repository.transaction {
            for index in 0 ..< size {
                let book = try repository.create(
                    performanceDraft(index),
                    id: deterministicID(namespace: 2, index: index),
                    at: FictionalLibraryFixtures.timestamp.addingTimeInterval(
                        TimeInterval(index)
                    )
                )
                try repository.attach(
                    tagID: tags[index % tags.count].id,
                    toBookID: book.id
                )
            }
        }
        try repository.database.close()
    }

    private func makeHistoricalPerformanceDatabase(
        at url: URL,
        size: Int,
        schemaVersion: Int
    ) throws {
        let database = try SQLiteDatabase(path: url.path)
        try DatabaseMigrator().migrate(database, through: schemaVersion)
        let repository = try BookRepository(
            database: database,
            automaticallyMigrate: false
        )
        try repository.transaction {
            for index in 0 ..< size {
                _ = try repository.create(
                    performanceDraft(index),
                    id: deterministicID(
                        namespace: 10 + schemaVersion,
                        index: index
                    ),
                    at: FictionalLibraryFixtures.timestamp.addingTimeInterval(
                        TimeInterval(index)
                    )
                )
            }
        }
        try database.close()
    }

    private func performanceDraft(_ index: Int) -> BookDraft {
        BookDraft(
            title: String(format: "《固定存储书目 %05d》", index),
            originalTitle: String(format: "Synthetic Storage %05d", index),
            author: "虚构作者 \(index % 97)",
            readingStatus: ReadingStatus.allCases[index % ReadingStatus.allCases.count],
            priority: BookPriority(rawValue: (index % 5) + 1),
            note: index.isMultiple(of: 11) ? "固定虚构性能备注。" : nil
        )
    }

    private func deterministicID(namespace: Int, index: Int) -> UUID {
        UUID(
            uuidString: String(
                format: "%08d-0000-0000-0000-%012d",
                namespace,
                index
            )
        )!
    }

    private func deterministicID(_ index: Int) -> UUID {
        let suffix = String(format: "%012d", index)
        return UUID(uuidString: "00000000-0000-0000-0000-\(suffix)")!
    }
}
