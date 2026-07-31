import XCTest
@testable import BookAtlas

final class LibraryQueryTests: XCTestCase {
    private var repository: BookRepository!

    override func setUpWithError() throws {
        repository = try BookRepository.inMemory()
    }

    override func tearDown() {
        repository = nil
    }

    func testSearchCoversTitleOriginalTitleAuthorAndNormalizedISBN() throws {
        let book = try repository.create(
            BookDraft(
                title: "Mist Harbor Ledger",
                originalTitle: "Archive of Silver Fog",
                author: "Ada North",
                isbn: "978-1-4028-9462-6"
            ),
            at: FictionalLibraryFixtures.timestamp
        )
        _ = try repository.create(
            BookDraft(title: "Clockwork Orchard", author: "Ivo Bell", isbn: "9780000000001"),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(1)
        )

        XCTAssertEqual(try repository.query(LibraryQuery(searchText: "  mist   harbor  ")).map(\.id), [book.id])
        XCTAssertEqual(try repository.query(LibraryQuery(searchText: "SILVER FOG")).map(\.id), [book.id])
        XCTAssertEqual(try repository.query(LibraryQuery(searchText: "ada north")).map(\.id), [book.id])
        XCTAssertEqual(try repository.query(LibraryQuery(searchText: "978 1 4028 9462 6")).map(\.id), [book.id])
        XCTAssertEqual(try repository.query(LibraryQuery(searchText: "%_")), [])
        XCTAssertEqual(try repository.query(LibraryQuery(searchText: "unmapped term")), [])
    }

    func testAssociationFamiliesUseAndWhileReadingStatusesUseOr() throws {
        let first = try repository.create(
            BookDraft(title: "Aster Index", author: "Mira Vale", readingStatus: .reading),
            at: FictionalLibraryFixtures.timestamp
        )
        let second = try repository.create(
            BookDraft(title: "Beacon Index", author: "Mira Vale", readingStatus: .reading),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(1)
        )
        let third = try repository.create(
            BookDraft(title: "Cinder Index", author: "Noa Reed", readingStatus: .read),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(2)
        )
        let coastal = try repository.createTag(try Tag(name: "Coastal", createdAt: FictionalLibraryFixtures.timestamp))
        let reference = try repository.createTag(try Tag(name: "Reference", createdAt: FictionalLibraryFixtures.timestamp))
        let collection = try repository.createCollection(
            try BookCollection(name: "Research Shelf", createdAt: FictionalLibraryFixtures.timestamp)
        )
        let source = try repository.createSource(
            try RecommendationSource(name: "North Review", createdAt: FictionalLibraryFixtures.timestamp)
        )

        try repository.attach(tagID: coastal.id, toBookID: first.id)
        try repository.attach(tagID: reference.id, toBookID: first.id)
        try repository.add(bookID: first.id, toCollectionID: collection.id)
        try repository.attach(sourceID: source.id, toBookID: first.id)

        try repository.attach(tagID: coastal.id, toBookID: second.id)
        try repository.add(bookID: second.id, toCollectionID: collection.id)

        try repository.attach(tagID: reference.id, toBookID: third.id)
        try repository.attach(sourceID: source.id, toBookID: third.id)

        let statusQuery = LibraryQuery(readingStatuses: [.reading, .read])
        XCTAssertEqual(Set(try repository.query(statusQuery).map(\.id)), Set([first.id, second.id, third.id]))

        let combined = LibraryQuery(
            searchText: "Index",
            readingStatuses: [.reading, .read],
            tagIDs: [coastal.id, reference.id],
            collectionIDs: [collection.id],
            sourceIDs: [source.id]
        )
        XCTAssertEqual(try repository.query(combined).map(\.id), [first.id])
    }

    func testEachStructuredFilterCanBeAppliedIndependently() throws {
        let matching = try repository.create(
            BookDraft(title: "Aster Ledger", author: "Mira Vale", readingStatus: .reading),
            at: FictionalLibraryFixtures.timestamp
        )
        _ = try repository.create(
            BookDraft(title: "Beacon Ledger", author: "Noa Reed", readingStatus: .read),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(1)
        )
        let tag = try repository.createTag(
            try Tag(name: "Coastal", createdAt: FictionalLibraryFixtures.timestamp)
        )
        let collection = try repository.createCollection(
            try BookCollection(name: "Research Shelf", createdAt: FictionalLibraryFixtures.timestamp)
        )
        let source = try repository.createSource(
            try RecommendationSource(name: "North Review", createdAt: FictionalLibraryFixtures.timestamp)
        )
        try repository.attach(tagID: tag.id, toBookID: matching.id)
        try repository.add(bookID: matching.id, toCollectionID: collection.id)
        try repository.attach(sourceID: source.id, toBookID: matching.id)

        XCTAssertEqual(
            try repository.query(LibraryQuery(readingStatuses: [.reading])).map(\.id),
            [matching.id]
        )
        XCTAssertEqual(
            try repository.query(LibraryQuery(tagIDs: [tag.id])).map(\.id),
            [matching.id]
        )
        XCTAssertEqual(
            try repository.query(LibraryQuery(collectionIDs: [collection.id])).map(\.id),
            [matching.id]
        )
        XCTAssertEqual(
            try repository.query(LibraryQuery(sourceIDs: [source.id])).map(\.id),
            [matching.id]
        )
    }

