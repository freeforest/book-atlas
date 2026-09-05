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

    func testManualRelationCatalogMapsConflictsAndMissingEntitiesWithoutPayloads() async throws {
        let repository = try BookRepository.inMemory()
        let service = LibraryCatalogService(repository: repository)
        let source = try await service.createBook(
            from: BookEditorDraft(title: "《目录关系来源》", author: "虚构作者甲")
        )
        let target = try await service.createBook(
            from: BookEditorDraft(title: "《目录关系目标》", author: "虚构作者乙")
        )
        let initialRevision = await service.graphContentRevision()
        let relation = try ManualBookRelation(
            sourceBookID: source.id,
            targetBookID: target.id,
            kind: .companion,
            note: "固定虚构目录关系备注",
            createdAt: FictionalLibraryFixtures.timestamp
        )

        _ = try await service.addManualRelation(relation)
        let addedRevision = await service.graphContentRevision()
        XCTAssertGreaterThan(addedRevision, initialRevision)
        let summaries = try await service.manualRelationSummaries(for: source.id)
        XCTAssertEqual(summaries.map(\.otherBookID), [target.id])
        XCTAssertEqual(summaries.map(\.direction), [.outgoing])

        do {
            _ = try await service.addManualRelation(
                ManualBookRelation(
                    sourceBookID: source.id,
                    targetBookID: target.id,
                    kind: .companion,
                    createdAt: FictionalLibraryFixtures.timestamp
                )
            )
            XCTFail("Expected a safe relation conflict")
        } catch {
            XCTAssertEqual(error as? CatalogServiceError, .manualRelationConflict)
        }
        let revisionAfterConflict = await service.graphContentRevision()
        XCTAssertEqual(revisionAfterConflict, addedRevision)

        do {
            _ = try await service.addManualRelation(
                ManualBookRelation(
                    sourceBookID: source.id,
                    targetBookID: UUID(),
                    kind: .related,
                    createdAt: FictionalLibraryFixtures.timestamp
                )
            )
            XCTFail("Expected a safe missing endpoint error")
        } catch {
            XCTAssertEqual(error as? CatalogServiceError, .manualRelationEndpointMissing)
        }

        try await service.deleteManualRelation(relation)
        let deletedRevision = await service.graphContentRevision()
        XCTAssertGreaterThan(deletedRevision, addedRevision)
        let sourcePage = try await service.queryBookPage(
            LibraryQuery(),
            focusedBookID: source.id
        )
        let targetPage = try await service.queryBookPage(
            LibraryQuery(),
            focusedBookID: target.id
        )
        XCTAssertNotNil(sourcePage.focusedBook)
        XCTAssertNotNil(targetPage.focusedBook)

        do {
            try await service.deleteManualRelation(relation)
            XCTFail("Expected a safe missing relation error")
        } catch {
            XCTAssertEqual(error as? CatalogServiceError, .manualRelationNotFound)
        }
        let revisionAfterMissingDelete = await service.graphContentRevision()
        XCTAssertEqual(revisionAfterMissingDelete, deletedRevision)
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
