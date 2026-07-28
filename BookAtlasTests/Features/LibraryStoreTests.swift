import XCTest
@testable import BookAtlas

@MainActor
final class LibraryStoreTests: XCTestCase {
    func testStoreSelectsNewlyCreatedBookAndClearsSelectionAfterDelete() async throws {
        let repository = try BookRepository.inMemory()
        let service = LibraryCatalogService(repository: repository)
        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()

        store.beginCreate()
        let session = try XCTUnwrap(store.editorSession)
        guard case .success = await store.save(
            BookEditorDraft(title: "《雾港档案》", author: "林雾"),
            for: session
        ) else {
            return XCTFail("Expected book creation to succeed")
        }
        XCTAssertEqual(store.books.count, 1)
        XCTAssertEqual(store.selectedBook?.title, "《雾港档案》")

        store.beginDelete()
        store.confirmDelete()
        await store.waitForPendingWork()
        XCTAssertTrue(store.books.isEmpty)
        XCTAssertNil(store.selectedBookID)
    }

    func testValidationFailureKeepsEditorSessionAndDraftAvailable() async throws {
        let repository = try BookRepository.inMemory()
        let store = LibraryStore(catalog: LibraryCatalogService(repository: repository))
        await store.waitForPendingWork()
        store.beginCreate()
        let session = try XCTUnwrap(store.editorSession)

        guard case let .failure(error) = await store.save(
            BookEditorDraft(title: " ", author: "林雾"),
            for: session
        ) else {
            return XCTFail("Expected validation failure")
        }
        XCTAssertEqual(error, .validation(.titleRequired))
        XCTAssertNotNil(store.editorSession)
        XCTAssertTrue(store.books.isEmpty)
    }

    func testLoadAndDeleteFailuresAreMappedWithoutPrivateDetails() async throws {
        let book = try Book(draft: FictionalLibraryFixtures.draft(), createdAt: FictionalLibraryFixtures.timestamp)
        let failingCatalog = FailingCatalog(books: [book])
        let store = LibraryStore(catalog: failingCatalog)

        await store.waitForPendingWork()
        XCTAssertEqual(store.loadingState, .failed(.loadFailed))

        let deleteFailingCatalog = FailingCatalog(books: [book], failsOnLoad: false)
        let deleteStore = LibraryStore(catalog: deleteFailingCatalog)
        await deleteStore.waitForPendingWork()
        deleteStore.beginDelete()
        deleteStore.confirmDelete()
        await deleteStore.waitForPendingWork()
        XCTAssertEqual(deleteStore.operationError, .deleteFailed)
    }

    func testCatalogChangesCleanDeletedFiltersAndReplaceMergedTag() async throws {
        let repository = try BookRepository.inMemory()
        let service = LibraryCatalogService(
            repository: repository,
            now: { FictionalLibraryFixtures.timestamp }
        )
        let book = try await service.createBook(
            from: BookEditorDraft(title: "F606", author: "AuthorF")
        )
        let sourceTag = try await service.createTag(name: "SourceFilter")
        let targetTag = try await service.createTag(name: "TargetFilter")
        let collection = try await service.createCollection(name: "FilterShelf", description: nil)
        let source = try await service.createSource(name: "FilterSignal", details: nil)
        try await service.setAssociation(.tag(sourceTag.id), included: true, bookID: book.id)
        try await service.setAssociation(.collection(collection.id), included: true, bookID: book.id)
        try await service.setAssociation(.source(source.id), included: true, bookID: book.id)

        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()
        store.toggleTag(sourceTag.id)
        store.toggleCollection(collection.id)
        store.toggleSource(source.id)
        await store.waitForPendingWork()
        XCTAssertEqual(store.books.map(\.id), [book.id])

        try await service.mergeTag(sourceTag, into: targetTag)
        store.catalogDidMergeTag(sourceTag.id, into: targetTag.id)
        await store.waitForPendingWork()
        XCTAssertEqual(store.query.tagIDs, [targetTag.id])

        try await service.deleteCollection(collection)
        store.catalogDidDeleteCollection(collection.id)
        try await service.deleteSource(source)
        store.catalogDidDeleteSource(source.id)
        try await service.deleteTag(targetTag)
        store.catalogDidDeleteTag(targetTag.id)
        await store.waitForPendingWork()

        XCTAssertFalse(store.hasActiveFilters)
        XCTAssertEqual(store.books.map(\.id), [book.id])
    }

    func testCreateSaveRequiresReviewAndCancellationDoesNotChangeLibrary() async throws {
        let repository = try BookRepository.inMemory()
        let existing = try repository.create(
            BookDraft(title: "《雾港档案》", author: "林雾"),
            at: FictionalLibraryFixtures.timestamp
        )
        let service = LibraryCatalogService(repository: repository)
        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()
        store.beginCreate()
        let session = try XCTUnwrap(store.editorSession)

        guard case .success = await store.save(
            BookEditorDraft(title: "雾港档案", author: "林雾"),
            for: session
        ) else {
            return XCTFail("Expected save interception to present review")
        }
        XCTAssertEqual(store.duplicateReview?.candidates.map(\.id), [existing.id])
        XCTAssertNotNil(store.editorSession)
        let booksBeforeCancel = try await service.queryBooks(LibraryQuery())
        XCTAssertEqual(booksBeforeCancel.count, 1)

        store.cancelDuplicateReview()
        XCTAssertNil(store.duplicateReview)
        XCTAssertNotNil(store.editorSession)
        let booksAfterCancel = try await service.queryBooks(LibraryQuery())
        XCTAssertEqual(booksAfterCancel.count, 1)
    }

