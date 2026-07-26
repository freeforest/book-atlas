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

    func testSortingIsStableAndPriorityKeepsUnsetValuesLast() throws {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let thirdID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let timestamp = FictionalLibraryFixtures.timestamp

        _ = try repository.create(
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

        XCTAssertEqual(
            try repository.query(
                LibraryQuery(sortField: .createdAt, sortDirection: .ascending)
            ).map(\.id),
            [firstID, secondID, thirdID]
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
}
