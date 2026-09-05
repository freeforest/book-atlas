import Foundation
import XCTest
@testable import BookAtlas

@MainActor
final class ManualRelationStoreTests: XCTestCase {
    func testSwitchingBookClearsImmediatelyAndRejectsLateSnapshot() async throws {
        let firstID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        let firstOtherID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
        let secondOtherID = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
        let access = DelayedManualRelationAccess()
        let store = ManualRelationStore(access: access)

        store.load(bookID: firstID)
        await waitUntil { await access.hasPendingRequest(for: firstID) }
        store.load(bookID: secondID)

        XCTAssertEqual(store.currentBookID, secondID)
        XCTAssertEqual(store.loadState, .loading)
        XCTAssertTrue(store.allRelations.isEmpty)
        await waitUntil { await access.hasPendingRequest(for: secondID) }

        await access.resume(
            bookID: secondID,
            with: [
                try makeSummary(
                    relationID: UUID(
                        uuidString: "10000000-0000-0000-0000-000000000102"
                    )!,
                    viewedBookID: secondID,
                    otherBookID: secondOtherID,
                    direction: .incoming,
                    title: "《新的关系快照》"
                )
            ]
        )
        await store.waitForPendingWork()
        XCTAssertEqual(store.incomingRelations.map(\.otherBookID), [secondOtherID])

        await access.resume(
            bookID: firstID,
            with: [
                try makeSummary(
                    relationID: UUID(
                        uuidString: "10000000-0000-0000-0000-000000000101"
                    )!,
                    viewedBookID: firstID,
                    otherBookID: firstOtherID,
                    direction: .outgoing,
                    title: "《迟到的旧快照》"
                )
            ]
        )
        for _ in 0 ..< 10 { await Task.yield() }

        XCTAssertEqual(store.currentBookID, secondID)
        XCTAssertEqual(store.incomingRelations.map(\.otherBookID), [secondOtherID])
        XCTAssertTrue(store.outgoingRelations.isEmpty)
    }

    func testCreateCancelConflictNavigateAndDeleteLifecycle() async throws {
        let repository = try BookRepository.inMemory()
        let source = try repository.create(
            BookDraft(title: "《关系闭环来源》", author: "虚构作者甲"),
            at: FictionalLibraryFixtures.timestamp
        )
        let target = try repository.create(
            BookDraft(title: "《关系闭环目标》", author: "虚构作者乙", isbn: "9780000001111"),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(1)
        )
        let catalog = LibraryCatalogService(repository: repository)
        let store = ManualRelationStore(catalog: catalog)

        store.load(bookID: source.id)
        await store.waitForPendingWork()
        XCTAssertEqual(store.loadState, .content)
        XCTAssertTrue(store.allRelations.isEmpty)

        store.beginCreate()
        await store.waitForPendingWork()
        store.cancelCreate()
        XCTAssertFalse(store.isCreating)
        let relationsAfterCreateCancellation = try await catalog.manualRelationSummaries(
            for: source.id
        )
        XCTAssertEqual(relationsAfterCreateCancellation, [])
        XCTAssertEqual(store.statusMessage, "已取消新增关系；书库未更改。")

        store.beginCreate()
        store.updateTargetSearchText("9780000001111", delay: nil)
        await store.waitForPendingWork()
        XCTAssertEqual(store.targetBooks.map(\.id), [target.id])
        store.selectFirstTargetFromKeyboard()
        XCTAssertEqual(store.selectedTargetID, target.id)
        store.updateTargetSearchText("9780000001111", delay: nil)
        XCTAssertEqual(
            store.selectedTargetID,
            target.id,
            "A same-value field commit must not clear the selected target"
        )
        store.setKind(.inspiredBy)
        store.setNote("固定虚构闭环备注")
        let beforeCreate = await catalog.graphContentRevision()

        let creationSucceeded = await store.saveCreation()
        XCTAssertTrue(creationSucceeded)
        let afterCreate = await catalog.graphContentRevision()
        XCTAssertGreaterThan(afterCreate, beforeCreate)
        XCTAssertEqual(store.outgoingRelations.count, 1)
        let created = try XCTUnwrap(store.outgoingRelations.first)
        XCTAssertEqual(created.otherBookID, target.id)
        XCTAssertEqual(created.relation.kind, .inspiredBy)
        XCTAssertEqual(created.relation.note, "固定虚构闭环备注")
        XCTAssertEqual(store.navigationTarget(for: created), target.id)

        store.beginCreate()
        store.updateTargetSearchText("关系闭环目标", delay: nil)
        await store.waitForPendingWork()
        store.selectTarget(target.id)
        store.setKind(.inspiredBy)
        let duplicateCreationSucceeded = await store.saveCreation()
        XCTAssertFalse(duplicateCreationSucceeded)
        XCTAssertEqual(
            store.creationErrorMessage,
            "相同方向和类型的关系已存在；书库未更改。"
        )
        let relationsAfterConflict = try await catalog.manualRelationSummaries(for: source.id)
        XCTAssertEqual(relationsAfterConflict.count, 1)
        store.cancelCreate()

        store.beginDelete(created)
        store.cancelDelete()
        let relationsAfterDeleteCancellation = try await catalog.manualRelationSummaries(
            for: source.id
        )
        XCTAssertEqual(relationsAfterDeleteCancellation.count, 1)

        store.beginDelete(created)
        let confirmedCandidate = try XCTUnwrap(store.deletionCandidate)
        store.cancelDelete()
        let beforeDelete = await catalog.graphContentRevision()
        let deletionSucceeded = await store.confirmDelete(confirmedCandidate)
        XCTAssertTrue(deletionSucceeded)
        let afterDelete = await catalog.graphContentRevision()
        XCTAssertGreaterThan(afterDelete, beforeDelete)
        XCTAssertTrue(store.allRelations.isEmpty)
        let sourceResult = try await catalog.queryBookPage(
            LibraryQuery(),
            focusedBookID: source.id
        )
        let targetResult = try await catalog.queryBookPage(
            LibraryQuery(),
            focusedBookID: target.id
        )
        XCTAssertEqual(sourceResult.focusedBook, source)
        XCTAssertEqual(targetResult.focusedBook, target)
    }

