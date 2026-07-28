import Foundation
import SwiftUI

enum LibraryUserFacingError: Error, Equatable {
    case databaseUnavailable
    case loadFailed
    case saveFailed
    case deleteFailed
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

    let organizer: CatalogOrganizerStore

    private let catalog: (any LibraryCataloging)?
    private var queryTask: Task<Void, Never>?
    private var activeRequestID = UUID()

    init(catalog: (any LibraryCataloging)? = nil, initialError: LibraryUserFacingError? = nil) {
        self.catalog = catalog
        organizer = CatalogOrganizerStore(catalog: catalog)
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
            let catalog: LibraryCatalogService
            if arguments.contains("-BookAtlasUseInMemoryStore") || environment["XCTestConfigurationFilePath"] != nil {
                catalog = try Self.makeInMemoryCatalog(
                    seedFictionalUITestBooks: arguments.contains("-BookAtlasSeedFictionalUITestBooks")
                )
            } else {
                catalog = LibraryCatalogService(
                    repository: try BookRepository(databaseURL: BookAtlasDatabaseLocation.defaultURL())
                )
            }
            return LibraryStore(catalog: catalog)
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
        deletionCandidate = nil
        editorSession = BookEditorSession(mode: .create)
    }

    func beginEdit() {
        guard let selectedBook else {
            return
        }
        operationError = nil
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
        await organizer.waitForPendingWork()
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

    private nonisolated static func makeInMemoryCatalog(
        seedFictionalUITestBooks: Bool
    ) throws -> LibraryCatalogService {
        let repository = try BookRepository.inMemory()
        guard seedFictionalUITestBooks else {
            return LibraryCatalogService(repository: repository)
        }

        let timestamp = Date(timeIntervalSince1970: 1_735_689_600)
        _ = try repository.create(
            BookDraft(title: "A101", author: "Harbor Author"),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            at: timestamp
        )
        _ = try repository.create(
            BookDraft(title: "B202", author: "Forest Author"),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
            at: timestamp.addingTimeInterval(1)
        )
        return LibraryCatalogService(repository: repository)
    }
}
