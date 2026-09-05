import Foundation

enum DomainValidationError: Error, Equatable {
    case blankTitle
    case blankAuthor
    case blankName
    case priorityOutOfRange
    case invalidPublicationDate
    case blankExternalLinkValue
    case invalidLocalFileDisplayName
    case invalidBookmarkData
    case selfRelation
}

enum ReadingStatus: String, CaseIterable, Codable, Sendable {
    case wishToRead = "wish_to_read"
    case reading
    case read
    case paused
    case abandoned
    case reference
    case archived
}

enum BookKind: String, CaseIterable, Codable, Sendable {
    case book
    case essayCollection = "essay_collection"
    case reference
    case other
}

struct BookPriority: RawRepresentable, Equatable, Comparable, Codable, Sendable {
    let rawValue: Int

    init?(rawValue: Int) {
        guard (1 ... 5).contains(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    static func < (lhs: BookPriority, rhs: BookPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct PublicationDate: Equatable, Codable, Sendable {
    let year: Int
    let month: Int?
    let day: Int?

    init(year: Int, month: Int? = nil, day: Int? = nil) throws {
        guard (1 ... 9_999).contains(year) else {
            throw DomainValidationError.invalidPublicationDate
        }
        guard day == nil || month != nil else {
            throw DomainValidationError.invalidPublicationDate
        }

        if let month {
            guard (1 ... 12).contains(month) else {
                throw DomainValidationError.invalidPublicationDate
            }
        }

        if let day, let month {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            var components = DateComponents()
            components.calendar = calendar
            components.timeZone = TimeZone(secondsFromGMT: 0)
            components.year = year
            components.month = month
            components.day = day
            guard let date = calendar.date(from: components) else {
                throw DomainValidationError.invalidPublicationDate
            }
            let normalized = calendar.dateComponents([.year, .month, .day], from: date)
            guard normalized.year == year, normalized.month == month, normalized.day == day else {
                throw DomainValidationError.invalidPublicationDate
            }
        }

        self.year = year
        self.month = month
        self.day = day
    }

    init(storageValue: String) throws {
        let parts = storageValue.split(separator: "-", omittingEmptySubsequences: false)
        guard let year = Int(parts.first ?? "") else {
            throw DomainValidationError.invalidPublicationDate
        }

        switch parts.count {
        case 1:
            try self.init(year: year)
        case 2:
            guard let month = Int(parts[1]) else {
                throw DomainValidationError.invalidPublicationDate
            }
            try self.init(year: year, month: month)
        case 3:
            guard let month = Int(parts[1]), let day = Int(parts[2]) else {
                throw DomainValidationError.invalidPublicationDate
            }
            try self.init(year: year, month: month, day: day)
        default:
            throw DomainValidationError.invalidPublicationDate
        }
    }

    var storageValue: String {
        switch (month, day) {
        case let (.some(month), .some(day)):
            String(format: "%04d-%02d-%02d", year, month, day)
        case let (.some(month), .none):
            String(format: "%04d-%02d", year, month)
        case (.none, .none):
            String(format: "%04d", year)
        case (.none, .some):
            // The initializer prevents this state; keeping the fallback avoids a trap
            // if a future decoder receives malformed data.
            String(format: "%04d", year)
        }
    }
}

struct BookDraft: Equatable, Sendable {
    var title: String
    var originalTitle: String?
    var author: String
    var isbn: String?
    var publisher: String?
    var publicationDate: PublicationDate?
    var kind: BookKind
    var readingStatus: ReadingStatus
    var priority: BookPriority?
    var note: String?
    var startedAt: Date?
    var finishedAt: Date?

    init(
        title: String,
        originalTitle: String? = nil,
        author: String,
        isbn: String? = nil,
        publisher: String? = nil,
        publicationDate: PublicationDate? = nil,
        kind: BookKind = .book,
        readingStatus: ReadingStatus = .wishToRead,
        priority: BookPriority? = nil,
        note: String? = nil,
        startedAt: Date? = nil,
        finishedAt: Date? = nil
    ) {
        self.title = title
        self.originalTitle = originalTitle
        self.author = author
        self.isbn = isbn
        self.publisher = publisher
        self.publicationDate = publicationDate
        self.kind = kind
        self.readingStatus = readingStatus
        self.priority = priority
        self.note = note
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    fileprivate func normalized() throws -> BookDraft {
        let normalizedTitle = try required(title, error: .blankTitle)
        let normalizedAuthor = try required(author, error: .blankAuthor)

        return BookDraft(
            title: normalizedTitle,
            originalTitle: optional(originalTitle),
            author: normalizedAuthor,
            isbn: optional(isbn),
            publisher: optional(publisher),
            publicationDate: publicationDate,
            kind: kind,
            readingStatus: readingStatus,
            priority: priority,
            note: optional(note),
            startedAt: startedAt,
            finishedAt: finishedAt
        )
    }
}

struct Book: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let originalTitle: String?
    let author: String
    let isbn: String?
    let publisher: String?
    let publicationDate: PublicationDate?
    let kind: BookKind
    let readingStatus: ReadingStatus
    let priority: BookPriority?
    let note: String?
    let createdAt: Date
    let updatedAt: Date
    let startedAt: Date?
    let finishedAt: Date?

    init(id: UUID = UUID(), draft: BookDraft, createdAt: Date = Date(), updatedAt: Date? = nil) throws {
        let normalized = try draft.normalized()
        self.id = id
        title = normalized.title
        originalTitle = normalized.originalTitle
        author = normalized.author
        isbn = normalized.isbn
        publisher = normalized.publisher
        publicationDate = normalized.publicationDate
        kind = normalized.kind
        readingStatus = normalized.readingStatus
        priority = normalized.priority
        note = normalized.note
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        startedAt = normalized.startedAt
        finishedAt = normalized.finishedAt
    }

    func applying(_ draft: BookDraft, at date: Date = Date()) throws -> Book {
        try Book(id: id, draft: draft, createdAt: createdAt, updatedAt: date)
    }
}

struct Tag: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), updatedAt: Date? = nil) throws {
        self.id = id
        self.name = try CatalogNameNormalizer.displayName(name)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

struct BookCollection: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) throws {
        self.id = id
        self.name = try CatalogNameNormalizer.displayName(name)
        self.description = optional(description)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

struct RecommendationSource: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let details: String?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        details: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) throws {
        self.id = id
        self.name = try CatalogNameNormalizer.displayName(name)
        self.details = optional(details)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

enum ExternalLinkKind: String, CaseIterable, Codable, Sendable {
    case web
    case localAuthorization = "local_authorization"
}

struct ExternalLink: Identifiable, Equatable, Sendable {
    let id: UUID
    let bookID: UUID
    let kind: ExternalLinkKind
    let label: String?
    let value: String
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID = UUID(),
        bookID: UUID,
        kind: ExternalLinkKind,
        label: String? = nil,
        value: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) throws {
        self.id = id
        self.bookID = bookID
        self.kind = kind
        self.label = optional(label)
        self.value = try required(value, error: .blankExternalLinkValue)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

struct LocalFileReference: Identifiable, Equatable, Sendable {
    /// A security-scoped bookmark is normally only a few kilobytes. One MiB
    /// leaves generous headroom while bounding every database read and backup
    /// validation allocation.
    static let maximumBookmarkBytes = 1_048_576
    static let maximumDisplayNameLength = 512

    let id: UUID
    let bookID: UUID
    let displayName: String
    let bookmarkData: Data
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID = UUID(),
        bookID: UUID,
        displayName: String,
        bookmarkData: Data,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) throws {
        guard Self.isCanonicalDisplayName(displayName) else {
            throw DomainValidationError.invalidLocalFileDisplayName
        }
        guard !bookmarkData.isEmpty,
              bookmarkData.count <= Self.maximumBookmarkBytes
        else { throw DomainValidationError.invalidBookmarkData }
        self.id = id
        self.bookID = bookID
        self.displayName = displayName
        self.bookmarkData = bookmarkData
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    static func isCanonicalDisplayName(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.count <= maximumDisplayNameLength,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              value != ".",
              value != "..",
              !value.contains("/"),
              !value.contains("\\")
        else { return false }
        return !value.unicodeScalars.contains {
            $0.value <= 0x1F || $0.value == 0x7F
        }
    }
}

enum ManualRelationKind: String, CaseIterable, Codable, Hashable, Sendable {
    case related
    case inspiredBy = "inspired_by"
    case respondsTo = "responds_to"
    case companion
}

struct ManualBookRelation: Identifiable, Equatable, Sendable {
    let id: UUID
    let sourceBookID: UUID
    let targetBookID: UUID
    let kind: ManualRelationKind
    let note: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        sourceBookID: UUID,
        targetBookID: UUID,
        kind: ManualRelationKind,
        note: String? = nil,
        createdAt: Date = Date()
    ) throws {
        guard sourceBookID != targetBookID else {
            throw DomainValidationError.selfRelation
        }
        self.id = id
        self.sourceBookID = sourceBookID
        self.targetBookID = targetBookID
        self.kind = kind
        self.note = optional(note)
        self.createdAt = createdAt
    }
}

private func required(_ value: String, error: DomainValidationError) throws -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        throw error
    }
    return trimmed
}

private func optional(_ value: String?) -> String? {
    guard let value else {
        return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
