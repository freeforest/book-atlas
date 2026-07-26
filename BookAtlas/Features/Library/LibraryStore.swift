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
    @Published var selectedBookID: UUID?
    @Published var editorSession: BookEditorSession?
    @Published var deletionCandidate: Book?
    @Published var saveRequestID = 0
    @Published var operationError: LibraryUserFacingError?

    private let catalog: (any LibraryCataloging)?

    init(catalog: (any LibraryCataloging)? = nil, initialError: LibraryUserFacingError? = nil) {
        self.catalog = catalog
        if let initialError {
            loadingState = .failed(initialError)
        } else if catalog != nil {
            load()
        } else {
            loadingState = .failed(.databaseUnavailable)
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
            let repository: BookRepository
            if arguments.contains("-BookAtlasUseInMemoryStore") || environment["XCTestConfigurationFilePath"] != nil {
                repository = try BookRepository.inMemory()
            } else {
                repository = try BookRepository(databaseURL: BookAtlasDatabaseLocation.defaultURL())
            }
            return LibraryStore(catalog: LibraryCatalogService(repository: repository))
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

    func load() {
        guard let catalog else {
            loadingState = .failed(.databaseUnavailable)
            return
        }

        loadingState = .loading
        do {
            books = try catalog.loadBooks()
            if let selectedBookID, books.contains(where: { $0.id == selectedBookID }) {
                self.selectedBookID = selectedBookID
            } else {
                selectedBookID = books.first?.id
            }
            loadingState = .content
        } catch {
            books = []
            selectedBookID = nil
            loadingState = .failed(.loadFailed)
        }
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

    func save(_ draft: BookEditorDraft, for session: BookEditorSession) -> Result<Void, LibraryUserFacingError> {
        guard let catalog else {
            return .failure(.databaseUnavailable)
        }

        do {
            let savedBook: Book
            switch session.mode {
            case .create:
                savedBook = try catalog.createBook(from: draft)
            case let .edit(book):
                savedBook = try catalog.updateBook(book, from: draft)
            }
            try replaceBooks(using: catalog, selecting: savedBook.id)
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

        do {
            try catalog.deleteBook(candidate)
            try replaceBooks(using: catalog, selecting: nil)
            selectedBookID = nil
            deletionCandidate = nil
        } catch {
            deletionCandidate = nil
            operationError = .deleteFailed
        }
    }

    func dismissOperationError() {
        operationError = nil
    }

    private func replaceBooks(using catalog: any LibraryCataloging, selecting id: UUID?) throws {
        books = try catalog.loadBooks()
        selectedBookID = id ?? (books.contains { $0.id == selectedBookID } ? selectedBookID : books.first?.id)
        loadingState = .content
    }
}
