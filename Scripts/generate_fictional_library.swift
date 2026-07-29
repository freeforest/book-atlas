import Foundation

struct GeneratorArguments {
    let count: Int
    let seed: UInt64
    let outputURL: URL

    static func parse(_ values: [String]) throws -> GeneratorArguments {
        enum ArgumentError: Error { case usage }
        var count: Int?
        var seed: UInt64 = 20_260_730
        var output: String?
        var index = 1
        while index < values.count {
            guard index + 1 < values.count else { throw ArgumentError.usage }
            switch values[index] {
            case "--count":
                count = Int(values[index + 1])
            case "--seed":
                seed = UInt64(values[index + 1]) ?? 0
            case "--output":
                output = values[index + 1]
            default:
                throw ArgumentError.usage
            }
            index += 2
        }
        guard let count, (1 ... 10_000).contains(count),
              let output, !output.isEmpty
        else { throw ArgumentError.usage }
        return GeneratorArguments(
            count: count,
            seed: seed,
            outputURL: URL(fileURLWithPath: output)
        )
    }
}

struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    mutating func index(under upperBound: Int) -> Int {
        Int(next() % UInt64(upperBound))
    }
}

struct Fixture: Codable {
    let format: String
    let seed: UInt64
    let books: [FixtureBook]
    let tags: [FixtureOrganization]
    let collections: [FixtureOrganization]
    let sources: [FixtureOrganization]
    let externalLinks: [FixtureLink]
    let manualRelations: [FixtureRelation]
}

struct FixtureBook: Codable {
    let id: String
    let title: String
    let author: String
    let readingStatus: String
    let tagIDs: [String]
    let collectionIDs: [String]
    let sourceIDs: [String]
}

struct FixtureOrganization: Codable {
    let id: String
    let name: String
}

struct FixtureLink: Codable {
    let id: String
    let bookID: String
    let label: String
    let value: String
}

struct FixtureRelation: Codable {
    let id: String
    let sourceBookID: String
    let targetBookID: String
    let kind: String
    let hasNote: Bool
}

func identifier(namespace: Int, value: Int) -> String {
    String(format: "%08x-0000-0000-%04x-%012x", namespace, value % 65_536, value)
}

do {
    let arguments = try GeneratorArguments.parse(CommandLine.arguments)
    guard !FileManager.default.fileExists(atPath: arguments.outputURL.path) else {
        throw CocoaError(.fileWriteFileExists)
    }
    var random = SeededGenerator(seed: arguments.seed)
    let organizationCount = max(4, min(40, arguments.count / 250))
    let tags = (0 ..< organizationCount).map {
        FixtureOrganization(id: identifier(namespace: 0xA0, value: $0), name: "虚构标签 \($0)")
    }
    let collections = (0 ..< organizationCount).map {
        FixtureOrganization(id: identifier(namespace: 0xB0, value: $0), name: "虚构书单 \($0)")
    }
    let sources = (0 ..< organizationCount).map {
        FixtureOrganization(id: identifier(namespace: 0xC0, value: $0), name: "虚构来源 \($0)")
    }
    let statuses = ["wish_to_read", "reading", "read", "paused", "archived"]
    var books: [FixtureBook] = []
    var links: [FixtureLink] = []
    var relations: [FixtureRelation] = []
    books.reserveCapacity(arguments.count)

    for index in 0 ..< arguments.count {
        let previousDuplicate = index > 0 && index.isMultiple(of: 250)
        let titleIndex = previousDuplicate ? index - 1 : index
        let authorIndex = previousDuplicate ? index - 1 : random.index(under: 173)
        let bookID = identifier(namespace: 0xD0, value: index)
        books.append(
            FixtureBook(
                id: bookID,
                title: "固定虚构书 \(String(titleIndex, radix: 36))",
                author: "固定虚构作者 \(authorIndex)",
                readingStatus: statuses[index % statuses.count],
                tagIDs: [tags[index % tags.count].id],
                collectionIDs: index.isMultiple(of: 3)
                    ? [collections[index % collections.count].id]
                    : [],
                sourceIDs: index.isMultiple(of: 5)
                    ? [sources[index % sources.count].id]
                    : []
            )
        )
        if index.isMultiple(of: 20) {
            links.append(
                FixtureLink(
                    id: identifier(namespace: 0xE0, value: index),
                    bookID: bookID,
                    label: "固定虚构入口",
                    value: "https://example.invalid/fixture/\(index)"
                )
            )
        }
        if index > 0, index.isMultiple(of: 10) {
            relations.append(
                FixtureRelation(
                    id: identifier(namespace: 0xF0, value: index),
                    sourceBookID: bookID,
                    targetBookID: books[index - 1].id,
                    kind: "related",
                    hasNote: index.isMultiple(of: 30)
                )
            )
        }
    }

    let fixture = Fixture(
        format: "bookatlas-fictional-performance/1",
        seed: arguments.seed,
        books: books,
        tags: tags,
        collections: collections,
        sources: sources,
        externalLinks: links,
        manualRelations: relations
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(fixture)
    try data.write(to: arguments.outputURL, options: .withoutOverwriting)
    print(
        "Wrote fictional fixture: books=\(books.count) links=\(links.count) "
            + "relations=\(relations.count) seed=\(arguments.seed)"
    )
} catch {
    FileHandle.standardError.write(
        Data(
            """
            Usage: swift Scripts/generate_fictional_library.swift \
            --count <1...10000> --seed <integer> --output <new-file>
            The destination must not already exist.

            """.utf8
        )
    )
    exit(2)
}
