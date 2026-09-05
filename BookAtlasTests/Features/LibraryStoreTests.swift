import Combine
import XCTest
@testable import BookAtlas

@MainActor
final class LibraryStoreTests: XCTestCase {
    func testSuspendedRelationSwitchRejectsInvalidCombinationsBeforeDatabaseResolution() {
        let flag = "-BookAtlasSuspendManualRelationSave"
        let combinations = [
            [flag],
            [flag, "-BookAtlasPerformanceUseExistingLibrary", "00000000-0000-0000-0000-000000000909"],
            [flag, "-BookAtlasUseInMemoryStore", "-BookAtlasPerformanceUseExistingLibrary", "00000000-0000-0000-0000-000000000909"],
            [flag, "-BookAtlasUseInMemoryStore", "-BookAtlasPerformanceUnknown"]
        ]
        for arguments in combinations {
            var resolvedProduction = false
            let store = LibraryStore.makeApplicationStore(
                arguments: arguments,
                environment: ["XCTestConfigurationFilePath": "fictional-test-environment"],
                productionDatabaseURL: {
                    resolvedProduction = true
                    throw PerformanceLibraryError.unsafeTemporaryLocation
                }
            )
            XCTAssertFalse(resolvedProduction)
            XCTAssertEqual(store.loadingState, .failed(.databaseUnavailable))
        }
    }

    func testSuspendedRelationSwitchAllowsOnlyExplicitMemoryFixture() async throws {
        var resolvedProduction = false
        let store = LibraryStore.makeApplicationStore(
            arguments: ["-BookAtlasUseInMemoryStore", "-BookAtlasSuspendManualRelationSave", "-BookAtlasSeedManualRelationUITestData"],
            environment: [:],
            productionDatabaseURL: {
                resolvedProduction = true
                throw PerformanceLibraryError.unsafeTemporaryLocation
            }
        )
        await store.waitForPendingWork()
        XCTAssertFalse(resolvedProduction)
        XCTAssertEqual(store.loadingState, .content)
        XCTAssertEqual(store.selectedBookID, UUID(uuidString: "00000000-0000-0000-0000-000000000101"))
        let sourceID = try XCTUnwrap(store.selectedBookID)
        store.manualRelations.load(bookID: sourceID)
        await store.manualRelations.waitForPendingWork()
        XCTAssertEqual(store.manualRelations.currentBookID, sourceID)
        XCTAssertEqual(store.manualRelations.loadState, .content)
    }

