import XCTest
@testable import BookAtlas

final class DuplicateDetectionTests: XCTestCase {
    func testSameValidISBNIsExactWithReadableEvidence() throws {
        let existing = try fictionalBook(
            title: "《玻璃港》",
            author: "林雾",
            isbn: "9780000000002"
        )
        let incoming = DuplicateProbe(
            id: UUID(),
            draft: BookDraft(
                title: "Glass Harbor",
                author: "Mira Vale",
                isbn: "978-0-00000-000-2"
            )
        )

        let candidate = DuplicateDetectionEngine.evaluate(incoming, against: existing)

        XCTAssertEqual(candidate.confidence, .exact)
        XCTAssertEqual(candidate.evidence.map(\.rule), [.validISBNExact])
        XCTAssertFalse(candidate.uncertainty.isEmpty)
    }

    func testNormalizedTitleAndAuthorAreStrongWithoutConflictEvidence() throws {
        let existing = try fictionalBook(title: "《雾港档案：潮汐》", author: "林雾、许岸")
        let incoming = DuplicateProbe(
            draft: BookDraft(
                title: "雾港档案: 潮汐",
                author: "林雾 / 许岸"
            )
        )

        let candidate = DuplicateDetectionEngine.evaluate(incoming, against: existing)

        XCTAssertEqual(candidate.confidence, .strong)
        XCTAssertEqual(
            Set(candidate.evidence.map(\.rule)),
            [.normalizedTitleExact, .normalizedAuthorExact]
        )
    }

    func testDifferentValidISBNDoesNotBecomeExactOrStrong() throws {
        let existing = try fictionalBook(
            title: "《玻璃港》",
            author: "林雾",
            isbn: "9780000000002"
        )
        let incoming = DuplicateProbe(
            draft: BookDraft(
                title: "玻璃港",
                author: "林雾",
                isbn: "9780000000019"
            )
        )

        let candidate = DuplicateDetectionEngine.evaluate(incoming, against: existing)

        XCTAssertEqual(candidate.confidence, .possible)
        XCTAssertTrue(candidate.evidence.contains { $0.rule == .conflictingValidISBN })
    }

    func testTranslationsAndEditionsArePossibleButSeriesAndSimilarTitlesAreNotDuplicates() throws {
        let translated = try fictionalBook(
            title: "《北岸灯火》",
            originalTitle: "Glass Harbor",
            author: "Mira Vale",
            publisher: "North Press",
            year: 2025
        )
        let translationProbe = DuplicateProbe(
            draft: BookDraft(
                title: "《玻璃港》",
                originalTitle: "Glass Harbor",
                author: "Mira Vale",
                publisher: "South Press",
                publicationDate: try PublicationDate(year: 2024)
            )
        )
        XCTAssertEqual(
            DuplicateDetectionEngine.evaluate(translationProbe, against: translated).confidence,
            .possible
        )

        let edition = try fictionalBook(
            title: "Glass Harbor",
            author: "Mira Vale",
            isbn: "9780000000002",
            publisher: "North Press",
            year: 2024
        )
        let editionProbe = DuplicateProbe(
            draft: BookDraft(
                title: "Glass Harbor: Second Edition",
                author: "Mira Vale",
                isbn: "9780000000019",
                publisher: "North Press",
                publicationDate: try PublicationDate(year: 2025)
            )
        )
        XCTAssertEqual(
            DuplicateDetectionEngine.evaluate(editionProbe, against: edition).confidence,
            .possible
        )

        let seriesBook = try fictionalBook(title: "Harbor Cycle One", author: "Mira Vale")
        let seriesProbe = DuplicateProbe(
            draft: BookDraft(title: "Harbor Cycle Two", author: "Mira Vale")
        )
        XCTAssertEqual(
            DuplicateDetectionEngine.evaluate(seriesProbe, against: seriesBook).confidence,
            .notDuplicate
        )

        let similar = try fictionalBook(title: "The Silent Garden", author: "Noa Reed")
        let similarProbe = DuplicateProbe(
            draft: BookDraft(title: "The Silent Gardener", author: "Ivo Bell")
        )
        XCTAssertEqual(
            DuplicateDetectionEngine.evaluate(similarProbe, against: similar).confidence,
            .notDuplicate
        )
    }

