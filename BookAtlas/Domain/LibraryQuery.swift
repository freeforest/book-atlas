import Foundation

enum LibrarySortField: String, CaseIterable, Sendable {
    case createdAt
    case updatedAt
    case priority
}

enum LibrarySortDirection: String, CaseIterable, Sendable {
    case ascending
    case descending
}

/// Structured catalog query.
///
/// Different filter families are combined with AND. Reading statuses within
/// their family use OR because a book has one status. Tags, collections, and
/// sources within their families use AND so every selected association must
/// be present.
struct LibraryQuery: Equatable, Sendable {
    var searchText: String = ""
    var readingStatuses: Set<ReadingStatus> = []
    var tagIDs: Set<UUID> = []
    var collectionIDs: Set<UUID> = []
    var sourceIDs: Set<UUID> = []
    var sortField: LibrarySortField = .updatedAt
    var sortDirection: LibrarySortDirection = .descending
    var limit: Int = 500
    var offset: Int = 0

    var normalizedSearchText: String {
        searchText
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    var hasFilters: Bool {
        !normalizedSearchText.isEmpty
            || !readingStatuses.isEmpty
            || !tagIDs.isEmpty
            || !collectionIDs.isEmpty
            || !sourceIDs.isEmpty
    }

    mutating func clearFilters() {
        searchText = ""
        readingStatuses = []
        tagIDs = []
        collectionIDs = []
        sourceIDs = []
        offset = 0
    }
}

struct TagSummary: Identifiable, Equatable, Sendable {
    let tag: Tag
    let bookCount: Int

    var id: UUID { tag.id }
}

struct CollectionSummary: Identifiable, Equatable, Sendable {
    let collection: BookCollection
    let bookCount: Int

    var id: UUID { collection.id }
}

struct SourceSummary: Identifiable, Equatable, Sendable {
    let source: RecommendationSource
    let bookCount: Int

    var id: UUID { source.id }
}

struct BookMembership: Equatable, Sendable {
    var tagIDs: Set<UUID>
    var collectionIDs: Set<UUID>
    var sourceIDs: Set<UUID>

    static let empty = BookMembership(tagIDs: [], collectionIDs: [], sourceIDs: [])
}

struct CatalogSnapshot: Equatable, Sendable {
    var tags: [TagSummary]
    var collections: [CollectionSummary]
    var sources: [SourceSummary]

    static let empty = CatalogSnapshot(tags: [], collections: [], sources: [])
}

enum BookAssociation: Equatable, Sendable {
    case tag(UUID)
    case collection(UUID)
    case source(UUID)
}

enum CatalogNameNormalizer {
    static func displayName(_ value: String) throws -> String {
        let normalized = value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !normalized.isEmpty else {
            throw DomainValidationError.blankName
        }
        return normalized
    }

    static func comparisonKey(_ value: String) throws -> String {
        try displayName(value).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}

enum ISBNNormalizer {
    static func normalize(_ value: String) -> String {
        value
            .filter { !$0.isWhitespace && $0 != "-" }
            .uppercased()
    }
}
