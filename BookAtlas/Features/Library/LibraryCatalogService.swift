import Foundation

protocol LibraryCataloging: AnyObject {
    func loadBooks() throws -> [Book]
    func createBook(from editor: BookEditorDraft) throws -> Book
    func updateBook(_ book: Book, from editor: BookEditorDraft) throws -> Book
    func deleteBook(_ book: Book) throws
}

final class LibraryCatalogService: LibraryCataloging {
    private let repository: BookRepository
    private let now: () -> Date

    init(repository: BookRepository, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.now = now
    }

    func loadBooks() throws -> [Book] {
        try repository.list(limit: 500)
    }

    func createBook(from editor: BookEditorDraft) throws -> Book {
        try repository.create(editor.makeBookDraft(), at: now())
    }

    func updateBook(_ book: Book, from editor: BookEditorDraft) throws -> Book {
        let updated = try book.applying(editor.makeBookDraft(), at: now())
        try repository.update(updated)
        return updated
    }

    func deleteBook(_ book: Book) throws {
        try repository.deleteBook(id: book.id)
    }
}
