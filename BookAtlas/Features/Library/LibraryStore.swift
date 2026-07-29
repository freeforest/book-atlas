import Foundation
import SwiftUI

enum LibraryUserFacingError: Error, Equatable {
    case databaseUnavailable
    case loadFailed
    case saveFailed
    case deleteFailed
    case duplicateReviewFailed
    case mergeFailed
    case restoreRecoveryRequired
    case validation(BookEditorValidationError)

    var title: String {
        switch self {
        case .databaseUnavailable:
            "无法打开本地书库"
        case .loadFailed:
            "无法载入书库"
        case .saveFailed:
            "无法保存书籍"
        case .deleteFailed:
            "无法删除书籍"
        case .duplicateReviewFailed:
            "无法检查重复书籍"
        case .mergeFailed:
            "无法合并书籍"
        case .restoreRecoveryRequired:
            "恢复需要人工处理"
        case .validation:
            "请检查填写内容"
        }
    }

    var message: String {
        switch self {
        case .databaseUnavailable:
            "请稍后重试；书籍内容未被发送到网络。"
        case .loadFailed:
            "暂时无法读取本地书库，请重试。"
        case .saveFailed:
            "未能保存本次修改，表单内容仍会保留。"
        case .deleteFailed:
            "未能删除这本书，现有记录未被更改。"
        case .duplicateReviewFailed:
            "暂时无法读取重复候选；书库内容未被更改。"
        case .mergeFailed:
            "合并未完成，相关书籍和关联均保持原状。"
        case .restoreRecoveryRequired:
            "检测到无法自动判定的中断恢复状态。请停止编辑，保留数据库与恢复前副本，并按照恢复指引处理。"
        case let .validation(error):
            error.message
        }
    }
}

enum LibraryLoadingState: Equatable {
    case loading
    case content
    case failed(LibraryUserFacingError)
}

struct BookEditorSession: Identifiable {
    enum Mode {
        case create
        case edit(Book)
    }

    let id = UUID()
    let proposedBookID = UUID()
    let mode: Mode
    let initialDraft: BookEditorDraft

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            initialDraft = BookEditorDraft()
        case let .edit(book):
            initialDraft = BookEditorDraft(book: book)
        }
    }

    var title: String {
        switch mode {
        case .create:
            "新增书籍"
        case .edit:
            "编辑书籍"
        }
    }
}

enum DuplicateReviewSubject {
    case newBook(editor: BookEditorDraft, proposedID: UUID)
    case existingBook(Book)
}

struct DuplicateReviewSession: Identifiable {
    enum Origin: Equatable {
        case newDraft
        case createdBookContinuation
        case existingBook
    }

