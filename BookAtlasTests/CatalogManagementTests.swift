import XCTest
@testable import BookAtlas

final class CatalogManagementTests: XCTestCase {
    @MainActor
    func testOrganizerPublishesCatalogMutationSnapshot() async throws {
        let service = LibraryCatalogService(
            repository: try BookRepository.inMemory(),
            now: { FictionalLibraryFixtures.timestamp }
        )
        let organizer = CatalogOrganizerStore(catalog: service)

        let succeeded = await organizer.createTag(name: "Harbor Draft")
        XCTAssertTrue(succeeded)
        XCTAssertEqual(organizer.snapshot.tags.map(\.tag.name), ["Harbor Draft"])
    }

    func testNormalizedNamesConflictAndMetadataCanBeRenamed() async throws {
        let service = LibraryCatalogService(
            repository: try BookRepository.inMemory(),
            now: { FictionalLibraryFixtures.timestamp }
        )
        let tag = try await service.createTag(name: "  Sea   Light ")
        XCTAssertEqual(tag.name, "Sea Light")

        do {
            _ = try await service.createTag(name: "sea light")
            XCTFail("Expected normalized name conflict")
        } catch {
            XCTAssertEqual(error as? CatalogServiceError, .nameConflict)
        }
        do {
            _ = try await service.createTag(name: " \n ")
            XCTFail("Expected blank tag name to fail")
        } catch {
            XCTAssertEqual(error as? DomainValidationError, .blankName)
        }

        let renamed = try await service.renameTag(tag, name: "Harbor Light")
        let collection = try await service.createCollection(name: "North Shelf", description: "Fictional list")
        let revisedCollection = try await service.renameCollection(
            collection,
            name: "North Shelf Revised",
            description: "Revised fictional list"
        )
        let source = try await service.createSource(name: "Paper Signal", details: "Fictional source")
        let revisedSource = try await service.renameSource(
            source,
            name: "Paper Signal Weekly",
            details: "Revised fictional source"
        )

        let snapshot = try await service.catalogSnapshot()
        XCTAssertEqual(snapshot.tags.map(\.tag), [renamed])
        XCTAssertEqual(snapshot.collections.map(\.collection), [revisedCollection])
        XCTAssertEqual(snapshot.sources.map(\.source), [revisedSource])
    }

    func testAssociationsAreUniqueCountsAreDerivedAndTagsMergeTransactionally() async throws {
        let service = LibraryCatalogService(repository: try BookRepository.inMemory())
        let first = try await service.createBook(
            from: BookEditorDraft(title: "A101", author: "AuthorA")
        )
        let second = try await service.createBook(
            from: BookEditorDraft(title: "B202", author: "AuthorB")
        )
        let sourceTag = try await service.createTag(name: "SourceTag")
        let targetTag = try await service.createTag(name: "TargetTag")
        let collection = try await service.createCollection(name: "ShelfA", description: nil)
        let source = try await service.createSource(name: "SignalA", details: nil)

        try await service.setAssociation(.tag(sourceTag.id), included: true, bookID: first.id)
        try await service.setAssociation(.tag(sourceTag.id), included: true, bookID: second.id)
        try await service.setAssociation(.tag(targetTag.id), included: true, bookID: second.id)
        try await service.setAssociation(.tag(sourceTag.id), included: true, bookID: first.id)
        try await service.setAssociation(.collection(collection.id), included: true, bookID: first.id)
        try await service.setAssociation(.source(source.id), included: true, bookID: first.id)

        var snapshot = try await service.catalogSnapshot()
        XCTAssertEqual(snapshot.tags.first { $0.id == sourceTag.id }?.bookCount, 2)
        XCTAssertEqual(snapshot.collections.first?.bookCount, 1)
        XCTAssertEqual(snapshot.sources.first?.bookCount, 1)

        try await service.mergeTag(sourceTag, into: targetTag)

        snapshot = try await service.catalogSnapshot()
        XCTAssertNil(snapshot.tags.first { $0.id == sourceTag.id })
        XCTAssertEqual(snapshot.tags.first { $0.id == targetTag.id }?.bookCount, 2)
        let mergedBooks = try await service.queryBooks(LibraryQuery(tagIDs: [targetTag.id]))
        XCTAssertEqual(
            Set(mergedBooks.map(\.id)),
            Set([first.id, second.id])
        )
    }

