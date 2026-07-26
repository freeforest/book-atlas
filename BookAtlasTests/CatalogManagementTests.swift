import XCTest
@testable import BookAtlas

final class CatalogManagementTests: XCTestCase {
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

    func testFailedMergeRollsBackAndDeletingCollectionOrSourceKeepsBook() throws {
        let repository = try BookRepository.inMemory()
        let book = try repository.create(FictionalLibraryFixtures.draft(), at: FictionalLibraryFixtures.timestamp)
        let tag = try repository.createTag(try Tag(name: "RollbackTag", createdAt: FictionalLibraryFixtures.timestamp))
        let collection = try repository.createCollection(
            try BookCollection(name: "DisposableShelf", createdAt: FictionalLibraryFixtures.timestamp)
        )
        let source = try repository.createSource(
            try RecommendationSource(name: "DisposableSource", createdAt: FictionalLibraryFixtures.timestamp)
        )
        try repository.attach(tagID: tag.id, toBookID: book.id)
        try repository.add(bookID: book.id, toCollectionID: collection.id)
        try repository.attach(sourceID: source.id, toBookID: book.id)

        XCTAssertThrowsError(try repository.mergeTag(sourceID: tag.id, into: UUID())) { error in
            XCTAssertEqual(error as? BookRepositoryError, .entityNotFound)
        }
        XCTAssertEqual(try repository.tags(forBookID: book.id), [tag])

        try repository.deleteCollection(id: collection.id)
        try repository.deleteSource(id: source.id)
        XCTAssertEqual(try repository.book(id: book.id), book)
        XCTAssertTrue(try repository.collections(forBookID: book.id).isEmpty)
        XCTAssertTrue(try repository.sources(forBookID: book.id).isEmpty)
    }
}