    func testDefaultApplicationPathStillUsesProvidedTemporaryDatabaseAndRealRelationAccess() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("fictional.sqlite")
        let repository = try BookRepository(databaseURL: url)
        let source = try repository.create(BookDraft(title: "Fictional source", author: "Fictional author"))
        let target = try repository.create(BookDraft(title: "Fictional target", author: "Fictional writer"))
        var resolutionCount = 0
        let store = LibraryStore.makeApplicationStore(arguments: [], environment: [:], productionDatabaseURL: {
            resolutionCount += 1
            return url
        })
        await store.waitForPendingWork()
        XCTAssertEqual(resolutionCount, 1)
        store.manualRelations.load(bookID: source.id)
        await store.manualRelations.waitForPendingWork()
        store.manualRelations.beginCreate()
        await store.manualRelations.waitForPendingWork()
        store.manualRelations.selectTarget(target.id)
        let saved = await store.manualRelations.saveCreation()
        XCTAssertTrue(saved)
        XCTAssertEqual(store.manualRelations.outgoingRelations.count, 1)
    }

    #if DEBUG
    func testSuspendedRelationAccessHandshakeReleaseAndCancellationNeverWrite() async throws {
        let repository = try BookRepository.inMemory()
        let source = try repository.create(BookDraft(title: "Fictional source", author: "Fictional author"))
        let target = try repository.create(BookDraft(title: "Fictional target", author: "Fictional writer"))
        let catalog = LibraryCatalogService(repository: repository)
        let access = SuspendedUITestManualRelationAccess(catalog: catalog)
        let store = LibraryStore(catalog: catalog, manualRelations: ManualRelationStore(access: access))
        await store.waitForPendingWork()
        store.manualRelations.load(bookID: source.id)
        await store.manualRelations.waitForPendingWork()
        store.manualRelations.beginCreate()
        await store.manualRelations.waitForPendingWork()
        store.manualRelations.selectTarget(target.id)
        let first = Task { await store.manualRelations.saveCreation() }
        await access.waitUntilSubmitted()
        XCTAssertTrue(store.manualRelations.isSaving)
        let before = try await catalog.manualRelationSummaries(for: source.id)
        XCTAssertTrue(before.isEmpty)
        await access.finishWithoutWriting()
        let firstResult = await first.value
        XCTAssertFalse(firstResult)
        XCTAssertFalse(store.manualRelations.isSaving)
        let second = Task { await store.manualRelations.saveCreation() }
        await access.waitUntilSubmitted()
        second.cancel()
        let secondResult = await second.value
        XCTAssertFalse(secondResult)
        XCTAssertFalse(store.manualRelations.isSaving)
        let count = await access.submissionCount
        XCTAssertEqual(count, 2)
        let after = try await catalog.manualRelationSummaries(for: source.id)
        XCTAssertTrue(after.isEmpty)
        store.manualRelations.cancelCreate()
        XCTAssertFalse(store.manualRelations.isCreating)
    }
    #endif

    func testListSelectionStateSynchronizesProgrammaticSelectionAndCoalescesRapidInput() {
        let first = UUID(uuidString: "56000000-0000-0000-0000-000000000001")!
        let second = UUID(uuidString: "56000000-0000-0000-0000-000000000002")!
        let programmatic = UUID(uuidString: "56000000-0000-0000-0000-000000000003")!
        let laterProgrammatic = UUID(uuidString: "56000000-0000-0000-0000-000000000004")!
        var state = LibraryListSelectionState()

        state.synchronizeFromStore(programmatic)
        XCTAssertEqual(state.selectedBookID, programmatic)
        XCTAssertEqual(state.source, .store)

        state.selectFromList(first)
        let supersededGeneration = state.generation
        state.selectFromList(first)
        state.selectFromList(second)
        XCTAssertEqual(state.selectedBookID, second)
        XCTAssertEqual(state.source, .list)
        XCTAssertGreaterThan(state.generation, supersededGeneration)
        XCTAssertEqual(state.generation, 3)

        state.synchronizeFromStore(laterProgrammatic)
        XCTAssertEqual(state.selectedBookID, laterProgrammatic)
        XCTAssertEqual(state.source, .store)
        XCTAssertEqual(state.generation, 4)
    }

    func testSelectingCurrentInPageIdentityDoesNotPublishWhenFocusAndIssueAreNil() async throws {
        let (service, _) = try await makePagedCatalog()
        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()
        let selectedBook = try XCTUnwrap(store.selectedBook)
        XCTAssertNil(store.pinnedFocusedBook)
        XCTAssertNil(store.selectionIssue)

        var publicationCount = 0
        let observation = store.objectWillChange.sink {
            publicationCount += 1
        }
        defer { observation.cancel() }

        store.selectBook(selectedBook.id)

        XCTAssertEqual(publicationCount, 0)
        XCTAssertEqual(store.selectedBookID, selectedBook.id)
        XCTAssertEqual(store.selectedBook?.id, selectedBook.id)
        XCTAssertNil(store.pinnedFocusedBook)
        XCTAssertNil(store.selectionIssue)
    }

    func testSelectingNilFromEmptySelectionDoesNotPublish() async throws {
        let repository = try BookRepository.inMemory()
        let store = LibraryStore(
            catalog: LibraryCatalogService(repository: repository)
        )
        await store.waitForPendingWork()
        XCTAssertNil(store.selectedBookID)
        XCTAssertNil(store.selectedBook)
        XCTAssertNil(store.pinnedFocusedBook)
        XCTAssertNil(store.selectionIssue)

        var publicationCount = 0
        let observation = store.objectWillChange.sink {
            publicationCount += 1
        }
        defer { observation.cancel() }

        store.selectBook(nil)

        XCTAssertEqual(publicationCount, 0)
        XCTAssertNil(store.selectedBookID)
        XCTAssertNil(store.selectedBook)
        XCTAssertNil(store.pinnedFocusedBook)
        XCTAssertNil(store.selectionIssue)
    }

    func testSelectingDifferentIdentityClearsExistingFocusedBook() async throws {
        let (service, seededBooks) = try await makePagedCatalog()
        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()
        let focusedTarget = seededBooks[42]
        let inPageTarget = try XCTUnwrap(store.books.first)
        store.focusBook(focusedTarget.id)
        await store.waitForPendingWork()
        XCTAssertEqual(store.pinnedFocusedBook?.id, focusedTarget.id)

        store.selectBook(inPageTarget.id)

        XCTAssertEqual(store.selectedBookID, inPageTarget.id)
        XCTAssertEqual(store.selectedBook?.id, inPageTarget.id)
        XCTAssertNil(store.pinnedFocusedBook)
        XCTAssertNil(store.selectionIssue)
    }

    func testSelectingNilClearsExistingFocusedBook() async throws {
        let (service, seededBooks) = try await makePagedCatalog()
        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()
        let focusedTarget = seededBooks[42]
        store.focusBook(focusedTarget.id)
        await store.waitForPendingWork()
        XCTAssertEqual(store.pinnedFocusedBook?.id, focusedTarget.id)

        store.selectBook(nil)

        XCTAssertNil(store.selectedBookID)
        XCTAssertNil(store.selectedBook)
        XCTAssertNil(store.pinnedFocusedBook)
        XCTAssertNil(store.selectionIssue)
    }

    func testSelectingMatchingFocusedIdentityIsIdempotentAndPreservesFocus() async throws {
        let (service, seededBooks) = try await makePagedCatalog()
        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()
        let target = seededBooks[42]
        store.focusBook(target.id)
        await store.waitForPendingWork()
        XCTAssertEqual(store.pinnedFocusedBook?.id, target.id)

        var publicationCount = 0
        let observation = store.objectWillChange.sink {
            publicationCount += 1
        }
        defer { observation.cancel() }

        store.selectBook(target.id)

        XCTAssertEqual(publicationCount, 0)
        XCTAssertEqual(store.selectedBookID, target.id)
        XCTAssertEqual(store.selectedBook?.id, target.id)
        XCTAssertEqual(store.pinnedFocusedBook?.id, target.id)
        XCTAssertNil(store.selectionIssue)
    }

    func testSelectingDifferentIdentityClearsMismatchAndRecoverableIssue() async throws {
        let (service, seededBooks) = try await makePagedCatalog()
        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()
        let target = seededBooks[42]
        let ordinaryBook = try XCTUnwrap(store.books.first)

        store.focusBook(target.id)
        await store.waitForPendingWork()
        XCTAssertEqual(store.pinnedFocusedBook?.id, target.id)

        store.selectBook(ordinaryBook.id)
        XCTAssertEqual(store.selectedBookID, ordinaryBook.id)
        XCTAssertNil(store.pinnedFocusedBook)
        XCTAssertNil(store.selectionIssue)

        store.focusBook(target.id)
        await store.waitForPendingWork()
        store.updateSearchText("不存在的固定虚构分页书籍")
        await store.waitForPendingWork()
        XCTAssertEqual(store.selectionIssue, .outsideCurrentResults)

        store.selectBook(ordinaryBook.id)
        XCTAssertEqual(store.selectedBookID, ordinaryBook.id)
        XCTAssertNil(store.pinnedFocusedBook)
        XCTAssertNil(store.selectionIssue)
    }

    func testReadingEntryUIFixtureProducesExactDuplicateCandidate() async throws {
        let store = LibraryStore.makeApplicationStore(
            arguments: [
                "-BookAtlasUseInMemoryStore",
                "-BookAtlasSeedReadingEntryUITestData"
            ],
            environment: [:]
        )
        await store.waitForPendingWork()

        XCTAssertEqual(
            store.selectedBookID,
            UUID(uuidString: "00000000-0000-0000-0000-000000000101")
        )
        store.reviewSelectedBookForDuplicates()
        await store.waitForPendingWork()

        let candidate = try XCTUnwrap(store.duplicateReview?.candidates.first)
        XCTAssertEqual(candidate.confidence, .exact)
        XCTAssertEqual(
            candidate.existingBook.id,
            UUID(uuidString: "00000000-0000-0000-0000-000000000202")
        )
    }

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
        let mainBook = try repository.create(
            BookDraft(title: "《主详情灯塔》", author: "林雾"),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(1)
        )
        let mainLink = try repository.addExternalLink(
            ExternalLink(
                bookID: mainBook.id,
                kind: .web,
                value: "https://main.example.invalid/private-main"
            )
        )
        let candidateLink = try repository.addExternalLink(
            ExternalLink(
                bookID: existing.id,
                kind: .web,
                value: "https://candidate.example.invalid/private-candidate"
            )
        )
        let mainFile = try repository.addLocalFileReference(
            LocalFileReference(
                bookID: mainBook.id,
                displayName: "主详情虚构文件.pdf",
                bookmarkData: Data("main".utf8)
            )
        )
        let candidateFile = try repository.addLocalFileReference(
            LocalFileReference(
                bookID: existing.id,
                displayName: "候选虚构文件.pdf",
                bookmarkData: Data("candidate".utf8)
            )
        )
        let store = LibraryStore(catalog: LibraryCatalogService(repository: repository))
        await store.waitForPendingWork()
        store.readingEntries.load(bookID: mainBook.id)
        await store.readingEntries.waitForPendingLoad()
        store.beginCreate()
        let session = try XCTUnwrap(store.editorSession)
        let draft = BookEditorDraft(
            title: "可返回的灯塔",
            author: "沈遥",
            isbn: "9780000000002",
            note: "固定虚构草稿内容"
        )
        _ = await store.save(draft, for: session)
        let reviewID = try XCTUnwrap(store.duplicateReview?.id)

        store.viewSelectedDuplicate()
        await store.duplicateReadingEntries.waitForPendingLoad()

        XCTAssertEqual(store.viewedDuplicateBook, existing)
        XCTAssertEqual(store.editorSession?.id, session.id)
        XCTAssertEqual(store.duplicateReview?.id, reviewID)
        XCTAssertEqual(store.readingEntries.currentBookID, mainBook.id)
        XCTAssertEqual(store.readingEntries.webLinks.map(\.id), [mainLink.id])
        XCTAssertEqual(store.readingEntries.webLinks.map(\.value), [mainLink.value])
        XCTAssertEqual(store.readingEntries.localFiles.map(\.id), [mainFile.id])
        XCTAssertEqual(
            store.readingEntries.localFiles.map(\.bookmarkData),
            [mainFile.bookmarkData]
        )
        XCTAssertEqual(store.duplicateReadingEntries.currentBookID, existing.id)
        XCTAssertEqual(
            store.duplicateReadingEntries.webLinks.map(\.id),
            [candidateLink.id]
        )
        XCTAssertEqual(
            store.duplicateReadingEntries.webLinks.map(\.value),
            [candidateLink.value]
        )
        XCTAssertEqual(
            store.duplicateReadingEntries.localFiles.map(\.id),
            [candidateFile.id]
        )

        store.returnFromViewedDuplicate()

        XCTAssertNil(store.viewedDuplicateBook)
        XCTAssertEqual(store.editorSession?.id, session.id)
        XCTAssertEqual(store.duplicateReview?.id, reviewID)
        XCTAssertEqual(store.duplicateReview?.candidates.map(\.id), [existing.id])
        XCTAssertNil(store.duplicateReadingEntries.currentBookID)
        XCTAssertEqual(store.duplicateReadingEntries.webLinks, [])
        XCTAssertEqual(store.readingEntries.currentBookID, mainBook.id)
        XCTAssertEqual(store.readingEntries.webLinks.map(\.id), [mainLink.id])
        XCTAssertEqual(store.readingEntries.localFiles.map(\.id), [mainFile.id])

        store.viewSelectedDuplicate()
        await store.duplicateReadingEntries.waitForPendingLoad()
        XCTAssertTrue(store.handleDuplicateReviewEscape())
        XCTAssertNil(store.viewedDuplicateBook)
        XCTAssertEqual(store.duplicateReview?.id, reviewID)
        XCTAssertEqual(store.editorSession?.id, session.id)
        guard case let .newBook(editor, _) = store.duplicateReview?.subject else {
            return XCTFail("Expected the original draft review after the first Escape")
        }
        XCTAssertEqual(editor.title, draft.title)
        XCTAssertEqual(editor.author, draft.author)
        XCTAssertEqual(editor.isbn, draft.isbn)
        XCTAssertEqual(editor.note, draft.note)

        XCTAssertTrue(store.handleDuplicateReviewEscape())
        XCTAssertNil(store.duplicateReview)
        XCTAssertEqual(store.editorSession?.id, session.id)
        XCTAssertFalse(store.handleDuplicateReviewEscape())
    }

    func testStoreLoadsAllPagesWithoutSilentTruncationAndResetsForNewQuery() async throws {
        let repository = try BookRepository.inMemory()
        for index in 0 ..< 501 {
            _ = try repository.create(
                BookDraft(
                    title: String(format: "《状态分页 %03d》", index),
                    author: "固定虚构作者",
                    readingStatus: index.isMultiple(of: 2)
                        ? .reading
                        : .wishToRead
                ),
                id: UUID(
                    uuidString: String(
                        format: "50000000-0000-0000-0000-%012d",
                        index
                    )
                )!,
                at: FictionalLibraryFixtures.timestamp
                    .addingTimeInterval(TimeInterval(index))
            )
        }

        let service = LibraryCatalogService(repository: repository)
        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()

        XCTAssertEqual(store.books.count, 200)
        XCTAssertEqual(store.totalBookCount, 501)
        XCTAssertTrue(store.hasMoreBooks)
        XCTAssertEqual(store.resultPageStateDescription, "可以继续加载")
        XCTAssertEqual(
            store.accessibleResultDescription,
            "已显示 200 本，共 501 本，可以继续加载"
        )
        let initialSelection = store.selectedBookID

        store.loadMore()
        await store.waitForPendingWork()
        XCTAssertEqual(store.books.count, 400)
        XCTAssertEqual(store.selectedBookID, initialSelection)
        XCTAssertEqual(Set(store.books.map(\.id)).count, 400)

        store.loadMore()
        await store.waitForPendingWork()
        XCTAssertEqual(store.books.count, 501)
        XCTAssertFalse(store.hasMoreBooks)
        XCTAssertEqual(store.resultPageStateDescription, "已全部加载")
        XCTAssertEqual(Set(store.books.map(\.id)).count, 501)

        store.updateSearchText("状态分页 042")
        await store.waitForPendingWork()
        XCTAssertEqual(store.books.count, 1)
        XCTAssertEqual(store.totalBookCount, 1)
        XCTAssertEqual(store.query.offset, 0)

        store.clearFilters()
        await store.waitForPendingWork()
        XCTAssertEqual(store.books.count, 200)
        XCTAssertEqual(store.totalBookCount, 501)

        store.loadMore()
        await store.waitForPendingWork()
        XCTAssertEqual(store.books.count, 400)
        store.setSort(field: .createdAt, direction: .ascending)
        await store.waitForPendingWork()
        XCTAssertEqual(store.books.count, 200)
        XCTAssertEqual(store.totalBookCount, 501)
        XCTAssertEqual(store.books.first?.id.uuidString, "50000000-0000-0000-0000-000000000000")

        store.loadMore()
        await store.waitForPendingWork()
        store.toggleReadingStatus(.reading)
        await store.waitForPendingWork()
        XCTAssertEqual(store.books.count, 200)
        XCTAssertEqual(store.totalBookCount, 251)
        XCTAssertEqual(store.query.offset, 0)
    }

    func testLoadMoreFailureKeepsRowsAndRetryPublishesOnlyNextPage() async throws {
        let books = try (0 ..< 3).map { index in
            try Book(
                id: UUID(
                    uuidString: String(
                        format: "51000000-0000-0000-0000-%012d",
                        index
                    )
                )!,
                draft: BookDraft(
                    title: "《重试分页 \(index)》",
                    author: "固定虚构作者"
                ),
                createdAt: FictionalLibraryFixtures.timestamp
                    .addingTimeInterval(TimeInterval(index))
            )
        }
        let catalog = LoadMoreRetryCatalog(books: books)
        let store = LibraryStore(catalog: catalog)
        await store.waitForPendingWork()

        XCTAssertEqual(store.books.map(\.id), Array(books.prefix(2)).map(\.id))
        XCTAssertEqual(store.totalBookCount, 3)

        store.loadMore()
        await store.waitForPendingWork()
        XCTAssertEqual(store.books.map(\.id), Array(books.prefix(2)).map(\.id))
        XCTAssertEqual(store.loadMoreError, .loadMoreFailed)
        XCTAssertTrue(store.canLoadMore)
        XCTAssertEqual(store.resultPageStateDescription, "下一页加载失败，可以重试")

        store.loadMore()
        await store.waitForPendingWork()
        XCTAssertEqual(store.books.map(\.id), books.map(\.id))
        XCTAssertEqual(store.totalBookCount, 3)
        XCTAssertEqual(store.resultPageStateDescription, "已全部加载")
        XCTAssertNil(store.loadMoreError)
        XCTAssertFalse(store.hasMoreBooks)
    }

    func testPagedStoreMutationsKeepTotalsUniqueAndSelectionDeterministic() async throws {
        let repository = try BookRepository.inMemory()
        var seededBooks: [Book] = []
        for index in 0 ..< 203 {
            seededBooks.append(
                try repository.create(
                    BookDraft(
                        title: index < 2
                            ? "《分页合并候选》"
                            : String(format: "《分页变更 %03d》", index),
                        author: "固定虚构作者"
                    ),
                    id: UUID(
                        uuidString: String(
                            format: "52000000-0000-0000-0000-%012d",
                            index
                        )
                    )!,
                    at: FictionalLibraryFixtures.timestamp
                        .addingTimeInterval(TimeInterval(index))
                )
            )
        }
        let service = LibraryCatalogService(
            repository: repository,
            now: {
                FictionalLibraryFixtures.timestamp
                    .addingTimeInterval(20_000)
            }
        )
        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()
        store.loadMore()
        await store.waitForPendingWork()
        XCTAssertEqual(store.books.count, 203)

        let updatedID = seededBooks[100].id
        store.selectedBookID = updatedID
        store.beginEdit()
        let editSession = try XCTUnwrap(store.editorSession)
        guard case .success = await store.save(
            BookEditorDraft(
                title: "《分页更新后》",
                author: "固定虚构作者"
            ),
            for: editSession
        ) else {
            return XCTFail("Expected the paged edit to succeed")
        }
        XCTAssertEqual(store.selectedBookID, updatedID)
        XCTAssertEqual(store.books.count, 200)
        XCTAssertEqual(store.totalBookCount, 203)
        XCTAssertEqual(Set(store.books.map(\.id)).count, 200)

        store.beginCreate()
        let createSession = try XCTUnwrap(store.editorSession)
        guard case .success = await store.save(
            BookEditorDraft(
                title: "《分页中新建》",
                author: "另一位固定虚构作者"
            ),
            for: createSession
        ) else {
            return XCTFail("Expected the paged create to succeed")
        }
        var createdQuery = LibraryQuery()
        createdQuery.searchText = "分页中新建"
        createdQuery.limit = 10
        let createdBooks = try await service.queryBooks(createdQuery)
        let createdID = try XCTUnwrap(createdBooks.first?.id)
        XCTAssertEqual(store.selectedBookID, createdID)
        XCTAssertTrue(store.books.contains(where: { $0.id == createdID }))
        XCTAssertEqual(store.totalBookCount, 204)
        XCTAssertEqual(Set(store.books.map(\.id)).count, 200)

        store.beginDelete()
        store.confirmDelete()
        await store.waitForPendingWork()
        XCTAssertNil(store.selectedBookID)
        XCTAssertEqual(store.totalBookCount, 203)
        XCTAssertEqual(Set(store.books.map(\.id)).count, 200)

        store.loadMore()
        await store.waitForPendingWork()
        let mergeSource = seededBooks[0]
        let mergeTarget = seededBooks[1]
        XCTAssertTrue(store.books.contains(where: { $0.id == mergeSource.id }))
        store.selectedBookID = mergeSource.id
        store.reviewSelectedBookForDuplicates()
        await store.waitForPendingWork()
        XCTAssertTrue(
            try XCTUnwrap(store.duplicateReview)
                .candidates
                .contains(where: { $0.id == mergeTarget.id })
        )
        store.selectedDuplicateID = mergeTarget.id
        store.beginMergePreview()
        await store.waitForPendingWork()
        store.confirmMerge()
        await store.waitForPendingWork()

        XCTAssertEqual(store.selectedBookID, mergeTarget.id)
        XCTAssertEqual(store.totalBookCount, 202)
        XCTAssertEqual(Set(store.books.map(\.id)).count, store.books.count)
        store.loadMore()
        await store.waitForPendingWork()
        XCTAssertEqual(store.books.count, 202)
        XCTAssertEqual(Set(store.books.map(\.id)).count, 202)
        XCTAssertTrue(store.books.contains(where: { $0.id == mergeTarget.id }))
        XCTAssertFalse(store.books.contains(where: { $0.id == mergeSource.id }))
    }

    func testFocusBookKeepsThirdPageIdentityAndMissingTargetNeverSelectsFirstRow() async throws {
        let (service, seededBooks) = try await makePagedCatalog()
        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()

        let target = seededBooks[42]
        XCTAssertFalse(store.books.contains(where: { $0.id == target.id }))
        store.focusBook(target.id)
        await store.waitForPendingWork()
        await Task.yield()

        XCTAssertEqual(store.selectedBookID, target.id)
        XCTAssertEqual(store.selectedBook?.id, target.id)
        XCTAssertEqual(store.selectedBook?.title, target.title)
        XCTAssertEqual(store.pinnedFocusedBook?.id, target.id)
        XCTAssertEqual(store.books.count, 200)
        XCTAssertEqual(store.totalBookCount, 501)
        XCTAssertEqual(Set(store.books.map(\.id)).count, 200)
        XCTAssertNil(store.selectionIssue)
        XCTAssertTrue(
            store.resultCountDescription.contains("另显示 1 本定位书籍")
        )

        let loadedIDs = store.books.map(\.id)
        store.focusBook(
            UUID(uuidString: "53000000-0000-0000-ffff-000000000999")!
        )
        await store.waitForPendingWork()

        XCTAssertNil(store.selectedBookID)
        XCTAssertNil(store.selectedBook)
        XCTAssertNil(store.pinnedFocusedBook)
        XCTAssertEqual(
            store.selectionIssue,
            .requestedBookUnavailable
        )
        XCTAssertEqual(store.books.map(\.id), loadedIDs)
        XCTAssertEqual(store.totalBookCount, 501)
    }

    func testMissingFocusInEmptyLibraryPublishesSpecificSelectionIssue() async throws {
        let repository = try BookRepository.inMemory()
        let store = LibraryStore(
            catalog: LibraryCatalogService(repository: repository)
        )
        await store.waitForPendingWork()

        store.focusBook(UUID(
            uuidString: "55000000-0000-0000-0000-000000000404"
        )!)
        await store.waitForPendingWork()

        XCTAssertTrue(store.books.isEmpty)
        XCTAssertEqual(store.totalBookCount, 0)
        XCTAssertNil(store.selectedBookID)
        XCTAssertNil(store.selectedBook)
        XCTAssertEqual(store.selectionIssue, .requestedBookUnavailable)
    }

    func testFilteringOutFocusedBookClearsSelectionWithoutChoosingAnotherBook() async throws {
        let (service, seededBooks) = try await makePagedCatalog()
        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()

        let target = seededBooks[42]
        store.focusBook(target.id)
        await store.waitForPendingWork()
        XCTAssertEqual(store.selectedBookID, target.id)

        store.updateSearchText("分页身份 001")
        await store.waitForPendingWork()

        XCTAssertEqual(store.books.map(\.id), [seededBooks[1].id])
        XCTAssertEqual(store.totalBookCount, 1)
        XCTAssertNil(store.selectedBookID)
        XCTAssertNil(store.selectedBook)
        XCTAssertEqual(store.selectionIssue, .outsideCurrentResults)
        XCTAssertNotEqual(store.selectedBookID, seededBooks[1].id)
    }

    func testZeroResultSearchShowsFocusedBookIssueAndClearingRecoversExactBook() async throws {
        let (service, seededBooks) = try await makePagedCatalog()
        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()

        let target = seededBooks[42]
        store.focusBook(target.id)
        await store.waitForPendingWork()
        XCTAssertEqual(store.selectedBookID, target.id)
        XCTAssertEqual(store.pinnedFocusedBook?.id, target.id)

        store.updateSearchText("不存在的固定虚构分页书籍")
        await store.waitForPendingWork()

        XCTAssertTrue(store.books.isEmpty)
        XCTAssertEqual(store.totalBookCount, 0)
        XCTAssertNil(store.selectedBookID)
        XCTAssertNil(store.selectedBook)
        XCTAssertEqual(store.selectionIssue, .outsideCurrentResults)

        // SwiftUI List may echo nil while the exact target is intentionally
        // outside the current query. That synchronization event must not erase
        // the identity needed by the clear-filter recovery flow.
        store.selectBook(nil)
        XCTAssertEqual(store.selectionIssue, .outsideCurrentResults)

        store.clearFilters()
        await store.waitForPendingWork()

        XCTAssertEqual(store.books.count, 200)
        XCTAssertEqual(store.totalBookCount, 501)
        XCTAssertEqual(Set(store.books.map(\.id)).count, 200)
        XCTAssertNil(store.selectionIssue)
        XCTAssertEqual(store.selectedBookID, target.id)
        XCTAssertEqual(store.pinnedFocusedBook?.id, target.id)
        XCTAssertNotEqual(store.selectedBookID, store.books.first?.id)
    }

    func testCreateAndEditKeepOffPageIdentityWithoutLoadingTheWholeResult() async throws {
        let (service, seededBooks) = try await makePagedCatalog(
            now: {
                FictionalLibraryFixtures.timestamp
                    .addingTimeInterval(10_000)
            }
        )
        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()
        store.setSort(field: .createdAt, direction: .ascending)
        await store.waitForPendingWork()

        store.beginCreate()
        let createSession = try XCTUnwrap(store.editorSession)
        guard case .success = await store.save(
            BookEditorDraft(
                title: "《分页末尾新书》",
                author: "固定新书作者"
            ),
            for: createSession
        ) else {
            return XCTFail("Expected the off-page create to succeed")
        }

        let createdID = try XCTUnwrap(store.selectedBookID)
        XCTAssertEqual(store.selectedBook?.id, createdID)
        XCTAssertEqual(store.selectedBook?.title, "《分页末尾新书》")
        XCTAssertEqual(store.pinnedFocusedBook?.id, createdID)
        XCTAssertEqual(store.books.count, 200)
        XCTAssertEqual(store.totalBookCount, 502)
        XCTAssertEqual(Set(store.books.map(\.id)).count, 200)
        XCTAssertFalse(store.books.contains(where: { $0.id == createdID }))

        store.loadMore()
        await store.waitForPendingWork()
        store.loadMore()
        await store.waitForPendingWork()
        let editTarget = seededBooks[450]
        XCTAssertTrue(store.books.contains(where: { $0.id == editTarget.id }))
        store.selectBook(editTarget.id)
        store.beginEdit()
        let editSession = try XCTUnwrap(store.editorSession)
        guard case .success = await store.save(
            BookEditorDraft(
                title: "《分页末尾已更新》",
                author: editTarget.author
            ),
            for: editSession
        ) else {
            return XCTFail("Expected the off-page edit to succeed")
        }

        XCTAssertEqual(store.selectedBookID, editTarget.id)
        XCTAssertEqual(store.selectedBook?.id, editTarget.id)
        XCTAssertEqual(store.selectedBook?.title, "《分页末尾已更新》")
        XCTAssertEqual(store.pinnedFocusedBook?.id, editTarget.id)
        XCTAssertEqual(store.books.count, 200)
        XCTAssertEqual(store.totalBookCount, 502)
        XCTAssertEqual(Set(store.books.map(\.id)).count, 200)
        XCTAssertFalse(store.books.contains(where: { $0.id == editTarget.id }))
    }

    func testMergeKeepsOffPageRetainedIdentityAndRemovesSourceWithoutSelectingFirstRow() async throws {
        let (service, seededBooks) = try await makePagedCatalog(
            duplicatePair: [450, 451]
        ) {
            FictionalLibraryFixtures.timestamp
                .addingTimeInterval(10_000)
        }
        let store = LibraryStore(catalog: service)
        await store.waitForPendingWork()
        store.setSort(field: .createdAt, direction: .ascending)
        await store.waitForPendingWork()
        store.loadMore()
        await store.waitForPendingWork()
        store.loadMore()
        await store.waitForPendingWork()

        let retained = seededBooks[450]
        let source = seededBooks[451]
        store.selectBook(source.id)
        store.reviewSelectedBookForDuplicates()
        await store.waitForPendingWork()
        XCTAssertTrue(
            try XCTUnwrap(store.duplicateReview)
                .candidates
                .contains(where: { $0.id == retained.id })
        )
        store.selectedDuplicateID = retained.id
        store.beginMergePreview()
        await store.waitForPendingWork()
        store.confirmMerge()
        await store.waitForPendingWork()

        XCTAssertEqual(store.selectedBookID, retained.id)
        XCTAssertEqual(store.selectedBook?.id, retained.id)
        XCTAssertEqual(store.pinnedFocusedBook?.id, retained.id)
        XCTAssertEqual(store.totalBookCount, 500)
        XCTAssertEqual(store.books.count, 200)
        XCTAssertEqual(Set(store.books.map(\.id)).count, 200)
        XCTAssertFalse(store.books.contains(where: { $0.id == source.id }))
        XCTAssertNotEqual(store.selectedBookID, store.books.first?.id)

        let sourceLookup = try await service.queryBookPage(
            LibraryQuery(
                sortField: .createdAt,
                sortDirection: .ascending
            ),
            focusedBookID: source.id
        )
        XCTAssertNil(sourceLookup.focusedBook)
    }

    func testLateOldFocusCannotOverrideNewerFocusedIdentityOrPage() async throws {
        let slow = try Book(
            id: UUID(
                uuidString: "54000000-0000-0000-0000-000000000001"
            )!,
            draft: BookDraft(
                title: "《迟到定位 A》",
                author: "固定虚构作者"
            ),
            createdAt: FictionalLibraryFixtures.timestamp
        )
        let fast = try Book(
            id: UUID(
                uuidString: "54000000-0000-0000-0000-000000000002"
            )!,
            draft: BookDraft(
                title: "《最新定位 B》",
                author: "固定虚构作者"
            ),
            createdAt: FictionalLibraryFixtures.timestamp
        )
        let first = try Book(
            id: UUID(
                uuidString: "54000000-0000-0000-0000-000000000003"
            )!,
            draft: BookDraft(
                title: "《首批无关书籍》",
                author: "固定虚构作者"
            ),
            createdAt: FictionalLibraryFixtures.timestamp
        )
        let catalog = FocusRaceCatalog(
            slowBook: slow,
            fastBook: fast,
            firstBook: first
        )
        let store = LibraryStore(catalog: catalog)
        await store.waitForPendingWork()

        store.focusBook(slow.id)
        await catalog.waitUntilSlowFocusStarts()
        store.focusBook(fast.id)
        await store.waitForPendingWork()
        XCTAssertEqual(store.selectedBookID, fast.id)
        XCTAssertEqual(store.selectedBook?.title, fast.title)
        XCTAssertEqual(store.totalBookCount, 3)

        await catalog.releaseSlowFocus()
        try await Task.sleep(for: .milliseconds(20))

        XCTAssertEqual(store.selectedBookID, fast.id)
        XCTAssertEqual(store.selectedBook?.id, fast.id)
        XCTAssertEqual(store.selectedBook?.title, fast.title)
        XCTAssertEqual(store.pinnedFocusedBook?.id, fast.id)
        XCTAssertEqual(store.books.map(\.id), [first.id])
        XCTAssertEqual(store.totalBookCount, 3)
        XCTAssertNil(store.selectionIssue)
    }

    func testPerformanceLibraryUsesOnlyControlledExistingTemporaryDatabase() async throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "BookAtlas-Performance-Session-Tests-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: false
        )
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        let sessionID = UUID()
        let session = PerformanceLibrarySession(
            sessionID: sessionID,
            temporaryRootURL: temporaryRoot
        )
        let databaseURL = try session.prepare(bookCount: 1_000)
        XCTAssertEqual(
            databaseURL.deletingLastPathComponent(),
            session.directoryURL
        )

        let repository = try BookRepository(existingDatabaseURL: databaseURL)
        let page = try repository.queryPage(LibraryQuery())
        XCTAssertEqual(repository.schemaVersion, 5)
        XCTAssertEqual(page.books.count, 200)
        XCTAssertEqual(page.totalCount, 1_000)
        try repository.close()

        for suffix in ["-wal", "-shm"] {
            FileManager.default.createFile(
                atPath: databaseURL.path + suffix,
                contents: Data(),
                attributes: nil
            )
        }
        try session.cleanup()
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: session.directoryURL.path)
        )
    }

    func testInvalidPerformanceArgumentsAndMissingFileNeverFallBackToProduction() {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "BookAtlas-Performance-Rejection-\(UUID().uuidString)",
                isDirectory: true
            )
        XCTAssertNoThrow(
            try FileManager.default.createDirectory(
                at: temporaryRoot,
                withIntermediateDirectories: false
            )
        )
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        var productionLocationWasRequested = false
        let malformed = LibraryStore.makeApplicationStore(
            arguments: [
                "BookAtlas",
                "-BookAtlasPerformanceUseExistingLibrary",
                "/tmp/not-a-session"
            ],
            environment: [:],
            performanceTemporaryDirectory: temporaryRoot,
            productionDatabaseURL: {
                productionLocationWasRequested = true
                throw PerformanceLibraryError.unsafeTemporaryLocation
            }
        )
        XCTAssertEqual(malformed.loadingState, .failed(.databaseUnavailable))
        XCTAssertFalse(productionLocationWasRequested)

        let missing = LibraryStore.makeApplicationStore(
            arguments: [
                "BookAtlas",
                "-BookAtlasPerformanceUseExistingLibrary",
                UUID().uuidString
            ],
            environment: [:],
            performanceTemporaryDirectory: temporaryRoot,
            productionDatabaseURL: {
                productionLocationWasRequested = true
                throw PerformanceLibraryError.unsafeTemporaryLocation
            }
        )
        XCTAssertEqual(missing.loadingState, .failed(.databaseUnavailable))
        XCTAssertFalse(productionLocationWasRequested)

        let legacy = LibraryStore.makeApplicationStore(
            arguments: [
                "BookAtlas",
                "-BookAtlasPerformanceBookCount",
                "1000"
            ],
            environment: [:],
            performanceTemporaryDirectory: temporaryRoot,
            productionDatabaseURL: {
                productionLocationWasRequested = true
                throw PerformanceLibraryError.unsafeTemporaryLocation
            }
        )
        XCTAssertEqual(legacy.loadingState, .failed(.databaseUnavailable))
        XCTAssertFalse(productionLocationWasRequested)

        let unsupportedCount = LibraryStore.makeApplicationStore(
            arguments: [
                "BookAtlas",
                "-BookAtlasPerformancePrepareLibrary",
                UUID().uuidString,
                "999"
            ],
            environment: [:],
            performanceTemporaryDirectory: temporaryRoot,
            productionDatabaseURL: {
                productionLocationWasRequested = true
                throw PerformanceLibraryError.unsafeTemporaryLocation
            }
        )
        XCTAssertEqual(
            unsupportedCount.loadingState,
            .failed(.databaseUnavailable)
        )
        XCTAssertFalse(productionLocationWasRequested)

        let unknownFlag = LibraryStore.makeApplicationStore(
            arguments: [
                "BookAtlas",
                "-BookAtlasPerformanceUnknown",
                UUID().uuidString
            ],
            environment: [:],
            performanceTemporaryDirectory: temporaryRoot,
            productionDatabaseURL: {
                productionLocationWasRequested = true
                throw PerformanceLibraryError.unsafeTemporaryLocation
            }
        )
        XCTAssertEqual(unknownFlag.loadingState, .failed(.databaseUnavailable))
        XCTAssertFalse(productionLocationWasRequested)
    }

    func testPerformanceLibraryRejectsSymlinkAndNonRegularDatabase() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "BookAtlas-Performance-Node-Rejection-\(UUID().uuidString)",
                isDirectory: true
            )
        let symlinkTarget = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "BookAtlas-Performance-Symlink-Target-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: false
        )
        try FileManager.default.createDirectory(
            at: symlinkTarget,
            withIntermediateDirectories: false
        )
        defer {
            try? FileManager.default.removeItem(at: temporaryRoot)
            try? FileManager.default.removeItem(at: symlinkTarget)
        }

        let session = PerformanceLibrarySession(
            sessionID: UUID(),
            temporaryRootURL: temporaryRoot
        )
        try FileManager.default.createSymbolicLink(
            at: session.directoryURL,
            withDestinationURL: symlinkTarget
        )
        XCTAssertThrowsError(try session.validatedExistingDatabaseURL()) {
            XCTAssertEqual(
                $0 as? PerformanceLibraryError,
                .unsafeTemporaryLocation
            )
        }

        try FileManager.default.removeItem(at: session.directoryURL)
        try FileManager.default.createDirectory(
            at: session.directoryURL,
            withIntermediateDirectories: false
        )
        try FileManager.default.createDirectory(
            at: session.databaseURL,
            withIntermediateDirectories: false
        )
        XCTAssertThrowsError(try session.validatedExistingDatabaseURL()) {
            XCTAssertEqual(
                $0 as? PerformanceLibraryError,
                .unsafeTemporaryLocation
            )
        }

        try FileManager.default.removeItem(at: session.databaseURL)
        XCTAssertTrue(
            FileManager.default.createFile(
                atPath: session.databaseURL.path,
                contents: Data(),
                attributes: nil
            )
        )
        XCTAssertTrue(
            FileManager.default.createFile(
                atPath: session.directoryURL
                    .appendingPathComponent("unexpected.txt")
                    .path,
                contents: Data(),
                attributes: nil
            )
        )
        XCTAssertThrowsError(try session.validatedExistingDatabaseURL()) {
            XCTAssertEqual(
                $0 as? PerformanceLibraryError,
                .unexpectedTemporaryArtifact
            )
        }
    }

}