    func testAssociationsCanBeRemovedAndRemainDuplicateSafeAcrossCatalogTypes() async throws {
        let service = LibraryCatalogService(repository: try BookRepository.inMemory())
        let book = try await service.createBook(
            from: BookEditorDraft(title: "C303", author: "AuthorC")
        )
        let tag = try await service.createTag(name: "TidalTag")
        let collection = try await service.createCollection(name: "ShelfC", description: nil)
        let firstSource = try await service.createSource(name: "SignalC", details: nil)
        let secondSource = try await service.createSource(name: "SignalD", details: nil)

        for association in [
            BookAssociation.tag(tag.id),
            .collection(collection.id),
            .source(firstSource.id)
        ] {
            try await service.setAssociation(association, included: true, bookID: book.id)
            try await service.setAssociation(association, included: true, bookID: book.id)
        }
        try await service.setAssociation(.source(secondSource.id), included: true, bookID: book.id)

        var membership = try await service.membership(for: book.id)
        XCTAssertEqual(membership.tagIDs, [tag.id])
        XCTAssertEqual(membership.collectionIDs, [collection.id])
        XCTAssertEqual(membership.sourceIDs, [firstSource.id, secondSource.id])

        var snapshot = try await service.catalogSnapshot()
        XCTAssertEqual(snapshot.tags.first?.bookCount, 1)
        XCTAssertEqual(snapshot.collections.first?.bookCount, 1)
        XCTAssertEqual(snapshot.sources.first { $0.id == firstSource.id }?.bookCount, 1)
        XCTAssertEqual(snapshot.sources.first { $0.id == secondSource.id }?.bookCount, 1)

        try await service.setAssociation(.tag(tag.id), included: false, bookID: book.id)
        try await service.setAssociation(.collection(collection.id), included: false, bookID: book.id)
        try await service.setAssociation(.source(firstSource.id), included: false, bookID: book.id)

        membership = try await service.membership(for: book.id)
        XCTAssertTrue(membership.tagIDs.isEmpty)
        XCTAssertTrue(membership.collectionIDs.isEmpty)
        XCTAssertEqual(membership.sourceIDs, [secondSource.id])

        snapshot = try await service.catalogSnapshot()
        XCTAssertEqual(snapshot.tags.first?.bookCount, 0)
        XCTAssertEqual(snapshot.collections.first?.bookCount, 0)
        XCTAssertEqual(snapshot.sources.first { $0.id == firstSource.id }?.bookCount, 0)
        XCTAssertEqual(snapshot.sources.first { $0.id == secondSource.id }?.bookCount, 1)
        let remainingBooks = try await service.queryBooks(LibraryQuery())
        XCTAssertEqual(remainingBooks.map(\.id), [book.id])
    }

    func testFailedTagMergeRollsBackMembershipCopies() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        let repository = try BookRepository(database: database)
        let first = try repository.create(
            BookDraft(title: "D404", author: "AuthorD"),
            at: FictionalLibraryFixtures.timestamp
        )
        let second = try repository.create(
            BookDraft(title: "E505", author: "AuthorE"),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(1)
        )
        let sourceTag = try repository.createTag(
            try Tag(name: "RollbackSource", createdAt: FictionalLibraryFixtures.timestamp)
        )
        let targetTag = try repository.createTag(
            try Tag(name: "RollbackTarget", createdAt: FictionalLibraryFixtures.timestamp)
        )
        try repository.attach(tagID: sourceTag.id, toBookID: first.id)
        try repository.attach(tagID: targetTag.id, toBookID: second.id)
        try database.execute(
            """
            CREATE TRIGGER fail_fictional_tag_merge
            BEFORE DELETE ON tags
            WHEN OLD.id = '\(sourceTag.id.uuidString)'
            BEGIN
                SELECT RAISE(ABORT, 'fictional merge rollback');
            END
            """
        )

        XCTAssertThrowsError(try repository.mergeTag(sourceID: sourceTag.id, into: targetTag.id))

        XCTAssertEqual(try repository.tags(forBookID: first.id), [sourceTag])
        XCTAssertEqual(try repository.tags(forBookID: second.id), [targetTag])
        let snapshot = try repository.tagSummaries()
        XCTAssertEqual(snapshot.first { $0.id == sourceTag.id }?.bookCount, 1)
        XCTAssertEqual(snapshot.first { $0.id == targetTag.id }?.bookCount, 1)
    }

    func testDeletingCatalogMetadataKeepsBook() throws {
        let repository = try BookRepository.inMemory()
        let book = try repository.create(FictionalLibraryFixtures.draft(), at: FictionalLibraryFixtures.timestamp)
        let tag = try repository.createTag(
            try Tag(name: "DisposableTag", createdAt: FictionalLibraryFixtures.timestamp)
        )
        let collection = try repository.createCollection(
            try BookCollection(name: "DisposableShelf", createdAt: FictionalLibraryFixtures.timestamp)
        )
        let source = try repository.createSource(
            try RecommendationSource(name: "DisposableSource", createdAt: FictionalLibraryFixtures.timestamp)
        )
        try repository.attach(tagID: tag.id, toBookID: book.id)
        try repository.add(bookID: book.id, toCollectionID: collection.id)
        try repository.attach(sourceID: source.id, toBookID: book.id)

        try repository.deleteTag(id: tag.id)
        try repository.deleteCollection(id: collection.id)
        try repository.deleteSource(id: source.id)
        XCTAssertEqual(try repository.book(id: book.id), book)
        XCTAssertTrue(try repository.tags(forBookID: book.id).isEmpty)
        XCTAssertTrue(try repository.collections(forBookID: book.id).isEmpty)
        XCTAssertTrue(try repository.sources(forBookID: book.id).isEmpty)
    }
}
