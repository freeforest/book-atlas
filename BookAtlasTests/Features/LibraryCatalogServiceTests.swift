import XCTest
@testable import BookAtlas

final class LibraryCatalogServiceTests: XCTestCase {
    func testCreateAndUpdatePersistNormalizedValuesAndModificationTime() async throws {
        let repository = try BookRepository.inMemory()
        let clock = TestClock(date: FictionalLibraryFixtures.timestamp)
        let service = LibraryCatalogService(repository: repository, now: clock.now)

        let created = try await service.createBook(
            from: BookEditorDraft(
                title: "《北岸来信》",
                author: "许岸",
                isbn: "978 - 0  - 0000 0000 - 0"
            )
        )
        XCTAssertEqual(created.isbn, "9780000000000")
        XCTAssertEqual(created.createdAt, clock.now())

        clock.advance(by: 90)
        let updated = try await service.updateBook(
            created,
            from: BookEditorDraft(title: "《北岸来信：增订版》", author: "许岸", readingStatus: .read)
        )
        XCTAssertEqual(updated.createdAt, created.createdAt)
        XCTAssertEqual(updated.updatedAt, clock.now())
        let queried = try await service.queryBooks(LibraryQuery())
        XCTAssertEqual(queried, [updated])
    }

    func testDeletingOrUpdatingMissingBookReportsRepositoryFailure() async throws {
        let repository = try BookRepository.inMemory()
        let service = LibraryCatalogService(repository: repository)
        let missing = try Book(draft: FictionalLibraryFixtures.draft(), createdAt: FictionalLibraryFixtures.timestamp)

        do {
            try await service.deleteBook(missing)
            XCTFail("Expected delete to fail")
        } catch {
            XCTAssertEqual(error as? BookRepositoryError, .bookNotFound)
        }
        do {
            _ = try await service.updateBook(missing, from: BookEditorDraft(book: missing))
            XCTFail("Expected update to fail")
        } catch {
            XCTAssertEqual(error as? BookRepositoryError, .bookNotFound)
        }
    }
}

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date

    init(date: Date) {
        self.date = date
    }

    func now() -> Date {
        lock.withLock { date }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock {
            date = date.addingTimeInterval(interval)
        }
    }
}