    func testSameTitleDifferentAuthorAndSameAuthorDifferentTitleStayBelowCandidateThreshold() throws {
        let existing = try fictionalBook(title: "《星图索引》", author: "沈遥")
        XCTAssertEqual(
            DuplicateDetectionEngine.evaluate(
                DuplicateProbe(draft: BookDraft(title: "星图索引", author: "顾弦")),
                against: existing
            ).confidence,
            .notDuplicate
        )
        XCTAssertEqual(
            DuplicateDetectionEngine.evaluate(
                DuplicateProbe(draft: BookDraft(title: "《静默算法》", author: "沈遥")),
                against: existing
            ).confidence,
            .notDuplicate
        )
    }

    func testRepositoryPersistsIgnoredPairsAndInvalidatesThemAfterIdentityChange() throws {
        let repository = try BookRepository.inMemory()
        let first = try repository.create(
            BookDraft(title: "《雾港档案》", author: "林雾"),
            at: FictionalLibraryFixtures.timestamp
        )
        let second = try repository.create(
            BookDraft(title: "雾港档案", author: "林雾"),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(1)
        )
        XCTAssertEqual(
            try repository.duplicateCandidates(for: DuplicateProbe(book: second)).map(\.confidence),
            [.strong]
        )

        try repository.ignoreDuplicatePair(
            first.id,
            second.id,
            disposition: .separateEdition,
            at: FictionalLibraryFixtures.timestamp
        )
        XCTAssertTrue(try repository.duplicateCandidates(for: DuplicateProbe(book: second)).isEmpty)
        XCTAssertEqual(
            try repository.ignoredDuplicatePair(between: second.id, and: first.id)?.disposition,
            .separateEdition
        )

        let noteOnlyRevision = try second.applying(
            BookDraft(title: "雾港档案", author: "林雾", note: "虚构备注"),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(1.5)
        )
        try repository.update(noteOnlyRevision)
        XCTAssertNotNil(try repository.ignoredDuplicatePair(between: first.id, and: second.id))

        let revised = try second.applying(
            BookDraft(title: "《雾港档案：修订版》", author: "林雾"),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(2)
        )
        try repository.update(revised)
        XCTAssertNil(try repository.ignoredDuplicatePair(between: first.id, and: second.id))
    }

    func testIgnoredPairRemainsEffectiveAfterReopeningDatabase() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookAtlas-Prompt6-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("fictional.sqlite")
        var firstID: UUID!
        var secondID: UUID!

        do {
            let repository = try BookRepository(databaseURL: databaseURL)
            let first = try repository.create(
                BookDraft(title: "《潮汐图谱》", author: "林雾"),
                at: FictionalLibraryFixtures.timestamp
            )
            let second = try repository.create(
                BookDraft(title: "潮汐图谱", author: "林雾"),
                at: FictionalLibraryFixtures.timestamp
            )
            firstID = first.id
            secondID = second.id
            try repository.ignoreDuplicatePair(
                first.id,
                second.id,
                disposition: .notDuplicate,
                at: FictionalLibraryFixtures.timestamp
            )
        }

