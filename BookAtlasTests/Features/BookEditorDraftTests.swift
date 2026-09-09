import XCTest
@testable import BookAtlas

final class BookEditorDraftTests: XCTestCase {
    func testBookKindsRoundTripThroughCatalogWithoutLosingFieldsOrRelations() async throws {
        let timestamp = FictionalLibraryFixtures.timestamp
        let saveTime = timestamp.addingTimeInterval(120)
        XCTAssertEqual(BookEditorDraft().kind, .book)
        XCTAssertEqual(BookKind.allCases.map(\.displayTitle), ["图书", "文集", "工具书", "其他"])
        let repository = try BookRepository.inMemory()
        let original = try repository.create(BookDraft(
            title: "Fictional Kind Atlas", originalTitle: "Fictional Original",
            author: "Mira Vale", isbn: "9781402894626", publisher: "Fictional Press",
            publicationDate: PublicationDate(year: 2024, month: 2),
            readingStatus: .read, priority: BookPriority(rawValue: 3), note: "Fictional note",
            startedAt: FictionalLibraryFixtures.timestamp,
            finishedAt: FictionalLibraryFixtures.timestamp.addingTimeInterval(60)
        ), at: FictionalLibraryFixtures.timestamp)
        let target = try repository.create(BookDraft(title: "Fictional Counterpart", author: "Noa Reed"), at: timestamp)
        let relation = try repository.addManualRelation(ManualBookRelation(
            sourceBookID: original.id, targetBookID: target.id, kind: .related, createdAt: timestamp
        ))
        let catalog = LibraryCatalogService(repository: repository, now: { saveTime })
        for kind in BookKind.allCases {
            var editor = BookEditorDraft(book: original)
            editor.kind = kind
            XCTAssertEqual(try editor.makeBookDraft().kind, kind)
            let saved = try await catalog.updateBook(original, from: editor)
            let rows = try await catalog.queryBooks(LibraryQuery())
            let loaded = try XCTUnwrap(rows.first { $0.id == original.id })
            XCTAssertEqual(loaded, saved)
            XCTAssertEqual(loaded.kind, kind)
            XCTAssertEqual(loaded.createdAt, original.createdAt)
            XCTAssertEqual(loaded.updatedAt, saveTime)
            var restored = BookEditorDraft(book: loaded)
            restored.kind = original.kind
            XCTAssertEqual(restored, BookEditorDraft(book: original))
            let relations = try await catalog.manualRelationSummaries(for: original.id)
            XCTAssertEqual(relations.map(\.relation), [relation])
            let created = try await catalog.createBook(from: editor)
            let createdRows = try await catalog.queryBooks(LibraryQuery())
            XCTAssertEqual(createdRows.first { $0.id == created.id }?.kind, kind)
        }
    }

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

    func testValidationErrorsKnowWhenTheirFieldHasBeenCorrected() {
        XCTAssertFalse(
            BookEditorValidationError.titleRequired.isResolved(
                by: BookEditorDraft(title: " ", author: "固定作者")
            )
        )
        XCTAssertTrue(
            BookEditorValidationError.titleRequired.isResolved(
                by: BookEditorDraft(title: "《固定书名》", author: "固定作者")
            )
        )
        XCTAssertFalse(
            BookEditorValidationError.authorRequired.isResolved(
                by: BookEditorDraft(title: "《固定书名》", author: " ")
            )
        )
        XCTAssertTrue(
            BookEditorValidationError.authorRequired.isResolved(
                by: BookEditorDraft(title: "《固定书名》", author: "固定作者")
            )
        )
        XCTAssertFalse(
            BookEditorValidationError.invalidPublicationDate.isResolved(
                by: BookEditorDraft(publicationDateText: "2024-02-30")
            )
        )
        XCTAssertTrue(
            BookEditorValidationError.invalidPublicationDate.isResolved(
                by: BookEditorDraft(publicationDateText: "2024-02")
            )
        )
        XCTAssertFalse(
            BookEditorValidationError.invalidPriority.isResolved(
                by: BookEditorDraft(priorityValue: 6)
            )
        )
        XCTAssertTrue(
            BookEditorValidationError.invalidPriority.isResolved(
                by: BookEditorDraft(priorityValue: 5)
            )
        )
    }

    @MainActor
    func testValidationFeedbackAnnouncesEverySubmissionWithoutPrivateDraftData() {
        let poster = AccessibilityAnnouncementPosterSpy()
        let feedback = BookEditorValidationFeedback(announcementPoster: poster)
        let privateDraftText = "不应进入公告的私人草稿"

        feedback.present(.validation(.titleRequired))
        feedback.present(.validation(.titleRequired))

        XCTAssertEqual(
            poster.messages,
            [
                "保存没有成功。请检查填写内容。请填写书名。",
                "保存没有成功。请检查填写内容。请填写书名。"
            ]
        )
        XCTAssertFalse(poster.messages.joined().contains(privateDraftText))
        XCTAssertEqual(feedback.validationError, .titleRequired)
    }

    @MainActor
    func testValidationFeedbackClearsOnlyAfterCurrentErrorIsResolved() {
        let poster = AccessibilityAnnouncementPosterSpy()
        let feedback = BookEditorValidationFeedback(announcementPoster: poster)

        feedback.present(.validation(.authorRequired))
        feedback.clearIfResolved(
            by: BookEditorDraft(title: "《固定书名》", author: " ")
        )
        XCTAssertEqual(feedback.validationError, .authorRequired)

        feedback.clearIfResolved(
            by: BookEditorDraft(title: "《固定书名》", author: "固定作者")
        )
        XCTAssertNil(feedback.error)

        feedback.present(.validation(.invalidPublicationDate))
        feedback.clearIfResolved(
            by: BookEditorDraft(publicationDateText: "2024-02-30")
        )
        XCTAssertEqual(feedback.validationError, .invalidPublicationDate)
        feedback.clearIfResolved(
            by: BookEditorDraft(publicationDateText: "2024-02")
        )
        XCTAssertNil(feedback.error)

        feedback.present(.validation(.invalidPriority))
        feedback.clearIfResolved(by: BookEditorDraft(priorityValue: 6))
        XCTAssertEqual(feedback.validationError, .invalidPriority)
        feedback.clearIfResolved(by: BookEditorDraft(priorityValue: 0))
        XCTAssertNil(feedback.error)
    }

    func testEditorDraftKeepsExistingBookValuesUntilExplicitSave() throws {
        let book = try Book(draft: FictionalLibraryFixtures.draft(), createdAt: FictionalLibraryFixtures.timestamp)
        let editor = BookEditorDraft(book: book)

        XCTAssertEqual(editor.title, book.title)
        XCTAssertEqual(editor.isbn, book.isbn)
        XCTAssertEqual(editor.priorityValue, book.priority?.rawValue)
    }
}

@MainActor
private final class AccessibilityAnnouncementPosterSpy:
    AccessibilityAnnouncementPosting
{
    private(set) var messages: [String] = []

    func postAnnouncement(_ message: String) {
        messages.append(message)
    }
}
