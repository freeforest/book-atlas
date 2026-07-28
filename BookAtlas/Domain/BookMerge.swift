import Foundation

enum BookMergeField: String, CaseIterable, Sendable {
    case title
    case originalTitle = "original_title"
    case author
    case isbn
    case publisher
    case publicationDate = "publication_date"
    case kind
    case readingStatus = "reading_status"
    case priority
    case note
    case startedAt = "started_at"
    case finishedAt = "finished_at"
}

enum BookMergeValueChoice: String, Sendable {
    case target
    case source
}

struct BookMergeSelections: Equatable, Sendable {
    private var choices: [BookMergeField: BookMergeValueChoice]

    init(choices: [BookMergeField: BookMergeValueChoice] = [:]) {
        self.choices = choices
    }

    subscript(field: BookMergeField) -> BookMergeValueChoice {
        get { choices[field] ?? .target }
        set { choices[field] = newValue }
    }
}

enum BookMergeAssociationOrigin: String, Equatable, Sendable {
    case target
    case source
}

enum BookMergeAssociationOutcome: String, Equatable, Sendable {
    case keep
    case add
    case deduplicate
    case fillMissingLabel
    case block
}

struct BookMergeNamedAssociationDetail: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let origin: BookMergeAssociationOrigin
    let outcome: BookMergeAssociationOutcome
}

struct BookMergeLinkDetail: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: ExternalLinkKind
    let label: String?
    let value: String
    let origin: BookMergeAssociationOrigin
    let outcome: BookMergeAssociationOutcome
}

enum BookMergeRelationDirection: String, Equatable, Sendable {
    case incoming
    case outgoing
}

struct BookMergeRelationDetail: Identifiable, Equatable, Sendable {
    let id: UUID
    let direction: BookMergeRelationDirection
    let kind: ManualRelationKind
    let otherBookID: UUID
    let otherBookTitle: String
    let hasNote: Bool
    let origin: BookMergeAssociationOrigin
    let outcome: BookMergeAssociationOutcome
}

struct BookMergeAssociationSummary: Equatable, Sendable {
    let targetTags: [Tag]
    let sourceTags: [Tag]
    let targetCollections: [BookCollection]
    let sourceCollections: [BookCollection]
    let targetSources: [RecommendationSource]
    let sourceSources: [RecommendationSource]
    let targetLinks: [ExternalLink]
    let sourceLinks: [ExternalLink]
    let manualRelations: [ManualBookRelation]
    let tagDetails: [BookMergeNamedAssociationDetail]
    let collectionDetails: [BookMergeNamedAssociationDetail]
    let sourceDetails: [BookMergeNamedAssociationDetail]
    let linkDetails: [BookMergeLinkDetail]
    let relationDetails: [BookMergeRelationDetail]

    var hasBlockingConflict: Bool {
        linkDetails.contains { $0.outcome == .block }
            || relationDetails.contains { $0.outcome == .block }
    }
}

struct BookMergePreview: Identifiable, Equatable, Sendable {
    let target: Book
    let source: Book
    let conflictingFields: Set<BookMergeField>
    let associations: BookMergeAssociationSummary
    let defaultSelections: BookMergeSelections

    var id: UUID { source.id }
}

struct BookMergeResult: Equatable, Sendable {
    let retainedBook: Book
    let removedBookID: UUID
}

enum BookMergeError: Error, Equatable {
    case sameBook
    case bookNotFound
    case selfRelationConflict
    case relationNoteConflict
    case externalLinkLabelConflict
    case mergeFailed
}