    let id = UUID()
    let subject: DuplicateReviewSubject
    let candidates: [DuplicateCandidate]
    let includingPossible: Bool
    let origin: Origin
    let possibleLookupWasTruncated: Bool
}

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var loadingState: LibraryLoadingState = .loading
    @Published private(set) var books: [Book] = []
    @Published private(set) var query = LibraryQuery()
    @Published private(set) var isQuerying = false
    @Published var selectedBookID: UUID?
    @Published var editorSession: BookEditorSession?
    @Published var deletionCandidate: Book?
    @Published var saveRequestID = 0
    @Published var operationError: LibraryUserFacingError?
    @Published var duplicateReview: DuplicateReviewSession?
    @Published var selectedDuplicateID: UUID?
    @Published var viewedDuplicateBook: Book?
    @Published var mergePreview: BookMergePreview?
    @Published var mergeSelections = BookMergeSelections()
    @Published var isDuplicateOperationInProgress = false

    let organizer: CatalogOrganizerStore
    let portability: PortabilityStore
    let graph: GraphStore
    let readingEntries: ReadingEntryStore
    let duplicateReadingEntries: ReadingEntryStore

    private let catalog: (any LibraryCataloging)?
    private var queryTask: Task<Void, Never>?
    private var duplicateTask: Task<Void, Never>?
    private var activeRequestID = UUID()

    init(
        catalog: (any LibraryCataloging)? = nil,
        initialError: LibraryUserFacingError? = nil,
        readingEntries: ReadingEntryStore? = nil
    ) {
        self.catalog = catalog
        organizer = CatalogOrganizerStore(catalog: catalog)
        portability = PortabilityStore(catalog: catalog)
        graph = GraphStore(catalog: catalog)
        let primaryReadingEntries = readingEntries ?? ReadingEntryStore(catalog: catalog)
        self.readingEntries = primaryReadingEntries
        duplicateReadingEntries = primaryReadingEntries.makeScopedStore()
        if let initialError {
            loadingState = .failed(initialError)
        } else if catalog == nil {
            loadingState = .failed(.databaseUnavailable)
        } else {
            load()
        }
    }

    static func makeApplicationStore(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> LibraryStore {
        if arguments.contains("-BookAtlasForceUnavailableStore") {
            return LibraryStore(initialError: .databaseUnavailable)
        }

        do {
            let usesTestStore = arguments.contains("-BookAtlasUseInMemoryStore")
                || environment["XCTestConfigurationFilePath"] != nil
            let catalog: LibraryCatalogService
            if usesTestStore {
                catalog = try Self.makeInMemoryCatalog(
                    seedFictionalUITestBooks: arguments.contains("-BookAtlasSeedFictionalUITestBooks"),
                    seedMergePreviewAssociations: arguments.contains("-BookAtlasSeedMergePreviewAssociations"),
                    seedGraphUITestData: arguments.contains("-BookAtlasSeedGraphUITestData"),
                    seedGraphLimitUITestData: arguments.contains("-BookAtlasSeedGraphLimitUITestData"),
                    seedReadingEntryUITestData: arguments.contains("-BookAtlasSeedReadingEntryUITestData")
                )
            } else {
                let databaseURL = try BookAtlasDatabaseLocation.defaultURL()
                try LibraryBackupCoordinator().recoverInterruptedRestore(
                    databaseURL: databaseURL
                )
                catalog = LibraryCatalogService(
                    repository: try BookRepository(databaseURL: databaseURL),
                    databaseURL: databaseURL
                )
            }
            let readingEntries = usesTestStore
                ? ReadingEntryStore(
                    catalog: catalog,
                    opener: FictionalUITestResourceOpener(),
                    appleBooks: FictionalUITestAppleBooksIntegration(),
                    clipboard: FictionalUITestClipboardWriter(),
                    fileSelector: FictionalUITestFileSelector(),
                    bookmarks: FictionalUITestBookmarkService()
                )
                : nil
            let store = LibraryStore(catalog: catalog, readingEntries: readingEntries)
            if arguments.contains("-BookAtlasSeedPortabilityPreview") {
                store.portability.seedFictionalPreviewForUITesting()
            }
            if arguments.contains("-BookAtlasSeedRestorePreview") {
                store.portability.seedFictionalRestorePreviewForUITesting()
            }
            if arguments.contains("-BookAtlasSeedSafeReplacement") {
                store.portability.seedSafeReplacementForUITesting()
            }
            if arguments.contains("-BookAtlasSeedRestoreInspection") {
                store.portability.seedRestoreInspectionForUITesting()
            }
            if arguments.contains("-BookAtlasSeedReadingEntryUITestData") {
                store.selectedBookID = UUID(
                    uuidString: "00000000-0000-0000-0000-000000000101"
                )!
            }
            if arguments.contains("-BookAtlasSeedGraphUITestData")
                || arguments.contains("-BookAtlasSeedGraphLimitUITestData")
            {
                let graphCenterID = UUID(
                    uuidString: "00000000-0000-0000-0000-000000000601"
                )!
                store.selectedBookID = graphCenterID
                if arguments.contains("-BookAtlasSeedGraphLimitUITestData") {
                    store.graph.load(
                        centerBookID: graphCenterID,
                        options: GraphBuildOptions(maximumNodes: 20, maximumEdges: 50)
                    )
                }
            }
            return store
        } catch PortabilityError.recoveryRequired {
            return LibraryStore(initialError: .restoreRecoveryRequired)
        } catch {
            return LibraryStore(initialError: .databaseUnavailable)
        }
    }

    var selectedBook: Book? {
        guard let selectedBookID else {
            return nil
        }
        return books.first { $0.id == selectedBookID }
    }

    var hasSelection: Bool {
        selectedBook != nil
    }

    var hasActiveFilters: Bool {
        query.hasFilters
    }

    func load() {
        guard catalog != nil else {
            loadingState = .failed(.databaseUnavailable)
            return
        }
        loadingState = .loading
        organizer.load()
        scheduleQuery(delay: nil)
    }

    func refresh() {
        organizer.load()
        scheduleQuery(delay: nil)
    }

    func focusBook(_ id: UUID) {
        query = LibraryQuery()
        selectedBookID = id
        scheduleQuery(delay: nil)
    }

    func updateSearchText(_ text: String) {
        query.searchText = text
        query.offset = 0
        scheduleQuery(delay: .milliseconds(250))
    }

    func toggleReadingStatus(_ status: ReadingStatus) {
        toggle(status, in: &query.readingStatuses)
        query.offset = 0
        scheduleQuery(delay: nil)
    }

    func toggleTag(_ id: UUID) {
        toggle(id, in: &query.tagIDs)
        query.offset = 0
        scheduleQuery(delay: nil)
    }

    func toggleCollection(_ id: UUID) {
        toggle(id, in: &query.collectionIDs)
        query.offset = 0
        scheduleQuery(delay: nil)
    }

    func toggleSource(_ id: UUID) {
        toggle(id, in: &query.sourceIDs)
        query.offset = 0
        scheduleQuery(delay: nil)
    }

    func setSort(field: LibrarySortField, direction: LibrarySortDirection) {
        query.sortField = field
        query.sortDirection = direction
        query.offset = 0
        scheduleQuery(delay: nil)
    }

    func clearFilters() {
        query.clearFilters()
        scheduleQuery(delay: nil)
    }

    func catalogDidDeleteTag(_ id: UUID) {
        query.tagIDs.remove(id)
        refresh()
    }

    func catalogDidMergeTag(_ sourceID: UUID, into targetID: UUID) {
        if query.tagIDs.remove(sourceID) != nil {
            query.tagIDs.insert(targetID)
        }
        refresh()
    }

    func catalogDidDeleteCollection(_ id: UUID) {
        query.collectionIDs.remove(id)
        refresh()
    }

    func catalogDidDeleteSource(_ id: UUID) {
        query.sourceIDs.remove(id)
        refresh()
    }

    func beginCreate() {
        operationError = nil
        clearDuplicateReview()
        deletionCandidate = nil
        editorSession = BookEditorSession(mode: .create)
    }

    func beginEdit() {
        guard let selectedBook else {
            return
        }
        operationError = nil
        clearDuplicateReview()
        deletionCandidate = nil
        editorSession = BookEditorSession(mode: .edit(selectedBook))
    }

    func requestSaveEditor() {
        guard editorSession != nil else {
            return
        }
        saveRequestID &+= 1
    }

    func cancelEditor() {
        clearDuplicateReview()
        editorSession = nil
    }

    func save(
        _ draft: BookEditorDraft,
        for session: BookEditorSession
    ) async -> Result<Void, LibraryUserFacingError> {
        guard let catalog else {
            return .failure(.databaseUnavailable)
        }

        do {
            let savedBook: Book
            switch session.mode {
            case .create:
                let search = try await catalog.duplicateCandidateSearch(
                    for: draft,
                    proposedID: session.proposedBookID,
                    includingPossible: false
                )
                if !search.candidates.isEmpty {
                    presentDuplicateReview(
                        DuplicateReviewSession(
                            subject: .newBook(editor: draft, proposedID: session.proposedBookID),
                            candidates: search.candidates,
                            includingPossible: false,
                            origin: .newDraft,
                            possibleLookupWasTruncated: search.possibleLookupWasTruncated
                        )
                    )
                    return .success(())
                }
                savedBook = try await catalog.createBook(from: draft)
            case let .edit(book):
                savedBook = try await catalog.updateBook(book, from: draft)
            }
            await reloadBooks(selecting: savedBook.id)
            organizer.load()
            editorSession = nil
            return .success(())
        } catch let error as BookEditorValidationError {
            return .failure(.validation(error))
        } catch {
            return .failure(.saveFailed)
        }
    }

    func reviewSelectedBookForDuplicates() {
        guard let selectedBook, let catalog else {
            operationError = .databaseUnavailable
            return
        }
        isDuplicateOperationInProgress = true
        duplicateTask = Task { @MainActor [weak self] in
            do {
                let search = try await catalog.duplicateCandidateSearch(
                    for: selectedBook,
                    includingPossible: true
                )
                self?.presentDuplicateReview(
                    DuplicateReviewSession(
                        subject: .existingBook(selectedBook),
                        candidates: search.candidates,
                        includingPossible: true,
                        origin: .existingBook,
                        possibleLookupWasTruncated: search.possibleLookupWasTruncated
                    )
                )
            } catch {
                self?.operationError = .duplicateReviewFailed
            }
            self?.isDuplicateOperationInProgress = false
        }
    }

    func cancelDuplicateReview() {
        clearDuplicateReview()
    }

    func viewSelectedDuplicate() {
        guard let selectedDuplicateID,
              let candidate = duplicateReview?.candidates.first(where: { $0.id == selectedDuplicateID })
        else {
            return
        }
        viewDuplicate(candidate)
    }

    func viewDuplicate(_ candidate: DuplicateCandidate) {
        selectedDuplicateID = candidate.id
        viewedDuplicateBook = candidate.existingBook
        duplicateReadingEntries.load(bookID: candidate.existingBook.id)
    }

    func returnFromViewedDuplicate() {
        viewedDuplicateBook = nil
        duplicateReadingEntries.reset()
    }

    func keepSelectedDuplicateIndependent(as disposition: DuplicatePairDisposition) {
        guard let review = duplicateReview,
              let selectedDuplicateID,
              review.candidates.contains(where: { $0.id == selectedDuplicateID }),
              let catalog
        else {
            return
        }
        isDuplicateOperationInProgress = true
        duplicateTask = Task { @MainActor [weak self] in
            do {
                switch review.subject {
                case let .newBook(editor, proposedID):
                    let saved = try await catalog.createBookKeepingIndependent(
                        from: editor,
                        proposedID: proposedID,
                        candidateID: selectedDuplicateID,
                        disposition: disposition
                    )
                    await self?.reloadBooks(selecting: saved.id)
                    self?.organizer.load()
                    self?.editorSession = nil
                    let search = try await catalog.duplicateCandidateSearch(
                        for: saved,
                        includingPossible: review.includingPossible
                    )
                    if search.candidates.isEmpty {
                        self?.clearDuplicateReview()
                    } else {
                        self?.presentDuplicateReview(
                            DuplicateReviewSession(
                                subject: .existingBook(saved),
                                candidates: search.candidates,
                                includingPossible: review.includingPossible,
                                origin: .createdBookContinuation,
                                possibleLookupWasTruncated: search.possibleLookupWasTruncated
                            )
                        )
                    }
                case let .existingBook(book):
                    try await catalog.ignoreDuplicatePair(
                        book.id,
                        selectedDuplicateID,
                        disposition: disposition
                    )
                    let search = try await catalog.duplicateCandidateSearch(
                        for: book,
                        includingPossible: review.includingPossible
                    )
                    if search.candidates.isEmpty {
                        self?.clearDuplicateReview()
                    } else {
                        self?.presentDuplicateReview(
                            DuplicateReviewSession(
                                subject: .existingBook(book),
                                candidates: search.candidates,
                                includingPossible: review.includingPossible,
                                origin: review.origin,
                                possibleLookupWasTruncated: search.possibleLookupWasTruncated
                            )
                        )
                    }
                }
            } catch {
                self?.operationError = .duplicateReviewFailed
            }
            self?.isDuplicateOperationInProgress = false
        }
    }

    func beginMergePreview() {
        guard let review = duplicateReview,
              let targetID = selectedDuplicateID,
              let catalog
        else {
            return
        }
        isDuplicateOperationInProgress = true
        duplicateTask = Task { @MainActor [weak self] in
            do {
                let preview: BookMergePreview
                switch review.subject {
                case let .newBook(editor, proposedID):
                    preview = try await catalog.mergePreview(
                        targetID: targetID,
                        sourceEditor: editor,
                        proposedSourceID: proposedID
                    )
                case let .existingBook(source):
                    preview = try await catalog.mergePreview(targetID: targetID, sourceID: source.id)
                }
                self?.mergePreview = preview
                self?.mergeSelections = preview.defaultSelections
            } catch {
                self?.operationError = .mergeFailed
            }
            self?.isDuplicateOperationInProgress = false
        }
    }

    func setMergeChoice(_ choice: BookMergeValueChoice, for field: BookMergeField) {
        mergeSelections[field] = choice
    }

    func cancelMergePreview() {
        mergePreview = nil
        mergeSelections = BookMergeSelections()
    }

    func confirmMerge() {
        guard let review = duplicateReview,
              let preview = mergePreview,
              let catalog
        else {
            return
        }
        isDuplicateOperationInProgress = true
        let selections = mergeSelections
        duplicateTask = Task { @MainActor [weak self] in
            do {
                let result: BookMergeResult
                switch review.subject {
                case let .newBook(editor, proposedID):
                    result = try await catalog.mergeNewBook(
                        targetID: preview.target.id,
                        sourceEditor: editor,
                        proposedSourceID: proposedID,
                        selections: selections
                    )
                case let .existingBook(source):
                    result = try await catalog.mergeBooks(
                        targetID: preview.target.id,
                        sourceID: source.id,
                        selections: selections
                    )
                }
                await self?.reloadBooks(selecting: result.retainedBook.id)
                self?.organizer.load()
                self?.editorSession = nil
                self?.clearDuplicateReview()
            } catch {
                self?.operationError = .mergeFailed
            }
            self?.isDuplicateOperationInProgress = false
        }
    }

    func beginDelete() {
        guard let selectedBook else {
            return
        }
        deletionCandidate = selectedBook
    }

    func cancelDelete() {
        deletionCandidate = nil
    }

    func confirmDelete() {
        guard let candidate = deletionCandidate, let catalog else {
            deletionCandidate = nil
            operationError = .databaseUnavailable
            return
        }

        queryTask?.cancel()
        queryTask = Task { [weak self] in
            do {
                try await catalog.deleteBook(candidate)
                guard !Task.isCancelled else { return }
                await self?.reloadBooks(selecting: nil)
                self?.selectedBookID = nil
                self?.deletionCandidate = nil
                self?.organizer.load()
            } catch {
                self?.deletionCandidate = nil
                self?.operationError = .deleteFailed
            }
        }
    }

    func dismissOperationError() {
        operationError = nil
    }

    func waitForPendingWork() async {
        await queryTask?.value
        await duplicateTask?.value
        await organizer.waitForPendingWork()
        await graph.waitForPendingWork()
    }

    private func scheduleQuery(delay: Duration?) {
        guard let catalog else {
            loadingState = .failed(.databaseUnavailable)
            return
        }

        queryTask?.cancel()
        let requestID = UUID()
        activeRequestID = requestID
        let requestedQuery = query
        isQuerying = true
        queryTask = Task { [weak self] in
            do {
                if let delay {
                    try await Task.sleep(for: delay)
                }
                try Task.checkCancellation()
                let books = try await catalog.queryBooks(requestedQuery)
                try Task.checkCancellation()
                guard let self, self.activeRequestID == requestID else {
                    return
                }
                self.apply(books, selecting: self.selectedBookID)
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.activeRequestID == requestID else {
                    return
                }
                self.books = []
                self.selectedBookID = nil
                self.isQuerying = false
                self.loadingState = .failed(.loadFailed)
            }
        }
    }

    private func reloadBooks(selecting id: UUID?) async {
        guard let catalog else {
            return
        }
        do {
            let refreshed = try await catalog.queryBooks(query)
            apply(refreshed, selecting: id)
        } catch {
            books = []
            selectedBookID = nil
            isQuerying = false
            loadingState = .failed(.loadFailed)
        }
    }

    private func apply(_ books: [Book], selecting id: UUID?) {
        self.books = books
        if let id, books.contains(where: { $0.id == id }) {
            selectedBookID = id
        } else if let selectedBookID, books.contains(where: { $0.id == selectedBookID }) {
            self.selectedBookID = selectedBookID
        } else {
            selectedBookID = books.first?.id
        }
        isQuerying = false
        loadingState = .content
    }

    private func toggle<Value: Hashable>(_ value: Value, in values: inout Set<Value>) {
        if values.contains(value) {
            values.remove(value)
        } else {
            values.insert(value)
        }
    }

    private func presentDuplicateReview(_ review: DuplicateReviewSession) {
        duplicateReview = review
        selectedDuplicateID = review.candidates.first?.id
        viewedDuplicateBook = nil
        duplicateReadingEntries.reset()
        mergePreview = nil
        mergeSelections = BookMergeSelections()
    }

    private func clearDuplicateReview() {
        duplicateReview = nil
        selectedDuplicateID = nil
        viewedDuplicateBook = nil
        duplicateReadingEntries.reset()
        mergePreview = nil
        mergeSelections = BookMergeSelections()
    }

    private nonisolated static func makeInMemoryCatalog(
        seedFictionalUITestBooks: Bool,
        seedMergePreviewAssociations: Bool,
        seedGraphUITestData: Bool,
        seedGraphLimitUITestData: Bool,
        seedReadingEntryUITestData: Bool
    ) throws -> LibraryCatalogService {
        let repository = try BookRepository.inMemory()
        guard seedFictionalUITestBooks
            || seedMergePreviewAssociations
            || seedGraphUITestData
            || seedGraphLimitUITestData
            || seedReadingEntryUITestData
        else {
            return LibraryCatalogService(repository: repository)
        }

        let timestamp = Date(timeIntervalSince1970: 1_735_689_600)
        if seedFictionalUITestBooks || seedReadingEntryUITestData {
            _ = try repository.create(
                BookDraft(
                    title: "A101",
                    author: "Harbor Author",
                    isbn: "9780000000002"
                ),
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                at: timestamp
            )
            _ = try repository.create(
                BookDraft(
                    title: seedReadingEntryUITestData ? "A101" : "B202",
                    author: seedReadingEntryUITestData ? "Harbor Author" : "Forest Author",
                    isbn: seedReadingEntryUITestData ? "9780000000002" : ""
                ),
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
                at: timestamp.addingTimeInterval(1)
            )
        }
        if seedReadingEntryUITestData {
            let bookID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
            _ = try repository.addExternalLink(
                ExternalLink(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000901")!,
                    bookID: bookID,
                    kind: .web,
                    label: "虚构公开入口",
                    value: "https://reader.example.invalid/private-segment",
                    createdAt: timestamp
                )
            )
            _ = try repository.addLocalFileReference(
                LocalFileReference(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000902")!,
                    bookID: bookID,
                    displayName: "虚构阅读副本.pdf",
                    bookmarkData: Data("fixed-fictional-ui-bookmark".utf8),
                    createdAt: timestamp
                )
            )
            let candidateBookID = UUID(
                uuidString: "00000000-0000-0000-0000-000000000202"
            )!
            _ = try repository.addExternalLink(
                ExternalLink(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000903")!,
                    bookID: candidateBookID,
                    kind: .web,
                    label: "候选虚构入口",
                    value: "https://candidate.example.invalid/private-candidate",
                    createdAt: timestamp
                )
            )
            _ = try repository.addLocalFileReference(
                LocalFileReference(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000904")!,
                    bookID: candidateBookID,
                    displayName: "候选虚构阅读副本.pdf",
                    bookmarkData: Data("fixed-fictional-candidate-bookmark".utf8),
                    createdAt: timestamp
                )
            )
        }
        if seedMergePreviewAssociations {
            try Self.seedMergePreviewAssociations(in: repository, at: timestamp)
        }
        if seedGraphUITestData || seedGraphLimitUITestData {
            try Self.seedGraphData(
                in: repository,
                at: timestamp,
                includesLimitFixture: seedGraphLimitUITestData
            )
        }
        return LibraryCatalogService(repository: repository)
    }

    private nonisolated static func seedGraphData(
        in repository: BookRepository,
        at timestamp: Date,
        includesLimitFixture: Bool
    ) throws {
        let center = try repository.create(
            BookDraft(
                title: "《雾港图谱中心》",
                author: "林雾",
                isbn: "9780000000601"
            ),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000601")!,
            at: timestamp
        )
        let direct = try repository.create(
            BookDraft(title: "《雾港直接邻居》", author: "林雾"),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000602")!,
            at: timestamp.addingTimeInterval(1)
        )
        let second = try repository.create(
            BookDraft(title: "《北岸第二层》", author: "沈遥"),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000603")!,
            at: timestamp.addingTimeInterval(2)
        )
        let sharedTag = try repository.createTag(
            try Tag(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000611")!,
                name: "潮汐图谱",
                createdAt: timestamp
            )
        )
        let bridgeTag = try repository.createTag(
            try Tag(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000612")!,
                name: "北岸桥接",
                createdAt: timestamp
            )
        )
        let collection = try repository.createCollection(
            try BookCollection(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000621")!,
                name: "虚构局部书单",
                createdAt: timestamp
            )
        )
        let source = try repository.createSource(
            try RecommendationSource(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000631")!,
                name: "虚构图谱来源",
                createdAt: timestamp
            )
        )
        for bookID in [center.id, direct.id] {
            try repository.attach(tagID: sharedTag.id, toBookID: bookID)
            try repository.add(bookID: bookID, toCollectionID: collection.id)
            try repository.attach(sourceID: source.id, toBookID: bookID)
        }
        for bookID in [direct.id, second.id] {
            try repository.attach(tagID: bridgeTag.id, toBookID: bookID)
        }
        _ = try repository.addManualRelation(
            try ManualBookRelation(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000641")!,
                sourceBookID: center.id,
                targetBookID: direct.id,
                kind: .respondsTo,
                note: "固定虚构图谱备注",
                createdAt: timestamp
            )
        )

        if includesLimitFixture {
            try repository.transaction {
                for index in 0 ..< 82 {
                    let id = UUID(
                        uuidString: String(
                            format: "00000000-0000-0000-0000-%012d",
                            700 + index
                        )
                    )!
                    _ = try repository.create(
                        BookDraft(
                            title: String(format: "《上限邻居 %03d》", index),
                            author: center.author
                        ),
                        id: id,
                        at: timestamp.addingTimeInterval(Double(index + 10))
                    )
                }
            }
        }
    }

    private nonisolated static func seedMergePreviewAssociations(
        in repository: BookRepository,
        at timestamp: Date
    ) throws {
        let target = try repository.create(
            BookDraft(title: "《关联港湾》", author: "林雾"),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!,
            at: timestamp
        )
        let source = try repository.create(
            BookDraft(title: "关联港湾", author: "林雾"),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000402")!,
            at: timestamp.addingTimeInterval(2)
        )
        let related = try repository.create(
            BookDraft(title: "《虚构灯塔》", author: "沈遥"),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000403")!,
            at: timestamp.addingTimeInterval(1)
        )
        let targetTag = try repository.createTag(
            try Tag(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000411")!,
                name: "保留标签",
                createdAt: timestamp
            )
        )
        let sourceTag = try repository.createTag(
            try Tag(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000412")!,
                name: "新增标签",
                createdAt: timestamp
            )
        )
        let collection = try repository.createCollection(
            try BookCollection(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000421")!,
                name: "虚构港湾书单",
                createdAt: timestamp
            )
        )
        let recommendation = try repository.createSource(
            try RecommendationSource(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000431")!,
                name: "虚构纸页来源",
                createdAt: timestamp
            )
        )
        try repository.attach(tagID: targetTag.id, toBookID: target.id)
        try repository.attach(tagID: sourceTag.id, toBookID: source.id)
        try repository.add(bookID: source.id, toCollectionID: collection.id)
        try repository.attach(sourceID: recommendation.id, toBookID: source.id)
        _ = try repository.addExternalLink(
            try ExternalLink(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000441")!,
                bookID: target.id,
                kind: .web,
                label: "保留书页",
                value: "https://example.invalid/retained",
                createdAt: timestamp
            )
        )
        _ = try repository.addExternalLink(
            try ExternalLink(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000442")!,
                bookID: source.id,
                kind: .web,
                label: "新增书页",
                value: "https://example.invalid/incoming",
                createdAt: timestamp
            )
        )
        _ = try repository.addManualRelation(
            try ManualBookRelation(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000451")!,
                sourceBookID: source.id,
                targetBookID: related.id,
                kind: .respondsTo,
                note: "固定虚构关系备注",
                createdAt: timestamp
            )
        )
    }
}
