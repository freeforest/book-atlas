import Foundation
import XCTest
@testable import BookAtlas

@MainActor
final class ManualRelationStoreTests: XCTestCase {
    func testCancelBeforeSaveNeverEntersWrite() async throws {
        let fixture = try makeSaveFixture()
        let store = fixture.store
        await prepareCreation(fixture)

        store.cancelCreate()

        XCTAssertFalse(store.isCreating)
        XCTAssertFalse(store.isSaving)
        XCTAssertEqual(store.statusMessage, "已取消新增关系；书库未更改。")
        let writes = await fixture.access.receivedWrites()
        let relations = try await fixture.catalog.manualRelationSummaries(for: fixture.source.id)
        XCTAssertTrue(writes.isEmpty)
        XCTAssertTrue(relations.isEmpty)
    }

    func testSuspendedSaveRejectsCancellationAndDraftMutation() async throws {
        let fixture = try makeSaveFixture()
        let store = fixture.store
        await prepareCreation(fixture)
        let originalTargets = store.targetBooks
        let save = Task { await store.saveCreation() }
        await fixture.access.waitForWriteEntered()

        store.cancelCreate()
        XCTAssertTrue(store.isCreating, "A submitted write cannot be cancelled by closing its editor")
        XCTAssertTrue(store.isSaving)
        XCTAssertNil(store.statusMessage, "A pending write must not claim the library was unchanged")

        store.beginCreate()
        store.updateTargetSearchText("replacement query", delay: nil)
        store.retryTargetSearch()
        store.loadMoreTargets()
        store.selectTarget(nil)
        store.selectTarget(fixture.other.id)
        store.selectFirstTargetFromKeyboard()
        store.setKind(.respondsTo)
        store.setNote("替换草稿备注")
        await store.waitForPendingWork()

        XCTAssertTrue(store.isCreating)
        XCTAssertTrue(store.isSaving)
        XCTAssertEqual(store.targetSearchText, "")
        XCTAssertEqual(store.targetBooks, originalTargets)
        XCTAssertEqual(store.selectedTargetID, fixture.target.id)
        XCTAssertEqual(store.selectedKind, .inspiredBy)
        XCTAssertEqual(store.relationNote, "固定虚构提交备注")
        XCTAssertNil(store.creationErrorMessage)
        let writes = await fixture.access.receivedWrites()
        XCTAssertEqual(writes.count, 1)
        XCTAssertEqual(writes.first?.targetBookID, fixture.target.id)
        XCTAssertEqual(writes.first?.kind, .inspiredBy)
        XCTAssertEqual(writes.first?.note, "固定虚构提交备注")

        await fixture.access.releaseWrite(success: true)
        let saved = await save.value
        XCTAssertTrue(saved)
        XCTAssertFalse(store.isCreating)
        XCTAssertEqual(store.outgoingRelations.count, 1)
    }

    func testSuspendedSaveRejectsDuplicateSubmissionAtStoreBoundary() async throws {
        let fixture = try makeSaveFixture()
        let store = fixture.store
        await prepareCreation(fixture)
        let firstSave = Task { await store.saveCreation() }
        await fixture.access.waitForWriteEntered()

        // The double rejects an unexpected second call immediately, so a broken
        // Store produces a deterministic failure instead of a hanging test.
        let duplicateSaved = await store.saveCreation()
        XCTAssertFalse(duplicateSaved)
        let writes = await fixture.access.receivedWrites()
        XCTAssertEqual(writes.count, 1)
        XCTAssertTrue(store.isCreating)
        XCTAssertTrue(store.isSaving)
        XCTAssertNil(store.creationErrorMessage)

        await fixture.access.releaseWrite(success: true)
        let saved = await firstSave.value
        XCTAssertTrue(saved)
        let persisted = try await fixture.catalog.manualRelationSummaries(for: fixture.source.id)
        XCTAssertEqual(persisted.count, 1)
    }

    func testSuccessfulWriteStillFinishesOnceWhenCallerTaskIsCancelled() async throws {
        let fixture = try makeSaveFixture()
        let store = fixture.store
        await prepareCreation(fixture)
        let revisionBefore = await fixture.catalog.graphContentRevision()
        let save = Task { await store.saveCreation() }
        await fixture.access.waitForWriteEntered()

        save.cancel()
        XCTAssertTrue(store.isSaving)
        await fixture.access.releaseWrite(success: true)
        let saved = await save.value

        XCTAssertTrue(saved, "Cancelling the caller is not rollback of a submitted database write")
        XCTAssertFalse(store.isCreating)
        XCTAssertFalse(store.isSaving)
        XCTAssertEqual(store.loadState, .content)
        XCTAssertEqual(store.statusMessage, "手动关系已保存。")
        let persisted = try await fixture.catalog.manualRelationSummaries(for: fixture.source.id)
        XCTAssertEqual(store.outgoingRelations, persisted)
        XCTAssertEqual(persisted.count, 1)
        let revisionAfter = await fixture.catalog.graphContentRevision()
        XCTAssertGreaterThan(revisionAfter, revisionBefore)
        let writes = await fixture.access.receivedWrites()
        XCTAssertEqual(writes.count, 1)
    }