enum BookMergePolicy {
    static func preview(
        target: Book,
        source: Book,
        associations: BookMergeAssociationSummary
    ) -> BookMergePreview {
        var conflicts = Set<BookMergeField>()
        var selections = BookMergeSelections()

        compare(.title, target.title, source.title, conflicts: &conflicts)
        compare(.originalTitle, target.originalTitle, source.originalTitle, conflicts: &conflicts)
        compare(.author, target.author, source.author, conflicts: &conflicts)
        compare(.isbn, target.isbn, source.isbn, conflicts: &conflicts)
        compare(.publisher, target.publisher, source.publisher, conflicts: &conflicts)
        compare(.publicationDate, target.publicationDate, source.publicationDate, conflicts: &conflicts)
        compare(.kind, target.kind, source.kind, conflicts: &conflicts)
        compare(.readingStatus, target.readingStatus, source.readingStatus, conflicts: &conflicts)
        compare(.priority, target.priority, source.priority, conflicts: &conflicts)
        compare(.note, target.note, source.note, conflicts: &conflicts)
        compare(.startedAt, target.startedAt, source.startedAt, conflicts: &conflicts)
        compare(.finishedAt, target.finishedAt, source.finishedAt, conflicts: &conflicts)

        for field in BookMergeField.allCases where !conflicts.contains(field) {
            if targetValueIsMissing(field, in: target), !sourceValueIsMissing(field, in: source) {
                selections[field] = .source
            }
        }

        return BookMergePreview(
            target: target,
            source: source,
            conflictingFields: conflicts,
            associations: associations,
            defaultSelections: selections
        )
    }

    static func mergedBook(
        preview: BookMergePreview,
        selections: BookMergeSelections,
        at mergeDate: Date
    ) throws -> Book {
        let target = preview.target
        let source = preview.source
        let draft = BookDraft(
            title: choose(.title, target.title, source.title, selections),
            originalTitle: choose(.originalTitle, target.originalTitle, source.originalTitle, selections),
            author: choose(.author, target.author, source.author, selections),
            isbn: choose(.isbn, target.isbn, source.isbn, selections),
            publisher: choose(.publisher, target.publisher, source.publisher, selections),
            publicationDate: choose(.publicationDate, target.publicationDate, source.publicationDate, selections),
            kind: choose(.kind, target.kind, source.kind, selections),
            readingStatus: choose(.readingStatus, target.readingStatus, source.readingStatus, selections),
            priority: choose(.priority, target.priority, source.priority, selections),
            note: choose(.note, target.note, source.note, selections),
            startedAt: choose(.startedAt, target.startedAt, source.startedAt, selections),
            finishedAt: choose(.finishedAt, target.finishedAt, source.finishedAt, selections)
        )
        return try Book(
            id: target.id,
            draft: draft,
            createdAt: min(target.createdAt, source.createdAt),
            updatedAt: mergeDate
        )
    }

    private static func compare<Value: Equatable>(
        _ field: BookMergeField,
        _ target: Value,
        _ source: Value,
        conflicts: inout Set<BookMergeField>
    ) {
        if target != source {
            conflicts.insert(field)
        }
    }

    private static func compare<Value: Equatable>(
        _ field: BookMergeField,
        _ target: Value?,
        _ source: Value?,
        conflicts: inout Set<BookMergeField>
    ) {
        if let target, let source, target != source {
            conflicts.insert(field)
        }
    }

    private static func choose<Value>(
        _ field: BookMergeField,
        _ target: Value,
        _ source: Value,
        _ selections: BookMergeSelections
    ) -> Value {
        selections[field] == .source ? source : target
    }

    private static func targetValueIsMissing(_ field: BookMergeField, in book: Book) -> Bool {
        switch field {
        case .originalTitle: book.originalTitle == nil
        case .isbn: book.isbn == nil
        case .publisher: book.publisher == nil
        case .publicationDate: book.publicationDate == nil
        case .priority: book.priority == nil
        case .note: book.note == nil
        case .startedAt: book.startedAt == nil
        case .finishedAt: book.finishedAt == nil
        case .title, .author, .kind, .readingStatus: false
        }
    }

    private static func sourceValueIsMissing(_ field: BookMergeField, in book: Book) -> Bool {
        targetValueIsMissing(field, in: book)
    }
}