private func makePagedCatalog(
    count: Int = 501,
    duplicatePair: Set<Int> = [],
    now: @escaping @Sendable () -> Date = Date.init
) async throws -> (LibraryCatalogService, [Book]) {
    try await Task.detached {
        let repository = try BookRepository.inMemory()
        var books: [Book] = []
        try repository.transaction {
            for index in 0 ..< count {
                let isDuplicate = duplicatePair.contains(index)
                books.append(
                    try repository.create(
                        BookDraft(
                            title: isDuplicate
                                ? "《分页合并身份》"
                                : String(format: "《分页身份 %03d》", index),
                            author: isDuplicate
                                ? "固定合并作者"
                                : String(format: "固定虚构作者 %03d", index)
                        ),
                        id: UUID(
                            uuidString: String(
                                format: "53000000-0000-0000-0000-%012d",
                                index
                            )
                        )!,
                        at: FictionalLibraryFixtures.timestamp
                            .addingTimeInterval(TimeInterval(index))
                    )
                )
            }
        }
        return (
            LibraryCatalogService(repository: repository, now: now),
            books
        )
    }.value
}

private actor FocusRaceCatalog: LibraryCataloging {
    private let slowBook: Book
    private let fastBook: Book
    private let firstBook: Book
    private var slowFocusStarted = false
    private var slowFocusStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var slowFocusContinuation: CheckedContinuation<Void, Never>?

    init(slowBook: Book, fastBook: Book, firstBook: Book) {
        self.slowBook = slowBook
        self.fastBook = fastBook
        self.firstBook = firstBook
    }

    func waitUntilSlowFocusStarts() async {
        if slowFocusStarted {
            return
        }
        await withCheckedContinuation { continuation in
            slowFocusStartWaiters.append(continuation)
        }
    }

    func releaseSlowFocus() {
        slowFocusContinuation?.resume()
        slowFocusContinuation = nil
    }

    func queryBooks(_ query: LibraryQuery) throws -> [Book] {
        [firstBook]
    }

    func queryBookPage(_ query: LibraryQuery) throws -> LibraryPage {
        LibraryPage(
            books: [firstBook],
            totalCount: 3,
            offset: query.offset
        )
    }

    func queryBookPage(
        _ query: LibraryQuery,
        focusedBookID: UUID
    ) async throws -> FocusedLibraryPage {
        if focusedBookID == slowBook.id {
            slowFocusStarted = true
            let waiters = slowFocusStartWaiters
            slowFocusStartWaiters.removeAll()
            waiters.forEach { $0.resume() }
            await withCheckedContinuation { continuation in
                slowFocusContinuation = continuation
            }
            return FocusedLibraryPage(
                page: LibraryPage(
                    books: [slowBook],
                    totalCount: 1,
                    offset: 0
                ),
                focusedBook: slowBook
            )
        }
        return FocusedLibraryPage(
            page: try queryBookPage(query),
            focusedBook: focusedBookID == fastBook.id ? fastBook : nil
        )
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

private actor LoadMoreRetryCatalog: LibraryCataloging {
    private let books: [Book]
    private var shouldFailNextPage = true

    init(books: [Book]) {
        self.books = books
    }

    func queryBooks(_ query: LibraryQuery) throws -> [Book] {
        Array(books.dropFirst(query.offset).prefix(query.limit))
    }

    func queryBookPage(_ query: LibraryQuery) throws -> LibraryPage {
        if query.offset > 0, shouldFailNextPage {
            shouldFailNextPage = false
            throw TestFailure.failed
        }
        let pageSize = query.offset == 0 ? 2 : query.limit
        return LibraryPage(
            books: Array(books.dropFirst(query.offset).prefix(pageSize)),
            totalCount: books.count,
            offset: query.offset
        )
    }

    func queryBookPage(
        _ query: LibraryQuery,
        focusedBookID: UUID
    ) async throws -> FocusedLibraryPage {
        let page = try queryBookPage(query)
        return FocusedLibraryPage(
            page: page,
            focusedBook: books.first { $0.id == focusedBookID }
        )
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

    func queryBookPage(_ query: LibraryQuery) throws -> LibraryPage {
        let books = try queryBooks(query)
        return LibraryPage(
            books: Array(
                books.dropFirst(query.offset).prefix(query.limit)
            ),
            totalCount: books.count,
            offset: query.offset
        )
    }

    func queryBookPage(
        _ query: LibraryQuery,
        focusedBookID: UUID
    ) async throws -> FocusedLibraryPage {
        let page = try queryBookPage(query)
        return FocusedLibraryPage(
            page: page,
            focusedBook: books.first { $0.id == focusedBookID }
        )
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