    func testFailedWritePreservesDraftAndRestoresEditingAndCancellation() async throws {
        let fixture = try makeSaveFixture()
        let store = fixture.store
        await prepareCreation(fixture)
        let save = Task { await store.saveCreation() }
        await fixture.access.waitForWriteEntered()
        await fixture.access.releaseWrite(success: false)
        let saved = await save.value

        XCTAssertFalse(saved)
        XCTAssertTrue(store.isCreating)
        XCTAssertFalse(store.isSaving)
        XCTAssertEqual(store.selectedTargetID, fixture.target.id)
        XCTAssertEqual(store.selectedKind, .inspiredBy)
        XCTAssertEqual(store.relationNote, "固定虚构提交备注")
        let message = try XCTUnwrap(store.creationErrorMessage)
        XCTAssertFalse(message.contains("SQL"))
        XCTAssertFalse(message.contains(fixture.source.id.uuidString))
        XCTAssertFalse(message.contains("固定虚构提交备注"))
        XCTAssertFalse(message.contains("书库未更改"), "An unspecified write error is not proof of rollback")

        store.setKind(.companion)
        store.setNote("失败后仍可编辑")
        store.selectTarget(fixture.other.id)
        XCTAssertEqual(store.selectedKind, .companion)
        XCTAssertEqual(store.relationNote, "失败后仍可编辑")
        XCTAssertEqual(store.selectedTargetID, fixture.other.id)
        store.cancelCreate()
        XCTAssertFalse(store.isCreating)
        XCTAssertFalse(store.statusMessage?.contains("书库未更改") == true)
        let persisted = try await fixture.catalog.manualRelationSummaries(for: fixture.source.id)
        XCTAssertTrue(persisted.isEmpty)
    }

    func testLateWriteSuccessCannotReplaceDraftAfterContextChange() async throws {
        try await assertLateWritePreservesNewContext(success: true)
    }

    func testLateWriteFailureCannotReplaceDraftAfterContextChange() async throws {
        try await assertLateWritePreservesNewContext(success: false)
    }

    func testLateSaveRefreshCannotPublishIntoSameBookNewDraft() async throws {
        for reloadSameBook in [false, true] {
            let fixture = try makeSaveFixture()
            let store = fixture.store
            await prepareCreation(fixture)
            await fixture.access.holdNextRelationRead()
            let save = Task { await store.saveCreation() }
            await fixture.access.waitForWriteEntered()
            await fixture.access.releaseWrite(success: true)
            await fixture.access.waitForReadEntered()

            if reloadSameBook {
                store.load(bookID: fixture.source.id)
                await store.waitForPendingWork()
            }
            store.beginCreate()
            store.setNote("刷新期间建立的新草稿")
            // Do not waitForPendingWork here: the older refresh is deliberately held.
            await fixture.access.releaseRead()
            let saved = await save.value
            await store.waitForPendingWork()

            XCTAssertTrue(saved)
            XCTAssertTrue(store.isCreating)
            XCTAssertEqual(store.currentBookID, fixture.source.id)
            XCTAssertEqual(store.relationNote, "刷新期间建立的新草稿")
            XCTAssertNil(store.statusMessage, "An old refresh must not publish a success message in a new draft")
            XCTAssertNil(store.creationErrorMessage)
        }
    }

    private func assertLateWritePreservesNewContext(success: Bool) async throws {
        for transition in ["switch", "reset", "same-book"] {
            let fixture = try makeSaveFixture()
            let store = fixture.store
            await prepareCreation(fixture)
            let save = Task { await store.saveCreation() }
            await fixture.access.waitForWriteEntered()

            let newBookID = transition == "switch" ? fixture.other.id : fixture.source.id
            if transition == "reset" {
                store.reset()
                XCTAssertNil(store.currentBookID)
                XCTAssertTrue(store.allRelations.isEmpty)
            }
            store.load(bookID: newBookID)
            await store.waitForPendingWork()
            store.beginCreate()
            await store.waitForPendingWork()
            store.selectTarget(fixture.target.id)
            store.setKind(.companion)
            store.setNote("新上下文草稿")
            let relationsBefore = store.allRelations

            await fixture.access.releaseWrite(success: success)
            _ = await save.value

            XCTAssertEqual(store.currentBookID, newBookID)
            XCTAssertTrue(store.isCreating)
            XCTAssertFalse(store.isSaving)
            XCTAssertEqual(store.selectedTargetID, fixture.target.id)
            XCTAssertEqual(store.selectedKind, .companion)
            XCTAssertEqual(store.relationNote, "新上下文草稿")
            XCTAssertEqual(store.allRelations, relationsBefore)
            XCTAssertNil(store.creationErrorMessage)
            XCTAssertNil(store.statusMessage)
            let persisted = try await fixture.catalog.manualRelationSummaries(for: fixture.source.id)
            XCTAssertEqual(persisted.count, success ? 1 : 0)
        }
    }

