import XCTest
@testable import BookAtlas

final class BookEditorDraftTests: XCTestCase {
    func testDefaultDraftRequiresOnlyTitleAndAuthorAndUsesWishToRead() throws {
        let draft = try BookEditorDraft(title: "  《雾港档案》 ", author: " 林雾 ").makeBookDraft()

        XCTAssertEqual(draft.title, "《雾港档案》")
        XCTAssertEqual(draft.author, "林雾")
        XCTAssertEqual(draft.readingStatus, .wishToRead)
        XCTAssertNil(draft.isbn)
    }

    func testBlankRequiredFieldsProduceSpecificValidationErrors() {
        XCTAssertThrowsError(try BookEditorDraft(title: " \n", author: "林雾").makeBookDraft()) { error in
            XCTAssertEqual(error as? BookEditorValidationError, .titleRequired)
        }
        XCTAssertThrowsError(try BookEditorDraft(title: "《雾港档案》", author: "  ").makeBookDraft()) { error in
            XCTAssertEqual(error as? BookEditorValidationError, .authorRequired)
        }
    }

    func testISBNIsNormalizedBeforePersistence() throws {
        let draft = try BookEditorDraft(
            title: "《机器与花园》",
            author: "周栩",
            isbn: " 978 - 0  - 1234 5678 - X "
        ).makeBookDraft()

        XCTAssertEqual(draft.isbn, "978012345678X")
    }

    func testPublicationDateAndPriorityValidation() {
        XCTAssertThrowsError(
            try BookEditorDraft(title: "《星图索引》", author: "沈遥", publicationDateText: "2024-02-30").makeBookDraft()
        ) { error in
            XCTAssertEqual(error as? BookEditorValidationError, .invalidPublicationDate)
        }
        XCTAssertThrowsError(
            try BookEditorDraft(title: "《静默算法》", author: "顾弦", priorityValue: 6).makeBookDraft()
        ) { error in
            XCTAssertEqual(error as? BookEditorValidationError, .invalidPriority)
        }
    }

    func testEditorDraftKeepsExistingBookValuesUntilExplicitSave() throws {
        let book = try Book(draft: FictionalLibraryFixtures.draft(), createdAt: FictionalLibraryFixtures.timestamp)
        let editor = BookEditorDraft(book: book)

        XCTAssertEqual(editor.title, book.title)
        XCTAssertEqual(editor.isbn, book.isbn)
        XCTAssertEqual(editor.priorityValue, book.priority?.rawValue)
    }
}
