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

    func testManualRelationSummariesReadBothDirectionsInDeterministicOrder() throws {
        let center = try repository.create(
            FictionalLibraryFixtures.draft(title: "《关系中心》", author: "虚构中心作者"),
            at: FictionalLibraryFixtures.timestamp
        )
        let outgoingLater = try repository.create(
            FictionalLibraryFixtures.draft(title: "《乙方书》", author: "虚构乙作者"),
            at: FictionalLibraryFixtures.timestamp
        )
        let outgoingFirst = try repository.create(
            FictionalLibraryFixtures.draft(title: "《甲方书》", author: "虚构甲作者"),
            at: FictionalLibraryFixtures.timestamp
        )
        let incomingLater = try repository.create(
            FictionalLibraryFixtures.draft(title: "《丁方书》", author: "虚构丁作者"),
            at: FictionalLibraryFixtures.timestamp
        )
        let incomingFirst = try repository.create(
            FictionalLibraryFixtures.draft(title: "《丙方书》", author: "虚构丙作者"),
            at: FictionalLibraryFixtures.timestamp
        )

        for relation in [
            try ManualBookRelation(
                sourceBookID: incomingLater.id,
                targetBookID: center.id,
                kind: .related,
                createdAt: FictionalLibraryFixtures.timestamp.addingTimeInterval(4)
            ),
            try ManualBookRelation(
                sourceBookID: center.id,
                targetBookID: outgoingLater.id,
                kind: .companion,
                createdAt: FictionalLibraryFixtures.timestamp.addingTimeInterval(1)
            ),
            try ManualBookRelation(
                sourceBookID: incomingFirst.id,
                targetBookID: center.id,
                kind: .respondsTo,
                note: "固定虚构传入备注",
                createdAt: FictionalLibraryFixtures.timestamp.addingTimeInterval(3)
            ),
            try ManualBookRelation(
                sourceBookID: center.id,
                targetBookID: outgoingFirst.id,
                kind: .inspiredBy,
                note: "固定虚构传出备注",
                createdAt: FictionalLibraryFixtures.timestamp.addingTimeInterval(2)
            )
        ] {
            _ = try repository.addManualRelation(relation)
        }

        let summaries = try repository.manualRelationSummaries(forBookID: center.id)
        XCTAssertEqual(
            summaries.map(\.direction),
            [.outgoing, .outgoing, .incoming, .incoming]
        )
        XCTAssertEqual(
            summaries.map(\.otherBookTitle),
            ["《乙方书》", "《甲方书》", "《丁方书》", "《丙方书》"]
        )
        XCTAssertEqual(
            summaries.first { $0.otherBookID == outgoingFirst.id }?.relation.note,
            "固定虚构传出备注"
        )
        XCTAssertEqual(
            summaries.first { $0.otherBookID == incomingFirst.id }?.relation.note,
            "固定虚构传入备注"
        )
        XCTAssertEqual(
            try repository.manualRelationSummaries(forBookID: center.id),
            summaries
        )
    }

    func testManualRelationConflictMissingEndpointAndDeletionAreSafe() throws {
        let source = try repository.create(
            FictionalLibraryFixtures.draft(title: "《关系来源》"),
            at: FictionalLibraryFixtures.timestamp
        )
        let target = try repository.create(
            FictionalLibraryFixtures.draft(title: "《关系目标》"),
            at: FictionalLibraryFixtures.timestamp
        )
        let relation = try ManualBookRelation(
            sourceBookID: source.id,
            targetBookID: target.id,
            kind: .related,
            createdAt: FictionalLibraryFixtures.timestamp
        )
        _ = try repository.addManualRelation(relation)

        XCTAssertThrowsError(
            try repository.addManualRelation(
                ManualBookRelation(
                    sourceBookID: source.id,
                    targetBookID: target.id,
                    kind: .related,
                    note: "不会覆盖原关系",
                    createdAt: FictionalLibraryFixtures.timestamp
                )
            )
        ) { error in
            XCTAssertEqual(error as? BookRepositoryError, .manualRelationConflict)
        }
        XCTAssertThrowsError(
            try repository.addManualRelation(
                ManualBookRelation(
                    sourceBookID: source.id,
                    targetBookID: UUID(),
                    kind: .companion,
                    createdAt: FictionalLibraryFixtures.timestamp
                )
            )
        ) { error in
            XCTAssertEqual(error as? BookRepositoryError, .bookNotFound)
        }

        try repository.deleteManualRelation(id: relation.id)
        XCTAssertEqual(try repository.book(id: source.id), source)
        XCTAssertEqual(try repository.book(id: target.id), target)
        XCTAssertEqual(try repository.manualRelations(forBookID: source.id), [])
        XCTAssertThrowsError(try repository.deleteManualRelation(id: relation.id)) { error in
            XCTAssertEqual(error as? BookRepositoryError, .entityNotFound)
        }
    }

    func testManualRelationTargetQueryExcludesSourceAndPaginatesWithoutTruncation() throws {
        let source = try repository.create(
            FictionalLibraryFixtures.draft(title: "《检索来源》", author: "共同虚构作者"),
            at: FictionalLibraryFixtures.timestamp
        )
        let first = try repository.create(
            FictionalLibraryFixtures.draft(title: "《检索目标甲》", author: "共同虚构作者"),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(1)
        )
        let second = try repository.create(
            FictionalLibraryFixtures.draft(title: "《检索目标乙》", author: "共同虚构作者"),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(2)
        )
        var query = LibraryQuery(
            searchText: "共同虚构作者",
            sortField: .createdAt,
            sortDirection: .ascending,
            limit: 1
        )

        let firstPage = try repository.queryManualRelationTargetPage(
            query,
            excludingBookID: source.id
        )
        XCTAssertEqual(firstPage.books.map(\.id), [first.id])
        XCTAssertEqual(firstPage.totalCount, 2)
        XCTAssertTrue(firstPage.hasMore)

        query.offset = 1
        let secondPage = try repository.queryManualRelationTargetPage(
            query,
            excludingBookID: source.id
        )
        XCTAssertEqual(secondPage.books.map(\.id), [second.id])
        XCTAssertFalse(secondPage.hasMore)
        XCTAssertFalse((firstPage.books + secondPage.books).contains { $0.id == source.id })
    }

    func testLocalFileReferenceCRUDAndBookDeletionCascadePreserveOpaqueBytes() throws {
        let book = try repository.create(
            FictionalLibraryFixtures.draft(),
            at: FictionalLibraryFixtures.timestamp
        )
        let created = try LocalFileReference(
            bookID: book.id,
            displayName: "虚构阅读副本.pdf",
            bookmarkData: Data([0x42, 0x41, 0x00, 0xFF]),
            createdAt: FictionalLibraryFixtures.timestamp
        )

        try repository.addLocalFileReference(created)
        XCTAssertEqual(try repository.localFileReferences(forBookID: book.id), [created])

        let updated = try LocalFileReference(
            id: created.id,
            bookID: created.bookID,
            displayName: "虚构阅读副本（移动后）.pdf",
            bookmarkData: Data([0x52, 0x45, 0x46]),
            createdAt: created.createdAt,
            updatedAt: created.updatedAt.addingTimeInterval(10)
        )
        try repository.updateLocalFileReference(updated)
        XCTAssertEqual(try repository.localFileReferences(forBookID: book.id), [updated])

        try repository.deleteLocalFileReference(id: updated.id)
        XCTAssertEqual(try repository.localFileReferences(forBookID: book.id), [])

        try repository.addLocalFileReference(created)
        try repository.deleteBook(id: book.id)
        XCTAssertEqual(try repository.localFileReferences(forBookID: book.id), [])
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