    private func makeSaveFixture() throws -> ManualRelationSaveFixture {
        let repository = try BookRepository.inMemory()
        let books = try (1 ... 3).map { index in
            try repository.create(
                BookDraft(title: "《虚构保存生命周期 \(index)》", author: "虚构作者 \(index)"),
                id: UUID(uuidString: "30000000-0000-0000-0000-00000000000\(index)")!,
                at: FictionalLibraryFixtures.timestamp.addingTimeInterval(TimeInterval(index))
            )
        }
        let catalog = LibraryCatalogService(repository: repository)
        let access = ControlledManualRelationWriteAccess(catalog: catalog)
        return ManualRelationSaveFixture(
            source: books[0], target: books[1], other: books[2], catalog: catalog,
            access: access, store: ManualRelationStore(access: access)
        )
    }

    private func prepareCreation(_ fixture: ManualRelationSaveFixture) async {
        let store = fixture.store
        store.load(bookID: fixture.source.id)
        await store.waitForPendingWork()
        store.beginCreate()
        await store.waitForPendingWork()
        store.selectTarget(fixture.target.id)
        store.setKind(.inspiredBy)
        store.setNote("固定虚构提交备注")
    }

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

private struct ManualRelationSaveFixture {
    let source: Book
    let target: Book
    let other: Book
    let catalog: LibraryCatalogService
    let access: ControlledManualRelationWriteAccess
    let store: ManualRelationStore
}

/// Continuations are explicit entry/release handshakes. No sleep or scheduling
/// loop decides whether the write or the post-write refresh has started.
private actor ControlledManualRelationWriteAccess: ManualRelationAccessing {
    let catalog: LibraryCatalogService
    private var writes: [ManualBookRelation] = []
    private var pendingWrite: CheckedContinuation<Void, any Error>?
    private var writeEntered: CheckedContinuation<Void, Never>?
    private var shouldHoldNextRead = false
    private var pendingRead: CheckedContinuation<Void, Never>?
    private var readEntered: CheckedContinuation<Void, Never>?

    init(catalog: LibraryCatalogService) {
        self.catalog = catalog
    }

    func relations(for bookID: UUID) async throws -> [ManualRelationSummary] {
        let shouldHold = shouldHoldNextRead
        shouldHoldNextRead = false
        let snapshot = try await catalog.manualRelationSummaries(for: bookID)
        if shouldHold {
            await withCheckedContinuation { continuation in
                pendingRead = continuation
                readEntered?.resume()
                readEntered = nil
            }
        }
        return snapshot
    }

    func targetPage(matching query: LibraryQuery, excludingBookID: UUID) async throws -> LibraryPage {
        try await catalog.manualRelationTargetPage(query, excludingBookID: excludingBookID)
    }

    func add(_ relation: ManualBookRelation) async throws -> ManualBookRelation {
        writes.append(relation)
        guard writes.count == 1 else { throw CatalogServiceError.manualRelationConflict }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            pendingWrite = continuation
            writeEntered?.resume()
            writeEntered = nil
        }
        return try await catalog.addManualRelation(relation)
    }

    func delete(_ relation: ManualBookRelation) async throws {
        try await catalog.deleteManualRelation(relation)
    }

    func receivedWrites() -> [ManualBookRelation] { writes }

    func waitForWriteEntered() async {
        if pendingWrite != nil { return }
        await withCheckedContinuation { writeEntered = $0 }
    }

    func releaseWrite(success: Bool) {
        let continuation = pendingWrite
        pendingWrite = nil
        if success {
            continuation?.resume()
        } else {
            continuation?.resume(throwing: NSError(
                domain: "FictionalWriteFailure", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "SQL 固定虚构提交备注"]
            ))
        }
    }

    func holdNextRelationRead() { shouldHoldNextRead = true }

    func waitForReadEntered() async {
        if pendingRead != nil { return }
        await withCheckedContinuation { readEntered = $0 }
    }

    func releaseRead() {
        pendingRead?.resume()
        pendingRead = nil
    }
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
