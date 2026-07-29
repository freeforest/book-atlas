import XCTest
@testable import BookAtlas

final class LibraryQueryBenchmarkTests: XCTestCase {
    @MainActor
    func testRepeatableQueryBaselinesAtOneFiveAndTenThousandBooks() throws {
        for size in [1_000, 5_000, 10_000] {
            let repository = try BookRepository.inMemory()
            let tag = try repository.createTag(
                try Tag(name: "BaselineTag", createdAt: FictionalLibraryFixtures.timestamp)
            )

            let insertionStart = ContinuousClock.now
            try repository.transaction {
                for index in 0 ..< size {
                    _ = try repository.create(
                        BookDraft(
                            title: String(format: "Fictional Volume %05d", index),
                            originalTitle: String(format: "Archive %05d", index),
                            author: "Author \(index % 97)",
                            isbn: String(format: "978%010d", index),
                            readingStatus: index.isMultiple(of: 3) ? .reading : .wishToRead,
                            priority: BookPriority(rawValue: (index % 5) + 1)
                        ),
                        id: deterministicID(index),
                        at: FictionalLibraryFixtures.timestamp.addingTimeInterval(TimeInterval(index))
                    )
                }
            }
            let insertionDuration = insertionStart.duration(to: .now)

            let associationStart = ContinuousClock.now
            try repository.transaction {
                for index in stride(from: 0, to: size, by: 10) {
                    try repository.attach(tagID: tag.id, toBookID: deterministicID(index))
                }
            }
            let associationDuration = associationStart.duration(to: .now)

            let queryConstructionStart = ContinuousClock.now
            let searchQuery = LibraryQuery(searchText: "Volume 00042", limit: 100)
            let filterQuery = LibraryQuery(
                readingStatuses: [.reading],
                tagIDs: [tag.id],
                sortField: .priority,
                sortDirection: .descending,
                limit: 100
            )
            let sortQuery = LibraryQuery(
                sortField: .createdAt,
                sortDirection: .ascending,
                limit: 100
            )
            let queryConstructionDuration = queryConstructionStart.duration(to: .now)

            let searchStart = ContinuousClock.now
            let searchResult = try repository.query(searchQuery)
            let searchDuration = searchStart.duration(to: .now)

            let filterStart = ContinuousClock.now
            let filtered = try repository.query(filterQuery)
            let filterDuration = filterStart.duration(to: .now)

            let sortStart = ContinuousClock.now
            let sorted = try repository.query(sortQuery)
            let sortDuration = sortStart.duration(to: .now)

            XCTAssertFalse(searchResult.isEmpty)
            XCTAssertLessThanOrEqual(filtered.count, 100)
            XCTAssertEqual(sorted.count, min(size, 100))
            print(
                """
                QUERY_BASELINE_\(size)=insert:\(insertionDuration.secondsValue),\
                tag_write:\(associationDuration.secondsValue),\
                query_build:\(queryConstructionDuration.secondsValue),\
                search:\(searchDuration.secondsValue),\
                filter:\(filterDuration.secondsValue),\
                sort:\(sortDuration.secondsValue)
                """
            )
            XCTContext.runActivity(named: "Baseline \(size) fictional books") { activity in
                let attachment = XCTAttachment(
                    string: """
                    count=\(size)
                    insert=\(insertionDuration)
                    query_construction=\(queryConstructionDuration)
                    tag_associations=\(size / 10)
                    tag_association_write=\(associationDuration)
                    search=\(searchDuration)
                    multi_filter=\(filterDuration)
                    sort=\(sortDuration)
                    """
                )
                attachment.lifetime = .keepAlways
                activity.add(attachment)
            }
        }
    }

    private func deterministicID(_ index: Int) -> UUID {
        let suffix = String(format: "%012d", index)
        return UUID(uuidString: "00000000-0000-0000-0000-\(suffix)")!
    }
}
