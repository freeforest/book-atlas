import Foundation

enum BookEditorValidationError: Error, Equatable {
    case titleRequired
    case authorRequired
    case invalidPublicationDate
    case invalidPriority

    var message: String {
        switch self {
        case .titleRequired:
            "请填写书名。"
        case .authorRequired:
            "请填写作者。"
        case .invalidPublicationDate:
            "出版日期应为 YYYY、YYYY-MM 或 YYYY-MM-DD。"
        case .invalidPriority:
            "优先级应在 1 到 5 之间。"
        }
    }
}

struct BookEditorDraft: Equatable {
    var title: String
    var originalTitle: String
    var author: String
    var isbn: String
    var publisher: String
    var publicationDateText: String
    var kind: BookKind
    var readingStatus: ReadingStatus
    var priorityValue: Int
    var note: String
    var hasStartedAt: Bool
    var startedAt: Date
    var hasFinishedAt: Bool
    var finishedAt: Date

    init(
        title: String = "",
        originalTitle: String = "",
        author: String = "",
        isbn: String = "",
        publisher: String = "",
        publicationDateText: String = "",
        kind: BookKind = .book,
        readingStatus: ReadingStatus = .wishToRead,
        priorityValue: Int = 0,
        note: String = "",
        hasStartedAt: Bool = false,
        startedAt: Date = Date(),
        hasFinishedAt: Bool = false,
        finishedAt: Date = Date()
    ) {
        self.title = title
        self.originalTitle = originalTitle
        self.author = author
        self.isbn = isbn
        self.publisher = publisher
        self.publicationDateText = publicationDateText
        self.kind = kind
        self.readingStatus = readingStatus
        self.priorityValue = priorityValue
        self.note = note
        self.hasStartedAt = hasStartedAt
        self.startedAt = startedAt
        self.hasFinishedAt = hasFinishedAt
        self.finishedAt = finishedAt
    }

    init(book: Book) {
        self.init(
            title: book.title,
            originalTitle: book.originalTitle ?? "",
            author: book.author,
            isbn: book.isbn ?? "",
            publisher: book.publisher ?? "",
            publicationDateText: book.publicationDate?.storageValue ?? "",
            kind: book.kind,
            readingStatus: book.readingStatus,
            priorityValue: book.priority?.rawValue ?? 0,
            note: book.note ?? "",
            hasStartedAt: book.startedAt != nil,
            startedAt: book.startedAt ?? Date(),
            hasFinishedAt: book.finishedAt != nil,
            finishedAt: book.finishedAt ?? Date()
        )
    }

    func makeBookDraft() throws -> BookDraft {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw BookEditorValidationError.titleRequired
        }

        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAuthor.isEmpty else {
            throw BookEditorValidationError.authorRequired
        }

        let publicationDate: PublicationDate?
        let dateText = publicationDateText.trimmingCharacters(in: .whitespacesAndNewlines)
        if dateText.isEmpty {
            publicationDate = nil
        } else {
            do {
                publicationDate = try PublicationDate(storageValue: dateText)
            } catch {
                throw BookEditorValidationError.invalidPublicationDate
            }
        }

        let priority: BookPriority?
        if priorityValue == 0 {
            priority = nil
        } else if let value = BookPriority(rawValue: priorityValue) {
            priority = value
        } else {
            throw BookEditorValidationError.invalidPriority
        }

        return BookDraft(
            title: trimmedTitle,
            originalTitle: optionalText(originalTitle),
            author: trimmedAuthor,
            isbn: BookEditorDraft.normalizedISBN(isbn),
            publisher: optionalText(publisher),
            publicationDate: publicationDate,
            kind: kind,
            readingStatus: readingStatus,
            priority: priority,
            note: optionalText(note),
            startedAt: hasStartedAt ? startedAt : nil,
            finishedAt: hasFinishedAt ? finishedAt : nil
        )
    }

    static func normalizedISBN(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let normalized = ISBNNormalizer.normalize(trimmed)
        return normalized.isEmpty ? nil : normalized
    }
}

private func optionalText(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
