import XCTest
@testable import BookAtlas

final class LibraryRepositoryTests: XCTestCase {
    private var repository: BookRepository!

    override func setUpWithError() throws {
        repository = try BookRepository.inMemory()
    }

    override func tearDown() {
        repository = nil
    }

    func testCreateReadUpdateSearchFilterAndDeleteBook() throws {
        let created = try repository.create(
            FictionalLibraryFixtures.draft(),
            at: FictionalLibraryFixtures.timestamp
        )
        XCTAssertEqual(try repository.book(id: created.id), created)

        let revised = try created.applying(
            FictionalLibraryFixtures.draft(title: "《雾港档案：修订版》", status: .read),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(60)
        )
        try repository.update(revised)

        XCTAssertEqual(try repository.list(readingStatus: .read).map(\.id), [created.id])
        XCTAssertEqual(try repository.search("修订").map(\.title), ["《雾港档案：修订版》"])
        XCTAssertEqual(try repository.search("%_"), [])

        try repository.deleteBook(id: created.id)
        XCTAssertNil(try repository.book(id: created.id))
    }

    func testAllSupportedRelationshipsRoundTripAndCascadeWithBookDeletion() throws {
        let first = try repository.create(FictionalLibraryFixtures.allDrafts()[0], at: FictionalLibraryFixtures.timestamp)
        let second = try repository.create(FictionalLibraryFixtures.allDrafts()[1], at: FictionalLibraryFixtures.timestamp)
        let tag = try repository.createTag(FictionalLibraryFixtures.tag())
        let collection = try repository.createCollection(FictionalLibraryFixtures.collection())
        let source = try repository.createSource(FictionalLibraryFixtures.source())
        let link = try ExternalLink(
            bookID: first.id,
            kind: .web,
            label: "虚构书页",
            value: "https://example.invalid/mist-harbor",
            createdAt: FictionalLibraryFixtures.timestamp
        )
        let relation = try ManualBookRelation(
            sourceBookID: first.id,
            targetBookID: second.id,
            kind: .inspiredBy,
            createdAt: FictionalLibraryFixtures.timestamp
        )

        try repository.attach(tagID: tag.id, toBookID: first.id)
        try repository.attach(tagID: tag.id, toBookID: first.id)
        try repository.add(bookID: first.id, toCollectionID: collection.id)
        try repository.attach(sourceID: source.id, toBookID: first.id)
        try repository.addExternalLink(link)
        try repository.addManualRelation(relation)

        XCTAssertEqual(try repository.tags(forBookID: first.id), [tag])
        XCTAssertEqual(try repository.collections(forBookID: first.id), [collection])
        XCTAssertEqual(try repository.sources(forBookID: first.id), [source])
        XCTAssertEqual(try repository.externalLinks(forBookID: first.id), [link])
        XCTAssertEqual(try repository.manualRelations(forBookID: first.id), [relation])

        try repository.deleteBook(id: first.id)
        XCTAssertEqual(try repository.externalLinks(forBookID: first.id), [])
        XCTAssertEqual(try repository.manualRelations(forBookID: second.id), [])
    }

    func testTransactionRollsBackWhenTheUseCaseFails() throws {
        enum ExpectedFailure: Error { case stop }

        XCTAssertThrowsError(
            try repository.transaction { () throws -> Void in
                _ = try repository.create(FictionalLibraryFixtures.draft(), at: FictionalLibraryFixtures.timestamp)
                throw ExpectedFailure.stop
            }
        )
        XCTAssertEqual(try repository.list(), [])
    }

    func testInMemoryRepositoryUsesOnlyTheTestConnection() throws {
        XCTAssertEqual(repository.schemaVersion, BookAtlasSchema.latestVersion)
        XCTAssertEqual(try repository.list(), [])
    }
}
