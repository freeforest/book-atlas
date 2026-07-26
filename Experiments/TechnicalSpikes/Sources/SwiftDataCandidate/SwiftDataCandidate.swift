import Foundation
import SwiftData

@Model
public final class SwiftDataBook {
    @Attribute(.unique) public var id: String
    public var title: String
    @Relationship(deleteRule: .cascade, inverse: \SwiftDataCredit.book)
    public var credits: [SwiftDataCredit]

    public init(id: String, title: String) {
        self.id = id
        self.title = title
        credits = []
    }
}

@Model
public final class SwiftDataContributor {
    @Attribute(.unique) public var id: String
    public var name: String
    @Relationship(deleteRule: .cascade, inverse: \SwiftDataCredit.contributor)
    public var credits: [SwiftDataCredit]

    public init(id: String, name: String) {
        self.id = id
        self.name = name
        credits = []
    }
}

@Model
public final class SwiftDataCredit {
    public var role: String
    public var book: SwiftDataBook?
    public var contributor: SwiftDataContributor?

    public init(
        role: String,
        book: SwiftDataBook,
        contributor: SwiftDataContributor
    ) {
        self.role = role
        self.book = book
        self.contributor = contributor
    }
}

@MainActor
public enum SwiftDataProbe {
    public static func exerciseInMemory() throws -> Int {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SwiftDataBook.self,
            SwiftDataContributor.self,
            SwiftDataCredit.self,
            configurations: configuration
        )
        let context = container.mainContext
        let book = SwiftDataBook(id: "swiftdata-book", title: "星图索引")
        let contributor = SwiftDataContributor(
            id: "swiftdata-author",
            name: "许澄野"
        )
        let credit = SwiftDataCredit(
            role: "author",
            book: book,
            contributor: contributor
        )
        context.insert(book)
        context.insert(contributor)
        context.insert(credit)
        try context.save()

        let descriptor = FetchDescriptor<SwiftDataBook>(
            predicate: #Predicate { $0.id == "swiftdata-book" }
        )
        let fetched = try context.fetch(descriptor)
        return fetched.first?.credits.count ?? 0
    }
}