        let reopened = try BookRepository(databaseURL: databaseURL)
        let second = try XCTUnwrap(reopened.book(id: secondID))
        XCTAssertEqual(
            try reopened.ignoredDuplicatePair(between: firstID, and: secondID)?.disposition,
            .notDuplicate
        )
        XCTAssertTrue(try reopened.duplicateCandidates(for: DuplicateProbe(book: second)).isEmpty)
    }

    func testIndexedCandidateLookupRemainsBoundedAtTenThousandBooks() throws {
        let repository = try BookRepository.inMemory()
        try repository.transaction {
            for index in 0 ..< 9_999 {
                _ = try repository.create(
                    BookDraft(
                        title: "Fictional Ledger \(index)",
                        author: "Author \(index)"
                    ),
                    at: FictionalLibraryFixtures.timestamp
                )
            }
            _ = try repository.create(
                BookDraft(
                    title: "Indexed Harbor",
                    author: "Mira Vale",
                    isbn: "9780000000002"
                ),
                at: FictionalLibraryFixtures.timestamp
            )
        }

        let started = Date()
        let candidates = try repository.duplicateCandidates(
            for: DuplicateProbe(
                draft: BookDraft(
                    title: "Unrelated Incoming Title",
                    author: "Noa Reed",
                    isbn: "978-0-00000-000-2"
                )
            )
        )
        let elapsed = Date().timeIntervalSince(started)
        print(String(format: "DUPLICATE_CANDIDATE_10000_SECONDS=%.6f", elapsed))

        XCTAssertEqual(candidates.map(\.confidence), [.exact])
        XCTAssertLessThan(elapsed, 1.0, "Indexed candidate lookup should not scan all book pairs")
    }

    func testExactAndStrongCandidateQueriesReturnAllMatchesBeyondTwoHundredFiftyDeterministically() throws {
        let exactRepository = try BookRepository.inMemory()
        let exactIDs = (1 ... 300).reversed().map(deterministicUUID)
        try exactRepository.transaction {
            for (index, id) in exactIDs.enumerated() {
                _ = try exactRepository.create(
                    BookDraft(
                        title: "Exact Fiction \(index)",
                        author: "Author \(index)",
                        isbn: "9780000000002"
                    ),
                    id: id,
                    at: FictionalLibraryFixtures.timestamp
                )
            }
        }
        let exactProbe = DuplicateProbe(
            draft: BookDraft(
                title: "Unrelated Exact Probe",
                author: "Noa Reed",
                isbn: "978-0-00000-000-2"
            )
        )
        let firstExact = try exactRepository.duplicateCandidates(for: exactProbe)
        let secondExact = try exactRepository.duplicateCandidates(for: exactProbe)
        XCTAssertEqual(firstExact.count, 300)
        XCTAssertEqual(firstExact.map(\.confidence), Array(repeating: .exact, count: 300))
        XCTAssertEqual(firstExact.map(\.id), secondExact.map(\.id))
        XCTAssertEqual(firstExact.map(\.id), exactIDs.sorted { $0.uuidString < $1.uuidString })
        let cappedPossibleSearch = try exactRepository.duplicateCandidateSearch(
            for: DuplicateProbe(
                draft: BookDraft(title: "Exact Fiction", author: "Different Author")
            ),
            includingPossible: true
        )
        XCTAssertTrue(cappedPossibleSearch.possibleLookupWasTruncated)

        let strongRepository = try BookRepository.inMemory()
        let strongIDs = (301 ... 600).reversed().map(deterministicUUID)
        try strongRepository.transaction {
            for id in strongIDs {
                _ = try strongRepository.create(
                    BookDraft(title: "《确定性港湾》", author: "林雾"),
                    id: id,
                    at: FictionalLibraryFixtures.timestamp
                )
            }
        }
        let strongProbe = DuplicateProbe(
            draft: BookDraft(title: "确定性港湾", author: "林雾")
        )
        let firstStrong = try strongRepository.duplicateCandidates(for: strongProbe)
        let secondStrong = try strongRepository.duplicateCandidates(for: strongProbe)
        XCTAssertEqual(firstStrong.count, 300)
        XCTAssertEqual(firstStrong.map(\.confidence), Array(repeating: .strong, count: 300))
        XCTAssertEqual(firstStrong.map(\.id), secondStrong.map(\.id))
        XCTAssertEqual(firstStrong.map(\.id), strongIDs.sorted { $0.uuidString < $1.uuidString })
    }

    private func fictionalBook(
        title: String,
        originalTitle: String? = nil,
        author: String,
        isbn: String? = nil,
        publisher: String? = nil,
        year: Int? = nil
    ) throws -> Book {
        try Book(
            draft: BookDraft(
                title: title,
                originalTitle: originalTitle,
                author: author,
                isbn: isbn,
                publisher: publisher,
                publicationDate: try year.map { try PublicationDate(year: $0) }
            ),
            createdAt: FictionalLibraryFixtures.timestamp
        )
    }

    private func deterministicUUID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", value))!
    }
}
