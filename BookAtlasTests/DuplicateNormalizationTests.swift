import XCTest
@testable import BookAtlas

final class DuplicateNormalizationTests: XCTestCase {
    func testISBNValidationAcceptsValidTenAndThirteenDigitForms() {
        XCTAssertEqual(
            DuplicateISBNNormalizer.validate("0-000-00000-0"),
            .valid("0000000000")
        )
        XCTAssertEqual(
            DuplicateISBNNormalizer.validate("0 000 00006 x"),
            .valid("000000006X")
        )
        XCTAssertEqual(
            DuplicateISBNNormalizer.validate("978-0-00000-000-2"),
            .valid("9780000000002")
        )
    }

    func testISBNValidationRejectsWrongChecksumsIllegalCharactersAndEmptyValues() {
        XCTAssertEqual(DuplicateISBNNormalizer.validate("9780000000003"), .invalid)
        XCTAssertEqual(DuplicateISBNNormalizer.validate("97800000A0002"), .invalid)
        XCTAssertEqual(DuplicateISBNNormalizer.validate("000000006Y"), .invalid)
        XCTAssertEqual(DuplicateISBNNormalizer.validate(" \n "), .empty)
        XCTAssertEqual(DuplicateISBNNormalizer.validate(nil), .empty)
    }

    func testTitleNormalizationHandlesUnicodeWidthCasePunctuationAndSubtitleSeparators() {
        XCTAssertEqual(
            DuplicateTextNormalizer.titleKey("  《Ｃａｆé　Atlas： North—Shore》 "),
            DuplicateTextNormalizer.titleKey("cafe\u{301} atlas: north:shore")
        )
        XCTAssertEqual(
            DuplicateTextNormalizer.titleKey("《雾港档案：潮汐》"),
            DuplicateTextNormalizer.titleKey("雾港档案: 潮汐")
        )
        XCTAssertNotEqual(
            DuplicateTextNormalizer.titleKey("《雾港档案：潮汐》"),
            DuplicateTextNormalizer.titleKey("《雾港档案：灯塔》")
        )
    }

    func testAuthorNormalizationHandlesCommonSeparatorsButPreservesOrder() {
        XCTAssertEqual(
            DuplicateTextNormalizer.authorKey(" Mira Vale，Noa Reed "),
            DuplicateTextNormalizer.authorKey("mira vale / noa reed")
        )
        XCTAssertNotEqual(
            DuplicateTextNormalizer.authorKey("Mira Vale, Noa Reed"),
            DuplicateTextNormalizer.authorKey("Noa Reed, Mira Vale")
        )
    }
}