    func testKeepingNewCandidateAsSeparateEditionPersistsDecisionAndClosesEditor() async throws {
        let repository = try BookRepository.inMemory()
        let existing = try repository.create(
            BookDraft(title: "《玻璃港》", author: "林雾"),
            at: FictionalLibraryFixtures.timestamp
        )
        let service = LibraryCatalogService(repository: repository)
        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()
        store.beginCreate()
        let session = try XCTUnwrap(store.editorSession)
        _ = await store.save(
            BookEditorDraft(title: "玻璃港", author: "林雾"),
            for: session
        )

        store.keepSelectedDuplicateIndependent(as: .separateEdition)
        await store.waitForPendingWork()

        XCTAssertNil(store.editorSession)
        XCTAssertNil(store.duplicateReview)
        XCTAssertEqual(store.books.count, 2)
        let created = try XCTUnwrap(store.books.first { $0.id != existing.id })
        let candidates = try await service.duplicateCandidates(for: created, includingPossible: true)
        XCTAssertTrue(candidates.isEmpty)
    }

    func testKeepingOneOfThreeCandidatesCreatesOnceAndLeavesOtherPairsForReview() async throws {
        let repository = try BookRepository.inMemory()
        let candidateIDs = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000311")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000312")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000313")!
        ]
        for id in candidateIDs {
            _ = try repository.create(
                BookDraft(title: "《三重港湾》", author: "林雾"),
                id: id,
                at: FictionalLibraryFixtures.timestamp
            )
        }
        let service = LibraryCatalogService(repository: repository)
        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()
        store.beginCreate()
        let session = try XCTUnwrap(store.editorSession)
        _ = await store.save(
            BookEditorDraft(title: "三重港湾", author: "林雾"),
            for: session
        )
        XCTAssertEqual(Set(try XCTUnwrap(store.duplicateReview).candidates.map(\.id)), Set(candidateIDs))

        store.selectedDuplicateID = candidateIDs[1]
        store.keepSelectedDuplicateIndependent(as: .separateTranslation)
        await store.waitForPendingWork()

        XCTAssertNotNil(store.selectedBook)
        XCTAssertEqual(store.books.count, 4)
        XCTAssertNil(store.editorSession)
        XCTAssertEqual(store.duplicateReview?.origin, .createdBookContinuation)
        XCTAssertEqual(
            Set(try XCTUnwrap(store.duplicateReview).candidates.map(\.id)),
            Set([candidateIDs[0], candidateIDs[2]])
        )
        XCTAssertFalse(try XCTUnwrap(store.duplicateReview).candidates.map(\.id).contains(candidateIDs[1]))

        store.selectedDuplicateID = candidateIDs[0]
        store.keepSelectedDuplicateIndependent(as: .notDuplicate)
        await store.waitForPendingWork()

        XCTAssertEqual(store.books.count, 4, "Continuing review must not create the draft again")
        XCTAssertEqual(store.duplicateReview?.candidates.map(\.id), [candidateIDs[2]])
        XCTAssertFalse(try XCTUnwrap(store.duplicateReview).candidates.map(\.id).contains(candidateIDs[0]))
    }

    func testViewingExistingCandidateKeepsDraftAndReturnsToSameReview() async throws {
        let repository = try BookRepository.inMemory()
        let existing = try repository.create(
            BookDraft(title: "《可返回的灯塔》", author: "沈遥"),
            at: FictionalLibraryFixtures.timestamp
        )
        let store = LibraryStore(catalog: LibraryCatalogService(repository: repository))
        await store.waitForPendingWork()
        store.beginCreate()
        let session = try XCTUnwrap(store.editorSession)
        let draft = BookEditorDraft(
            title: "可返回的灯塔",
            author: "沈遥",
            note: "固定虚构草稿内容"
        )
        _ = await store.save(draft, for: session)
        let reviewID = try XCTUnwrap(store.duplicateReview?.id)

        store.viewSelectedDuplicate()

        XCTAssertEqual(store.viewedDuplicateBook, existing)
        XCTAssertEqual(store.editorSession?.id, session.id)
        XCTAssertEqual(store.duplicateReview?.id, reviewID)

        store.returnFromViewedDuplicate()

        XCTAssertNil(store.viewedDuplicateBook)
        XCTAssertEqual(store.editorSession?.id, session.id)
        XCTAssertEqual(store.duplicateReview?.id, reviewID)
        XCTAssertEqual(store.duplicateReview?.candidates.map(\.id), [existing.id])
    }
}

private actor FailingCatalog: LibraryCataloging {
    private let books: [Book]
    private let failsOnLoad: Bool

    init(books: [Book], failsOnLoad: Bool = true) {
        self.books = books
        self.failsOnLoad = failsOnLoad
    }

    func queryBooks(_ query: LibraryQuery) throws -> [Book] {
        if failsOnLoad {
            throw TestFailure.failed
        }
        return books
    }

    func createBook(from editor: BookEditorDraft) throws -> Book {
        throw TestFailure.failed
    }

    func updateBook(_ book: Book, from editor: BookEditorDraft) throws -> Book {
        throw TestFailure.failed
    }

    func deleteBook(_ book: Book) throws {
        throw TestFailure.failed
    }

    private enum TestFailure: Error {
        case failed
    }
}