    func testSortingIsStableAndPriorityKeepsUnsetValuesLast() throws {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let thirdID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let timestamp = FictionalLibraryFixtures.timestamp

        let second = try repository.create(
            BookDraft(title: "A", author: "Author", priority: BookPriority(rawValue: 2)),
            id: secondID,
            at: timestamp
        )
        _ = try repository.create(
            BookDraft(title: "B", author: "Author", priority: BookPriority(rawValue: 5)),
            id: firstID,
            at: timestamp
        )
        _ = try repository.create(
            BookDraft(title: "C", author: "Author"),
            id: thirdID,
            at: timestamp.addingTimeInterval(10)
        )
        try repository.update(
            try second.applying(
                BookDraft(title: "A Revised", author: "Author", priority: BookPriority(rawValue: 2)),
                at: timestamp.addingTimeInterval(20)
            )
        )

        XCTAssertEqual(
            try repository.query(
                LibraryQuery(sortField: .createdAt, sortDirection: .ascending)
            ).map(\.id),
            [firstID, secondID, thirdID]
        )
        XCTAssertEqual(
            try repository.query(
                LibraryQuery(sortField: .createdAt, sortDirection: .descending)
            ).map(\.id),
            [thirdID, firstID, secondID]
        )
        XCTAssertEqual(
            try repository.query(
                LibraryQuery(sortField: .updatedAt, sortDirection: .ascending)
            ).map(\.id),
            [firstID, thirdID, secondID]
        )
        XCTAssertEqual(
            try repository.query(
                LibraryQuery(sortField: .updatedAt, sortDirection: .descending)
            ).map(\.id),
            [secondID, thirdID, firstID]
        )
        XCTAssertEqual(
            try repository.query(
                LibraryQuery(sortField: .priority, sortDirection: .descending)
            ).map(\.id),
            [firstID, secondID, thirdID]
        )
        XCTAssertEqual(
            try repository.query(
                LibraryQuery(sortField: .priority, sortDirection: .ascending)
            ).map(\.id),
            [secondID, firstID, thirdID]
        )
    }

    func testClearFiltersPreservesSortAndRestoresNormalResults() throws {
        _ = try repository.create(FictionalLibraryFixtures.draft(), at: FictionalLibraryFixtures.timestamp)
        var query = LibraryQuery(
            searchText: "missing",
            readingStatuses: [.reading],
            tagIDs: [UUID()],
            collectionIDs: [UUID()],
            sourceIDs: [UUID()],
            sortField: .createdAt,
            sortDirection: .ascending
        )
        XCTAssertTrue(try repository.query(query).isEmpty)

        query.clearFilters()

        XCTAssertFalse(query.hasFilters)
        XCTAssertEqual(query.sortField, .createdAt)
        XCTAssertEqual(query.sortDirection, .ascending)
        XCTAssertEqual(try repository.query(query).count, 1)
    }

    func testPagedQueryDisclosesCompleteTotalsAndHasNoBoundaryGapsAtScale() throws {
        try repository.transaction {
            for index in 0 ..< 10_000 {
                let status: ReadingStatus
                if index < 501 {
                    status = .reading
                } else if index < 1_001 {
                    status = .read
                } else {
                    status = .wishToRead
                }
                _ = try repository.create(
                    BookDraft(
                        title: String(format: "《分页边界 %05d》", index),
                        author: "固定虚构作者",
                        readingStatus: status
                    ),
                    id: pagedID(index),
                    at: FictionalLibraryFixtures.timestamp
                )
            }
        }

        let scenarios: [(LibraryQuery, Int, Int)] = [
            (
                LibraryQuery(
                    readingStatuses: [.reading],
                    sortField: .createdAt,
                    sortDirection: .ascending
                ),
                501,
                101
            ),
            (
                LibraryQuery(
                    readingStatuses: [.reading, .read],
                    sortField: .createdAt,
                    sortDirection: .ascending
                ),
                1_001,
                1
            ),
            (
                LibraryQuery(
                    sortField: .createdAt,
                    sortDirection: .ascending
                ),
                10_000,
                200
            )
        ]

        for (query, expectedTotal, expectedLastPageCount) in scenarios {
            let pages = try allPages(for: query)
            let books = pages.flatMap(\.books)
            XCTAssertEqual(pages.first?.offset, 0)
            XCTAssertEqual(pages.first?.books.count, 200)
            XCTAssertEqual(pages.last?.books.count, expectedLastPageCount)
            XCTAssertEqual(pages.last?.hasMore, false)
            XCTAssertEqual(
                Set(pages.map(\.totalCount)),
                Set([expectedTotal])
            )
            XCTAssertEqual(books.count, expectedTotal)
            XCTAssertEqual(Set(books.map(\.id)).count, expectedTotal)
            XCTAssertEqual(
                books.map(\.id),
                (0 ..< expectedTotal).map(pagedID),
                "Created-time pagination must retain the UUID tie-breaker"
            )
        }

        var oversizedQuery = LibraryQuery()
        oversizedQuery.limit = LibraryQuery.maximumPageSize + 1
        XCTAssertThrowsError(try repository.queryPage(oversizedQuery)) {
            XCTAssertEqual($0 as? BookRepositoryError, .invalidQuery)
        }
    }

