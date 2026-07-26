import XCTest

final class BookAtlasUITests: XCTestCase {
    private let pages = [
        ("library", "书库"),
        ("collections", "书单"),
        ("tags", "标签"),
        ("graph", "书图"),
        ("settings", "设置")
    ]

    @MainActor
    func testLaunchShowsSidebarPagesAndNavigationMenu() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(element("app-sidebar", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("page-title-library", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(app.menuBars.menuBarItems["导航"].exists)

        for (identifier, title) in pages {
            let navigationItem = element("navigation-\(identifier)", in: app)
            XCTAssertTrue(navigationItem.waitForExistence(timeout: 3))
            navigationItem.click()
            XCTAssertTrue(
                element("page-title-\(identifier)", in: app)
                    .waitForExistence(timeout: 3),
                "Expected \(title) page after selecting \(identifier)"
            )
        }
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