    func testTargetSearchUsesBoundedPagesAndNeverIncludesSource() async throws {
        let repository = try BookRepository.inMemory()
        let source = try repository.create(
            BookDraft(title: "《分页关系来源》", author: "虚构分页作者"),
            at: FictionalLibraryFixtures.timestamp
        )
        var expectedTargetIDs: [UUID] = []
        for index in 0 ..< 201 {
            let target = try repository.create(
                BookDraft(
                    title: String(format: "《分页关系目标 %03d》", index),
                    author: "虚构分页作者 \(index % 9)"
                ),
                id: UUID(
                    uuidString: String(
                        format: "20000000-0000-0000-0000-%012d",
                        index
                    )
                )!,
                at: FictionalLibraryFixtures.timestamp.addingTimeInterval(
                    TimeInterval(index + 1)
                )
            )
            expectedTargetIDs.append(target.id)
        }
        let catalog = LibraryCatalogService(repository: repository)
        let store = ManualRelationStore(catalog: catalog)
        store.load(bookID: source.id)
        await store.waitForPendingWork()

        store.beginCreate()
        await store.waitForPendingWork()
        XCTAssertEqual(store.targetBooks.count, LibraryQuery.defaultPageSize)
        XCTAssertEqual(store.targetTotalCount, 201)
        XCTAssertTrue(store.hasMoreTargets)
        XCTAssertFalse(store.targetBooks.contains { $0.id == source.id })

        store.loadMoreTargets()
        await store.waitForPendingWork()
        XCTAssertEqual(store.targetBooks.count, 201)
        XCTAssertEqual(Set(store.targetBooks.map(\.id)), Set(expectedTargetIDs))
        XCTAssertFalse(store.hasMoreTargets)
    }

