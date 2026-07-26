import XCTest
@testable import BookAtlas

@MainActor
final class LibraryStoreTests: XCTestCase {
    func testStoreSelectsNewlyCreatedBookAndClearsSelectionAfterDelete() async throws {
        let repository = try BookRepository.inMemory()
        let store = LibraryStore(catalog: LibraryCatalogService(repository: repository))
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
