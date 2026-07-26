import XCTest
@testable import BookAtlas

final class LibraryCatalogServiceTests: XCTestCase {
    func testCreateAndUpdatePersistNormalizedValuesAndModificationTime() throws {
        let repository = try BookRepository.inMemory()
        var currentDate = FictionalLibraryFixtures.timestamp
        let service = LibraryCatalogService(repository: repository, now: { currentDate })

        let created = try service.createBook(
            from: BookEditorDraft(
                title: "《北岸来信》",
                author: "许岸",
                isbn: "978 - 0  - 0000 0000 - 0"
            )
        )
        XCTAssertEqual(created.isbn, "9780000000000")
        XCTAssertEqual(created.createdAt, currentDate)

        currentDate = currentDate.addingTimeInterval(90)
        let updated = try service.updateBook(
            created,
            from: BookEditorDraft(title: "《北岸来信：增订版》", author: "许岸", readingStatus: .read)
        )
        XCTAssertEqual(updated.createdAt, created.createdAt)
        XCTAssertEqual(updated.updatedAt, currentDate)
        XCTAssertEqual(try repository.book(id: created.id), updated)
    }

    func testDeletingOrUpdatingMissingBookReportsRepositoryFailure() throws {
        let repository = try BookRepository.inMemory()
        let service = LibraryCatalogService(repository: repository)
        let missing = try Book(draft: FictionalLibraryFixtures.draft(), createdAt: FictionalLibraryFixtures.timestamp)

        XCTAssertThrowsError(try service.deleteBook(missing)) { error in
            XCTAssertEqual(error as? BookRepositoryError, .bookNotFound)
        }
        XCTAssertThrowsError(try service.updateBook(missing, from: BookEditorDraft(book: missing))) { error in
            XCTAssertEqual(error as? BookRepositoryError, .bookNotFound)
        }
    }
}
