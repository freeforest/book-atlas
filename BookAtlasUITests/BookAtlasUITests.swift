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
        let app = launchInMemoryApp(seedFictionalBooks: true)
        XCTAssertTrue(element("library-book-list", in: app).waitForExistence(timeout: 3))
        let retainedBookRow = element(
            "library-book-00000000-0000-0000-0000-000000000101",
            in: app
        )
        let deletedBookRow = element(
            "library-book-00000000-0000-0000-0000-000000000202",
            in: app
        )
        XCTAssertTrue(retainedBookRow.waitForExistence(timeout: 3))
        XCTAssertTrue(deletedBookRow.waitForExistence(timeout: 3))

        element("delete-book-button", in: app).click()
        XCTAssertTrue(element("cancel-delete-book", in: app).waitForExistence(timeout: 3))
        element("cancel-delete-book", in: app).click()
        XCTAssertTrue(element("book-detail-view", in: app).waitForExistence(timeout: 3))

        element("delete-book-button", in: app).click()
        XCTAssertTrue(element("confirm-delete-book", in: app).waitForExistence(timeout: 3))
        element("confirm-delete-book", in: app).click()
        XCTAssertTrue(deletedBookRow.waitForNonExistence(timeout: 3))
        XCTAssertTrue(retainedBookRow.waitForExistence(timeout: 3))
    }

    @MainActor
    func testBookListSupportsKeyboardSelection() {
        let app = launchInMemoryApp(seedFictionalBooks: true)
        XCTAssertTrue(element("library-book-list", in: app).waitForExistence(timeout: 3))

        element("library-book-list", in: app).click()
        app.typeKey(.upArrow, modifierFlags: [])

        element("edit-book-button", in: app).click()
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))
        XCTAssertEqual(element("editor-title", in: app).value as? String, "A101")
    }

    @MainActor
    func testSearchCombinesWithStatusFilterAndCanBeCleared() {
        let app = launchInMemoryApp(seedFictionalBooks: true)
        XCTAssertTrue(element("library-book-list", in: app).waitForExistence(timeout: 3))

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        replaceText(in: searchField, with: "A101")
        XCTAssertTrue(app.staticTexts["A101"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["B202"].exists)

        element("library-filter-menu", in: app).click()
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(element("active-filter-summary", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["A101"].exists)

        replaceText(in: searchField, with: "不存在的虚构书")
        XCTAssertTrue(element("library-no-results", in: app).waitForExistence(timeout: 3))
        element("clear-filters-button", in: app).click()
        XCTAssertTrue(element("library-book-list", in: app).waitForExistence(timeout: 3))

        element("library-sort-menu", in: app).click()
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(element("library-book-list", in: app).exists)
    }

    @MainActor
    func testCreateCollectionAndSourceWithKeyboardNavigation() {
        let app = launchInMemoryApp()
        XCTAssertTrue(element("library-empty-state", in: app).waitForExistence(timeout: 3))

        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(element("page-title-collections", in: app).waitForExistence(timeout: 3))
        element("add-collection-button", in: app).click()
        replaceText(in: element("collection-name-field", in: app), with: "North Shelf")
        replaceText(in: element("collection-details-field", in: app), with: "Fictional collection")
        app.typeKey(.tab, modifierFlags: [])
        element("collection-save-button", in: app).click()
        XCTAssertTrue(app.staticTexts["North Shelf"].waitForExistence(timeout: 3))

        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(element("library-empty-state", in: app).waitForExistence(timeout: 3))
        element("catalog-management-button", in: app).click()
        XCTAssertTrue(element("page-title-tags", in: app).waitForExistence(timeout: 3))

        let sourceTab = element("catalog-management-tab-sources", in: app)
        if sourceTab.waitForExistence(timeout: 1) {
            sourceTab.click()
        } else {
            let labeledSourceTab = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", "来源"))
                .firstMatch
            XCTAssertTrue(labeledSourceTab.waitForExistence(timeout: 3))
            labeledSourceTab.click()
        }
        XCTAssertTrue(element("page-title-sources", in: app).waitForExistence(timeout: 3))
        element("add-source-button", in: app).click()
        replaceText(in: element("source-name-field", in: app), with: "Paper Signal")
        replaceText(in: element("source-details-field", in: app), with: "Fictional source")
        app.typeKey(.tab, modifierFlags: [])
        element("source-save-button", in: app).click()
        XCTAssertTrue(app.staticTexts["Paper Signal"].waitForExistence(timeout: 3))

        element("close-catalog-management", in: app).click()
        XCTAssertTrue(element("library-empty-state", in: app).waitForExistence(timeout: 3))
    }

    @MainActor
    func testTagCreateRenameAndConfirmedMergeResult() {
        let app = launchInMemoryApp()
        XCTAssertTrue(element("library-empty-state", in: app).waitForExistence(timeout: 3))

        app.typeKey("3", modifierFlags: .command)
        XCTAssertTrue(element("page-title-tags", in: app).waitForExistence(timeout: 3))
        createTag(named: "Harbor Draft", in: app)

        let draftRow = catalogRow(named: "Harbor Draft", in: app)
        XCTAssertTrue(draftRow.waitForExistence(timeout: 3))
        draftRow.click()
        element("rename-tag-button", in: app).click()
        replaceText(in: element("tag-name-field", in: app), with: "Harbor Revised")
        app.typeKey(.tab, modifierFlags: [])
        element("tag-save-button", in: app).click()
        XCTAssertTrue(catalogRow(named: "Harbor Revised", in: app).waitForExistence(timeout: 3))

        createTag(named: "Coastal Target", in: app)
        catalogRow(named: "Harbor Revised", in: app).click()
        element("merge-tag-button", in: app).click()
        XCTAssertTrue(element("tag-merge-sheet", in: app).waitForExistence(timeout: 3))

        element("merge-tag-target-picker", in: app).click()
        let targetMenuItem = app.menuItems["Coastal Target"]
        if targetMenuItem.waitForExistence(timeout: 1) {
            targetMenuItem.click()
        } else {
            app.typeKey(.downArrow, modifierFlags: [])
            app.typeKey(.return, modifierFlags: [])
        }
        let mergeButton = element("confirm-merge-tag", in: app)
        XCTAssertTrue(waitForEnabled(mergeButton))
        mergeButton.click()
        XCTAssertTrue(element("perform-merge-tag", in: app).waitForExistence(timeout: 3))
        element("perform-merge-tag", in: app).click()

        XCTAssertTrue(catalogRow(named: "Harbor Revised", in: app).waitForNonExistence(timeout: 3))
        XCTAssertTrue(catalogRow(named: "Coastal Target", in: app).waitForExistence(timeout: 3))
    }

    @MainActor
    func testDuplicateSaveReviewSupportsFieldChoiceAndConfirmedMerge() {
        let app = launchInMemoryApp(seedFictionalBooks: true)
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))
        replaceText(in: element("editor-title", in: app), with: "A101 Incoming")
        replaceText(in: element("editor-author", in: app), with: "Harbor Author")
        replaceText(in: element("editor-isbn", in: app), with: "978-0-00000-000-2")

        app.typeKey("s", modifierFlags: .command)
        XCTAssertTrue(element("duplicate-review-sheet", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("duplicate-uncertainty", in: app).exists)
        app.typeKey(.return, modifierFlags: [])
        let titleChoice = element("merge-choice-title", in: app)
        XCTAssertTrue(titleChoice.waitForExistence(timeout: 3))
        titleChoice.click()
        let sourceTitle = app.menuItems["来源记录：A101 Incoming"]
        if sourceTitle.waitForExistence(timeout: 1) {
            sourceTitle.click()
        } else {
            app.typeKey(.downArrow, modifierFlags: [])
            app.typeKey(.return, modifierFlags: [])
        }
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["确认合并这两条书籍记录？"].waitForExistence(timeout: 3))
        let confirmMerge = element("confirm-book-merge", in: app)
        XCTAssertTrue(confirmMerge.waitForExistence(timeout: 3))
        confirmMerge.click()

        XCTAssertTrue(element("book-editor-sheet", in: app).waitForNonExistence(timeout: 3))
        XCTAssertTrue(
            element("library-book-00000000-0000-0000-0000-000000000101", in: app)
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            element("library-book-00000000-0000-0000-0000-000000000202", in: app)
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["A101 Incoming"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testManualDuplicateReviewShowsEmptyStateAndSupportsEscape() {
        let app = launchInMemoryApp(seedFictionalBooks: true)
        XCTAssertTrue(element("library-book-list", in: app).waitForExistence(timeout: 3))

        element("review-duplicates-button", in: app).click()
        XCTAssertTrue(element("duplicate-review-sheet", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["没有重复候选"].waitForExistence(timeout: 3))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("duplicate-review-sheet", in: app).waitForNonExistence(timeout: 3))
        XCTAssertTrue(element("library-book-list", in: app).exists)
    }

    @MainActor
    func testViewingExistingDuplicateReturnsToUnchangedDraft() {
        let app = launchInMemoryApp(seedFictionalBooks: true)
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))
        replaceText(in: element("editor-title", in: app), with: "A101 Recoverable Draft")
        replaceText(in: element("editor-author", in: app), with: "Harbor Author")
        replaceText(in: element("editor-isbn", in: app), with: "978-0-00000-000-2")

        app.typeKey("s", modifierFlags: .command)
        XCTAssertTrue(element("duplicate-review-sheet", in: app).waitForExistence(timeout: 3))
        app.typeKey("o", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["查看已有记录"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["A101"].exists)

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("duplicate-review-sheet", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(
            element("duplicate-existing-back", in: app).waitForNonExistence(timeout: 3)
        )
        app.typeKey(.escape, modifierFlags: [])

        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))
        XCTAssertEqual(
            element("editor-title", in: app).value as? String,
            "A101 Recoverable Draft"
        )
        XCTAssertEqual(element("editor-author", in: app).value as? String, "Harbor Author")
    }

    @MainActor
    func testMergePreviewExposesConcreteAssociationsToAccessibility() {
        let app = launchInMemoryApp(seedMergePreviewAssociations: true)
        let sourceRow = element(
            "library-book-00000000-0000-0000-0000-000000000402",
            in: app
        )
        XCTAssertTrue(sourceRow.waitForExistence(timeout: 3))
        sourceRow.click()
        element("review-duplicates-button", in: app).click()
        XCTAssertTrue(element("duplicate-review-sheet", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("duplicate-uncertainty", in: app).waitForExistence(timeout: 3))
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["合并预览"].waitForExistence(timeout: 3))

        let targetTag = element(
            "merge-tag-detail-00000000-0000-0000-0000-000000000411",
            in: app
        )
        let sourceTag = element(
            "merge-tag-detail-00000000-0000-0000-0000-000000000412",
            in: app
        )
        XCTAssertTrue(targetTag.waitForExistence(timeout: 3))
        XCTAssertTrue(sourceTag.waitForExistence(timeout: 3))
        let targetTagText = accessibilityText(of: targetTag)
        let sourceTagText = accessibilityText(of: sourceTag)
        XCTAssertTrue(targetTagText.contains("保留标签"), targetTagText)
        XCTAssertTrue(targetTagText.contains("保留"), targetTagText)
        XCTAssertTrue(sourceTagText.contains("新增标签"), sourceTagText)
        XCTAssertTrue(sourceTagText.contains("新增"), sourceTagText)

        app.scrollViews.firstMatch.swipeUp()
        let collection = element(
            "merge-collection-detail-00000000-0000-0000-0000-000000000421",
            in: app
        )
        let source = element(
            "merge-source-detail-00000000-0000-0000-0000-000000000431",
            in: app
        )
        let targetLink = element(
            "merge-link-detail-00000000-0000-0000-0000-000000000441",
            in: app
        )
        let sourceLink = element(
            "merge-link-detail-00000000-0000-0000-0000-000000000442",
            in: app
        )
        let relation = element(
            "merge-relation-detail-00000000-0000-0000-0000-000000000451",
            in: app
        )
        for association in [collection, source, targetLink, sourceLink, relation] {
            XCTAssertTrue(association.waitForExistence(timeout: 3))
        }
        XCTAssertTrue(accessibilityText(of: collection).contains("虚构港湾书单"))
        XCTAssertTrue(accessibilityText(of: source).contains("虚构纸页来源"))
        XCTAssertTrue(accessibilityText(of: targetLink).contains("https://example.invalid/retained"))
        XCTAssertTrue(accessibilityText(of: sourceLink).contains("https://example.invalid/incoming"))
        let relationText = accessibilityText(of: relation)
        XCTAssertTrue(relationText.contains("本书指向"), relationText)
        XCTAssertTrue(relationText.contains("回应"), relationText)
        XCTAssertTrue(relationText.contains("《虚构灯塔》"), relationText)
        XCTAssertTrue(relationText.contains("有备注"), relationText)
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
    private func launchInMemoryApp(
        seedFictionalBooks: Bool = false,
        seedMergePreviewAssociations: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-BookAtlasUseInMemoryStore"]
        if seedFictionalBooks {
            app.launchArguments.append("-BookAtlasSeedFictionalUITestBooks")
        }
        if seedMergePreviewAssociations {
            app.launchArguments.append("-BookAtlasSeedMergePreviewAssociations")
        }
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

    @MainActor
    private func createTag(named name: String, in app: XCUIApplication) {
        element("add-tag-button", in: app).click()
        replaceText(in: element("tag-name-field", in: app), with: name)
        app.typeKey(.tab, modifierFlags: [])
        element("tag-save-button", in: app).click()
        XCTAssertTrue(catalogRow(named: name, in: app).waitForExistence(timeout: 3))
    }

    @MainActor
    private func catalogRow(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts
            .matching(NSPredicate(format: "value BEGINSWITH %@", name))
            .firstMatch
    }

    @MainActor
    private func waitForEnabled(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND enabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func accessibilityText(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
