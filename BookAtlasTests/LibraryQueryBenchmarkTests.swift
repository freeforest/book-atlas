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
                    let book = try repository.create(
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
                    if index.isMultiple(of: 10) {
                        try repository.attach(tagID: tag.id, toBookID: book.id)
                    }
                }
            }
            let insertionDuration = insertionStart.duration(to: .now)

            let searchStart = ContinuousClock.now
            let searchResult = try repository.query(
                LibraryQuery(searchText: "Volume 00042", limit: 100)
            )
            let searchDuration = searchStart.duration(to: .now)

            let filterStart = ContinuousClock.now
            let filtered = try repository.query(
                LibraryQuery(
                    readingStatuses: [.reading],
                    tagIDs: [tag.id],
                    sortField: .priority,
                    sortDirection: .descending,
                    limit: 100
                )
            )
            let filterDuration = filterStart.duration(to: .now)

            XCTAssertFalse(searchResult.isEmpty)
            XCTAssertLessThanOrEqual(filtered.count, 100)
            XCTContext.runActivity(named: "Baseline \(size) fictional books") { activity in
                let attachment = XCTAttachment(
                    string: """
                    count=\(size)
                    insert=\(insertionDuration)
                    search=\(searchDuration)
                    combined_filter_sort=\(filterDuration)
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
