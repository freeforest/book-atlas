import XCTest

final class BookAtlasTechnicalSpikesUITests: XCTestCase {
    func testLaunchShowsFictionalDataAndFileAccessEntryPoint() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["雾港档案"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["choose-file"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["appkit-status"].waitForExistence(timeout: 3))
    }
}
