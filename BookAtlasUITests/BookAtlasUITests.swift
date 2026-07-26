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
        let app = launchInMemoryApp()

        XCTAssertTrue(element("app-sidebar", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("library-empty-state", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(app.menuBars.menuBarItems["导航"].exists)

        for (identifier, title) in pages {
            let navigationItem = element("navigation-\(identifier)", in: app)
            XCTAssertTrue(navigationItem.waitForExistence(timeout: 3))
            navigationItem.click()
            if identifier == "library" {
                XCTAssertTrue(element("library-empty-state", in: app).waitForExistence(timeout: 3))
            } else {
                XCTAssertTrue(
                    element("page-title-\(identifier)", in: app)
                        .waitForExistence(timeout: 3),
                    "Expected \(title) page after selecting \(identifier)"
                )
            }
        }
    }

    @MainActor
    func testEmptyLibraryAndCommandNShowValidationWithoutWritingARecord() {
        let app = launchInMemoryApp()

        XCTAssertTrue(element("library-empty-state", in: app).waitForExistence(timeout: 3))
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))

        app.typeKey("s", modifierFlags: .command)
        XCTAssertTrue(element("editor-validation-error", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("library-empty-state", in: app).exists)
    }

    @MainActor
    func testCreateEditCancelAndSaveWithKeyboardCommands() {
        let app = launchInMemoryApp()
        createFictionalBook(in: app)
        XCTAssertTrue(element("book-detail-view", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("book-detail-title", in: app).exists)

        element("edit-book-button", in: app).click()
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))
        replaceText(in: element("editor-title", in: app), with: "A202")

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("editor-continue-editing", in: app).waitForExistence(timeout: 3))
        element("editor-continue-editing", in: app).click()
        XCTAssertTrue(element("editor-title", in: app).exists)

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("editor-discard-changes", in: app).waitForExistence(timeout: 3))
        element("editor-discard-changes", in: app).click()
        XCTAssertTrue(element("book-detail-view", in: app).waitForExistence(timeout: 3))

        element("edit-book-button", in: app).click()
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))
        XCTAssertEqual(element("editor-title", in: app).value as? String, "A101")
        replaceText(in: element("editor-title", in: app), with: "A202")
        app.typeKey("s", modifierFlags: .command)
        XCTAssertTrue(element("book-detail-title", in: app).waitForExistence(timeout: 3))

        element("edit-book-button", in: app).click()
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))
        XCTAssertEqual(element("editor-title", in: app).value as? String, "A202")
    }

    @MainActor
    func testDeleteRequiresConfirmationAndCanBeCancelledOrConfirmed() {
        let app = launchInMemoryApp()
        createFictionalBook(in: app)

        element("delete-book-button", in: app).click()
        XCTAssertTrue(element("cancel-delete-book", in: app).waitForExistence(timeout: 3))
        element("cancel-delete-book", in: app).click()
        XCTAssertTrue(element("book-detail-view", in: app).waitForExistence(timeout: 3))

        element("delete-book-button", in: app).click()
        XCTAssertTrue(element("confirm-delete-book", in: app).waitForExistence(timeout: 3))
        element("confirm-delete-book", in: app).click()
        XCTAssertTrue(element("library-empty-state", in: app).waitForExistence(timeout: 3))
    }

    @MainActor
    func testBookListSupportsKeyboardSelection() {
        let app = launchInMemoryApp()
        createFictionalBook(in: app, title: "A101", author: "L101")
        createFictionalBook(in: app, title: "B202", author: "B202")

        element("library-book-list", in: app).click()
        app.typeKey(.upArrow, modifierFlags: [])

        element("edit-book-button", in: app).click()
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))
        XCTAssertEqual(element("editor-title", in: app).value as? String, "A101")
    }

    @MainActor
    func testDatabaseUnavailableUsesGenericErrorState() {
        let app = XCUIApplication()
        app.launchArguments = ["-BookAtlasForceUnavailableStore"]
        app.launch()

        XCTAssertTrue(element("library-load-error", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["无法打开本地书库"].exists)
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func launchInMemoryApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-BookAtlasUseInMemoryStore"]
        app.launch()
        return app
    }

    @MainActor
    private func createFictionalBook(
        in app: XCUIApplication,
        title: String = "A101",
        author: String = "L101"
    ) {
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))
        replaceText(in: element("editor-title", in: app), with: title)
        replaceText(in: element("editor-author", in: app), with: author)
        app.typeKey("s", modifierFlags: .command)
        XCTAssertTrue(element("book-detail-view", in: app).waitForExistence(timeout: 3))
    }

    @MainActor
    private func replaceText(in element: XCUIElement, with value: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        element.click()
        element.typeKey("a", modifierFlags: .command)
        element.typeText(value)
    }
}
