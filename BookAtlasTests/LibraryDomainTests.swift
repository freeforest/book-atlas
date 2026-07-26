import XCTest
@testable import BookAtlas

final class LibraryDomainTests: XCTestCase {
    func testReadingStatusHasSevenExplicitValues() {
        XCTAssertEqual(ReadingStatus.allCases.count, 7)
        XCTAssertEqual(ReadingStatus.read.rawValue, "read")
    }

    func testBookTrimsRequiredFieldsAndPreservesPartialPublicationDate() throws {
        let publicationDate = try PublicationDate(year: 2024, month: 2)
        let book = try Book(
            draft: BookDraft(title: "  《雾港档案》  ", author: "  林雾  ", publicationDate: publicationDate),
            createdAt: FictionalLibraryFixtures.timestamp
        )

        XCTAssertEqual(book.title, "《雾港档案》")
        XCTAssertEqual(book.author, "林雾")
        XCTAssertEqual(book.publicationDate?.storageValue, "2024-02")
    }

    func testBookRejectsBlankTitleAndAuthor() {
        XCTAssertThrowsError(try Book(draft: BookDraft(title: "  ", author: "林雾"))) { error in
            XCTAssertEqual(error as? DomainValidationError, .blankTitle)
        }
        XCTAssertThrowsError(try Book(draft: BookDraft(title: "《雾港档案》", author: "\n"))) { error in
            XCTAssertEqual(error as? DomainValidationError, .blankAuthor)
        }
    }

    func testPriorityBoundariesAndPublicationDateValidation() throws {
        XCTAssertEqual(BookPriority(rawValue: 1)?.rawValue, 1)
        XCTAssertEqual(BookPriority(rawValue: 5)?.rawValue, 5)
        XCTAssertNil(BookPriority(rawValue: 0))
        XCTAssertNil(BookPriority(rawValue: 6))
        XCTAssertThrowsError(try PublicationDate(year: 2024, month: 2, day: 30))
        XCTAssertEqual(try PublicationDate(storageValue: "1999").storageValue, "1999")
    }

    func testManualRelationRejectsTheSameBookAtBothEnds() {
        let bookID = UUID()
        XCTAssertThrowsError(
            try ManualBookRelation(sourceBookID: bookID, targetBookID: bookID, kind: .related)
        ) { error in
            XCTAssertEqual(error as? DomainValidationError, .selfRelation)
        }
    }
}