    func testReadAndMissingDeleteFailuresUseSafeFeatureMessages() async throws {
        let unavailable = ManualRelationStore(access: FailingManualRelationAccess())
        unavailable.load(bookID: UUID())
        await unavailable.waitForPendingWork()
        XCTAssertEqual(unavailable.loadState, .failed)
        XCTAssertTrue(unavailable.allRelations.isEmpty)

        let repository = try BookRepository.inMemory()
        let source = try repository.create(
            BookDraft(title: "《失效关系来源》", author: "虚构作者甲")
        )
        let target = try repository.create(
            BookDraft(title: "《失效关系目标》", author: "虚构作者乙")
        )
        let relation = try repository.addManualRelation(
            ManualBookRelation(
                sourceBookID: source.id,
                targetBookID: target.id,
                kind: .related
            )
        )
        let catalog = LibraryCatalogService(repository: repository)
        let store = ManualRelationStore(catalog: catalog)
        store.load(bookID: source.id)
        await store.waitForPendingWork()
        let summary = try XCTUnwrap(store.outgoingRelations.first)

        try await catalog.deleteManualRelation(relation)
        store.beginDelete(summary)
        let deletionSucceeded = await store.confirmDelete()
        XCTAssertFalse(deletionSucceeded)
        XCTAssertEqual(
            store.deletionErrorMessage,
            "该关系已不存在；两本书均未更改。"
        )
        let sourceResult = try await catalog.queryBookPage(
            LibraryQuery(),
            focusedBookID: source.id
        )
        let targetResult = try await catalog.queryBookPage(
            LibraryQuery(),
            focusedBookID: target.id
        )
        XCTAssertNotNil(sourceResult.focusedBook)
        XCTAssertNotNil(targetResult.focusedBook)
    }

    private func waitUntil(
        _ condition: @escaping @Sendable () async -> Bool
    ) async {
        for _ in 0 ..< 1_000 {
            if await condition() { return }
            await Task.yield()
        }
        XCTFail("Timed out waiting for the controlled relation request")
    }
}

private enum ManualRelationAccessStubError: Error {
    case unavailable
}

private actor DelayedManualRelationAccess: ManualRelationAccessing {
    private var continuations: [
        UUID: CheckedContinuation<[ManualRelationSummary], any Error>
    ] = [:]

    func relations(for bookID: UUID) async throws -> [ManualRelationSummary] {
        try await withCheckedThrowingContinuation { continuation in
            continuations[bookID] = continuation
        }
    }

    func targetPage(
        matching query: LibraryQuery,
        excludingBookID: UUID
    ) async throws -> LibraryPage {
        throw ManualRelationAccessStubError.unavailable
    }

    func add(_ relation: ManualBookRelation) async throws -> ManualBookRelation {
        throw ManualRelationAccessStubError.unavailable
    }

    func delete(_ relation: ManualBookRelation) async throws {
        throw ManualRelationAccessStubError.unavailable
    }

    func hasPendingRequest(for bookID: UUID) -> Bool {
        continuations[bookID] != nil
    }

    func resume(bookID: UUID, with relations: [ManualRelationSummary]) {
        continuations.removeValue(forKey: bookID)?.resume(returning: relations)
    }
}

private struct FailingManualRelationAccess: ManualRelationAccessing {
    func relations(for bookID: UUID) async throws -> [ManualRelationSummary] {
        throw ManualRelationAccessStubError.unavailable
    }

    func targetPage(
        matching query: LibraryQuery,
        excludingBookID: UUID
    ) async throws -> LibraryPage {
        throw ManualRelationAccessStubError.unavailable
    }

    func add(_ relation: ManualBookRelation) async throws -> ManualBookRelation {
        throw ManualRelationAccessStubError.unavailable
    }

    func delete(_ relation: ManualBookRelation) async throws {
        throw ManualRelationAccessStubError.unavailable
    }
}

private func makeSummary(
    relationID: UUID,
    viewedBookID: UUID,
    otherBookID: UUID,
    direction: ManualRelationDirection,
    title: String
) throws -> ManualRelationSummary {
    let sourceID = direction == .outgoing ? viewedBookID : otherBookID
    let targetID = direction == .outgoing ? otherBookID : viewedBookID
    return ManualRelationSummary(
        relation: try ManualBookRelation(
            id: relationID,
            sourceBookID: sourceID,
            targetBookID: targetID,
            kind: .related,
            createdAt: FictionalLibraryFixtures.timestamp
        ),
        otherBookID: otherBookID,
        otherBookTitle: title,
        otherBookAuthor: "固定虚构作者",
        direction: direction
    )
}