    func testPagedQueryRemainsConsistentAfterDeleteAndMerge() throws {
        var books: [Book] = []
        try repository.transaction {
            for index in 0 ..< 203 {
                books.append(
                    try repository.create(
                        BookDraft(
                            title: index < 2
                                ? "《可合并分页书》"
                                : String(format: "《分页变更 %03d》", index),
                            author: "固定虚构作者"
                        ),
                        id: pagedID(index),
                        at: FictionalLibraryFixtures.timestamp
                            .addingTimeInterval(TimeInterval(index))
                    )
                )
            }
        }

        try repository.deleteBook(id: books[150].id)
        var pages = try allPages(
            for: LibraryQuery(
                sortField: .createdAt,
                sortDirection: .ascending
            )
        )
        XCTAssertEqual(pages.first?.books.count, 200)
        XCTAssertEqual(pages.last?.books.count, 2)
        XCTAssertEqual(pages.last?.totalCount, 202)
        XCTAssertEqual(Set(pages.flatMap(\.books).map(\.id)).count, 202)

        let preview = try repository.mergePreview(
            targetID: books[0].id,
            sourceID: books[1].id
        )
        let result = try repository.mergeBooks(
            targetID: books[0].id,
            sourceID: books[1].id,
            selections: preview.defaultSelections,
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(1_000)
        )

        pages = try allPages(
            for: LibraryQuery(
                sortField: .createdAt,
                sortDirection: .ascending
            )
        )
        let remainingIDs = pages.flatMap(\.books).map(\.id)
        XCTAssertEqual(pages.last?.totalCount, 201)
        XCTAssertEqual(Set(remainingIDs).count, 201)
        XCTAssertTrue(remainingIDs.contains(result.retainedBook.id))
        XCTAssertFalse(remainingIDs.contains(books[1].id))
    }

    func testFocusedPageReturnsOneMatchingOffPageIdentityWithoutExpandingThePage() throws {
        try repository.transaction {
            for index in 0 ..< 501 {
                _ = try repository.create(
                    BookDraft(
                        title: String(format: "《有界定位 %03d》", index),
                        author: "固定虚构作者"
                    ),
                    id: pagedID(index),
                    at: FictionalLibraryFixtures.timestamp
                        .addingTimeInterval(TimeInterval(index))
                )
            }
        }

        let targetID = pagedID(450)
        let query = LibraryQuery(
            sortField: .createdAt,
            sortDirection: .ascending
        )
        let focused = try repository.queryPage(
            query,
            focusedBookID: targetID
        )

        XCTAssertEqual(focused.page.books.count, 200)
        XCTAssertEqual(focused.page.totalCount, 501)
        XCTAssertFalse(focused.page.books.contains(where: { $0.id == targetID }))
        XCTAssertEqual(focused.focusedBook?.id, targetID)
        XCTAssertEqual(focused.focusedBook?.title, "《有界定位 450》")

        var excludedQuery = query
        excludedQuery.searchText = "有界定位 001"
        let excluded = try repository.queryPage(
            excludedQuery,
            focusedBookID: targetID
        )
        XCTAssertEqual(excluded.page.books.map(\.id), [pagedID(1)])
        XCTAssertEqual(excluded.page.totalCount, 1)
        XCTAssertNil(excluded.focusedBook)
    }

    private func allPages(for baseQuery: LibraryQuery) throws -> [LibraryPage] {
        var pages: [LibraryPage] = []
        var query = baseQuery
        query.limit = LibraryQuery.defaultPageSize
        query.offset = 0

        repeat {
            let page = try repository.queryPage(query)
            pages.append(page)
            query.offset += page.books.count
            if page.books.isEmpty {
                break
            }
        } while pages.last?.hasMore == true

        return pages
    }

    private func pagedID(_ index: Int) -> UUID {
        UUID(
            uuidString: String(
                format: "40000000-0000-0000-0000-%012d",
                index
            )
        )!
    }
}
