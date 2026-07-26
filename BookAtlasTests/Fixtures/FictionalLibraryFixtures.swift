import Foundation
@testable import BookAtlas

enum FictionalLibraryFixtures {
    static let timestamp = Date(timeIntervalSince1970: 1_735_689_600)

    static func draft(
        title: String = "《雾港档案》",
        author: String = "林雾",
        status: ReadingStatus = .wishToRead
    ) -> BookDraft {
        BookDraft(
            title: title,
            originalTitle: "The Mist Harbor Files",
            author: author,
            isbn: "978-0-000-00000-0",
            publisher: "银潮出版社",
            publicationDate: try! PublicationDate(year: 2024, month: 5),
            kind: .book,
            readingStatus: status,
            priority: BookPriority(rawValue: 3),
            note: "虚构测试书目。",
            startedAt: timestamp,
            finishedAt: nil
        )
    }

    static func allDrafts() -> [BookDraft] {
        [
            draft(title: "《雾港档案》", author: "林雾"),
            draft(title: "《机器与花园》", author: "周栩", status: .reading),
            draft(title: "《星图索引》", author: "沈遥", status: .read),
            draft(title: "《静默算法》", author: "顾弦", status: .reference),
            draft(title: "《北岸来信》", author: "许岸", status: .paused)
        ]
    }

    static func tag() -> Tag {
        try! Tag(name: "潮汐理论", createdAt: timestamp)
    }

    static func collection() -> BookCollection {
        try! BookCollection(name: "虚构北岸书单", description: "仅供自动化测试。", createdAt: timestamp)
    }

    static func source() -> RecommendationSource {
        try! RecommendationSource(name: "晨星纸刊", details: "虚构推荐来源。", createdAt: timestamp)
    }
}
