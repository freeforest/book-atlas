@testable import BookAtlasTechnicalSpikes
import XCTest

final class BookAtlasTechnicalSpikesTests: XCTestCase {
    func testFictionalFixtureIsStable() {
        XCTAssertEqual(FictionalBook.all.count, 3)
        XCTAssertEqual(FictionalBook.all.first?.title, "雾港档案")
    }
}

