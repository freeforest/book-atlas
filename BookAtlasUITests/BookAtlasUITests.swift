import XCTest

private enum LibraryQueryPageSize {
    static let value = 200
}

private enum PerformanceLibraryMode {
    case prepare
    case useExisting
    case cleanup
}

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
    func testPerformanceColdLaunchWithOneThousandBooks() {
        measureColdLaunch(bookCount: 1_000)
    }

    @MainActor
    func testPerformanceColdLaunchWithFiveThousandBooks() {
        measureColdLaunch(bookCount: 5_000)
    }

    @MainActor
    func testPerformanceColdLaunchWithTenThousandBooks() {
        measureColdLaunch(bookCount: 10_000)
    }

    @MainActor
    func testPerformanceSustainedListScrollingWithOneThousandBooks() {
        measureSustainedListScrolling(bookCount: 1_000)
    }

    @MainActor
    func testPerformanceSustainedListScrollingWithFiveThousandBooks() {
        measureSustainedListScrolling(bookCount: 5_000)
    }

    @MainActor
    func testPerformanceSustainedListScrollingWithTenThousandBooks() {
        measureSustainedListScrolling(bookCount: 10_000)
    }

    @MainActor
    func testEmptyLibraryAndCommandNShowValidationWithoutWritingARecord() {
        let app = launchInMemoryApp()

        XCTAssertTrue(element("library-empty-state", in: app).waitForExistence(timeout: 3))
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))

        app.typeKey("s", modifierFlags: .command)
        assertVisibleEditorValidation(
            "请填写书名。",
            fieldIdentifier: "editor-title",
            fieldErrorIdentifier: "editor-title-error",
            in: app
        )
        XCTAssertTrue(element("book-editor-sheet", in: app).exists)
        XCTAssertTrue(element("library-empty-state", in: app).exists)
        XCTAssertFalse(element("duplicate-review-sheet", in: app).exists)
        XCTAssertFalse(element("editor-discard-changes", in: app).exists)
    }

    @MainActor
    func testAuthorOnlyMouseSaveShowsVisibleTitleErrorAndPreservesDraft() {
        let app = launchInMemoryApp()

        XCTAssertTrue(element("library-empty-state", in: app).waitForExistence(timeout: 3))
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))
        let title = element("editor-title", in: app)
        XCTAssertTrue(waitForKeyboardFocus(title, timeout: 3))
        app.typeKey(.tab, modifierFlags: [])
        let author = element("editor-author", in: app)
        XCTAssertTrue(waitForKeyboardFocus(author, timeout: 3))
        app.typeText("Manual Acceptance Author")

        clickEditorSave(in: app)

        assertVisibleEditorValidation(
            "请填写书名。",
            fieldIdentifier: "editor-title",
            fieldErrorIdentifier: "editor-title-error",
            in: app
        )
        XCTAssertEqual(author.value as? String, "Manual Acceptance Author")
        XCTAssertTrue(element("book-editor-sheet", in: app).exists)
        XCTAssertTrue(element("library-empty-state", in: app).exists)
        XCTAssertFalse(element("duplicate-review-sheet", in: app).exists)
        XCTAssertFalse(element("editor-discard-changes", in: app).exists)

        replaceText(
            in: element("editor-title", in: app),
            with: "Manual Acceptance Book",
            using: app
        )
        XCTAssertTrue(
            element("editor-validation-error", in: app)
                .waitForNonExistence(timeout: 3)
        )
        XCTAssertFalse(element("editor-title-error", in: app).exists)
        XCTAssertEqual(author.value as? String, "Manual Acceptance Author")
    }

    @MainActor
    func testTitleOnlyMouseSaveShowsVisibleAuthorErrorAndPreservesDraft() {
        let app = launchInMemoryApp()

        XCTAssertTrue(element("library-empty-state", in: app).waitForExistence(timeout: 3))
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))
        let title = element("editor-title", in: app)
        replaceText(in: title, with: "Manual Acceptance Book", using: app)

        clickEditorSave(in: app)

        assertVisibleEditorValidation(
            "请填写作者。",
            fieldIdentifier: "editor-author",
            fieldErrorIdentifier: "editor-author-error",
            in: app
        )
        XCTAssertEqual(title.value as? String, "Manual Acceptance Book")
        XCTAssertTrue(element("book-editor-sheet", in: app).exists)
        XCTAssertTrue(element("library-empty-state", in: app).exists)
        XCTAssertFalse(element("duplicate-review-sheet", in: app).exists)
    }

    @MainActor
    func testInvalidPublicationDateShowsVisibleSummaryAndFieldError() {
        let app = launchInMemoryApp()

        XCTAssertTrue(element("library-empty-state", in: app).waitForExistence(timeout: 3))
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))
        replaceText(
            in: element("editor-title", in: app),
            with: "Manual Acceptance Book",
            using: app
        )
        app.typeKey(.tab, modifierFlags: [])
        let author = element("editor-author", in: app)
        XCTAssertTrue(waitForKeyboardFocus(author, timeout: 3))
        app.typeText("Manual Acceptance Author")
        replaceText(
            in: element("editor-publication-date", in: app),
            with: "2024-02-30",
            using: app
        )

        clickEditorSave(in: app)

        assertVisibleEditorValidation(
            "出版日期应为 YYYY、YYYY-MM 或 YYYY-MM-DD。",
            fieldIdentifier: nil,
            fieldErrorIdentifier: "editor-publication-date-error",
            in: app
        )
        XCTAssertEqual(
            element("editor-publication-date", in: app).value as? String,
            "2024-02-30"
        )
        XCTAssertTrue(element("book-editor-sheet", in: app).exists)
        XCTAssertTrue(element("library-empty-state", in: app).exists)
        XCTAssertFalse(element("duplicate-review-sheet", in: app).exists)
    }

    @MainActor
    func testCreateEditCancelAndSaveWithKeyboardCommands() {
        let app = launchInMemoryApp()
        createFictionalBook(in: app)
        XCTAssertTrue(element("book-detail-view", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("book-detail-title", in: app).exists)

        element("edit-book-button", in: app).click()
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))
        replaceText(in: element("editor-title", in: app), with: "A202", using: app)

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
        replaceText(in: element("editor-title", in: app), with: "A202", using: app)
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
    func testLibraryPaginationDisclosesCountAndLoadsEveryPageFromKeyboard() {
        let app = launchInMemoryApp(seedPagination: true)
        let status = element("library-result-count", in: app)
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(
            waitForLibraryCount(
                displayed: 200,
                total: 501,
                in: app,
                timeout: 10
            )
        )

        let loadMore = element("library-load-more-button", in: app)
        XCTAssertTrue(loadMore.waitForExistence(timeout: 3))
        XCTAssertTrue(
            accessibilityText(of: loadMore).contains("加载更多书籍")
        )

        app.typeKey("l", modifierFlags: [.command, .shift])
        XCTAssertTrue(
            waitForLibraryCount(
                displayed: 400,
                total: 501,
                in: app,
                timeout: 10
            )
        )

        app.typeKey("l", modifierFlags: [.command, .shift])
        XCTAssertTrue(
            waitForLibraryCount(
                displayed: 501,
                total: 501,
                in: app,
                timeout: 10
            )
        )
        XCTAssertTrue(
            element("library-all-results-loaded", in: app)
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(loadMore.waitForNonExistence(timeout: 3))
    }

    @MainActor
    func testGraphOpensThirdPageBookWithoutSubstitutingFirstPageSelection() {
        let app = launchInMemoryApp(seedPagination: true)
        XCTAssertTrue(
            waitForLibraryCount(
                displayed: 200,
                total: 501,
                in: app,
                timeout: 10
            )
        )
        XCTAssertTrue(
            element("book-detail-title", in: app)
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            accessibilityText(of: element("book-detail-title", in: app))
                .contains("《固定分页书目 500》")
        )

        app.typeKey("4", modifierFlags: .command)
        XCTAssertTrue(
            element("local-graph-page", in: app)
                .waitForExistence(timeout: 5)
        )
        let targetID = "30000000-0000-0000-0000-000000000042"
        let targetTitle = "《固定分页书目 042》"
        let graphTarget = element("graph-node-\(targetID)", in: app)
        XCTAssertTrue(graphTarget.waitForExistence(timeout: 10))
        XCTAssertTrue(
            waitForAccessibilityText(
                element("graph-selected-node", in: app),
                containing: targetTitle,
                timeout: 3
            )
        )
        XCTAssertTrue(
            element("graph-open-detail", in: app)
                .waitForExistence(timeout: 3)
        )
        app.activate()
        app.typeKey(.enter, modifierFlags: [])

        let detailTitle = element("book-detail-title", in: app)
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 10))
        XCTAssertTrue(accessibilityText(of: detailTitle).contains(targetTitle))
        XCTAssertFalse(
            accessibilityText(of: detailTitle)
                .contains("《固定分页书目 500》")
        )

        let targetRow = element("library-book-\(targetID)", in: app)
        XCTAssertTrue(targetRow.waitForExistence(timeout: 5))
        XCTAssertTrue(accessibilityText(of: targetRow).contains(targetTitle))
        XCTAssertTrue(
            element("library-focused-book-section", in: app)
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            accessibilityText(
                of: element("library-result-count", in: app)
            ).contains("另显示 1 本定位书籍")
        )
    }

    @MainActor
    func testMissingFocusInEmptyLibraryShowsSpecificAccessibleIssue() {
        let app = launchInMemoryApp(focusMissingBook: true)
        let unavailable = element("library-selection-unavailable", in: app)

        XCTAssertTrue(unavailable.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["找不到请求的书籍"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(element("library-empty-state", in: app).exists)
        XCTAssertFalse(element("library-no-results", in: app).exists)
        XCTAssertFalse(element("book-detail-view", in: app).exists)
    }

    @MainActor
    func testZeroResultSearchShowsFocusedIssueAndClearRecoversLibrary() {
        let app = launchInMemoryApp(seedPagination: true)
        XCTAssertTrue(
            waitForLibraryCount(
                displayed: 200,
                total: 501,
                in: app,
                timeout: 10
            )
        )

        app.typeKey("4", modifierFlags: .command)
        XCTAssertTrue(
            element("local-graph-page", in: app)
                .waitForExistence(timeout: 5)
        )
        app.activate()
        app.typeKey(.enter, modifierFlags: [])
        XCTAssertTrue(
            waitForAccessibilityText(
                element("book-detail-title", in: app),
                containing: "《固定分页书目 042》",
                timeout: 10
            )
        )

        app.typeKey("f", modifierFlags: .command)
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        replaceText(
            in: searchField,
            with: "不存在的固定虚构分页书籍",
            using: app
        )

        let unavailable = element("library-selection-unavailable", in: app)
        XCTAssertTrue(unavailable.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["所选书籍不在当前结果中"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(element("library-no-results", in: app).exists)
        XCTAssertFalse(element("library-empty-state", in: app).exists)
        XCTAssertFalse(element("book-detail-view", in: app).exists)

        let clearFilters = app.buttons["clear-filters-selection-issue"]
        XCTAssertTrue(clearFilters.waitForExistence(timeout: 3))
        clearFilters.click()
        XCTAssertTrue(
            waitForLibraryCount(
                displayed: 200,
                total: 501,
                in: app,
                timeout: 10
            )
        )
        XCTAssertTrue(
            element("library-book-list", in: app)
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(unavailable.waitForNonExistence(timeout: 3))
    }

    @MainActor
    func testSearchCombinesWithStatusFilterAndCanBeCleared() {
        let app = launchInMemoryApp(seedFictionalBooks: true)
        XCTAssertTrue(element("library-book-list", in: app).waitForExistence(timeout: 3))

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        replaceText(in: searchField, with: "A101", using: app)
        let a101Row = element(
            "library-book-00000000-0000-0000-0000-000000000101",
            in: app
        )
        let b202Row = element(
            "library-book-00000000-0000-0000-0000-000000000202",
            in: app
        )
        XCTAssertTrue(a101Row.waitForExistence(timeout: 3))
        XCTAssertFalse(b202Row.exists)
        a101Row.click()
        let detailTitle = element("book-detail-title", in: app)
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 3))
        XCTAssertTrue(
            waitForAccessibilityText(
                detailTitle,
                containing: "A101",
                timeout: 3
            ),
            "Selecting the fixed A101 UUID row must publish the A101 detail"
        )

        element("library-filter-menu", in: app).click()
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(element("active-filter-summary", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(a101Row.exists)
        XCTAssertTrue(
            waitForAccessibilityText(
                detailTitle,
                containing: "A101",
                timeout: 3
            ),
            "Applying the status filter must retain the explicitly selected A101"
        )

        replaceText(
            in: searchField,
            with: "不存在的虚构书",
            using: app
        )
        let unavailable = element("library-selection-unavailable", in: app)
        XCTAssertTrue(unavailable.waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.staticTexts["所选书籍不在当前结果中"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(element("library-no-results", in: app).exists)
        element("clear-filters-button", in: app).click()
        XCTAssertTrue(element("library-book-list", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(unavailable.waitForNonExistence(timeout: 3))

        element("library-sort-menu", in: app).click()
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(element("library-book-list", in: app).exists)
    }

    @MainActor
    func testCommandFFocusesLibrarySearchFromAnotherSection() {
        let app = launchInMemoryApp(seedFictionalBooks: true)
        XCTAssertTrue(element("library-book-list", in: app).waitForExistence(timeout: 3))
        app.typeKey("4", modifierFlags: .command)
        XCTAssertTrue(element("local-graph-page", in: app).waitForExistence(timeout: 3))

        app.typeKey("f", modifierFlags: .command)

        XCTAssertTrue(element("library-book-list", in: app).waitForExistence(timeout: 3))
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        XCTAssertTrue(
            waitForKeyboardFocus(searchField, timeout: 3),
            "Command-F must move keyboard focus to the library search field"
        )
        XCTAssertEqual(searchField.value as? String, "")
        app.typeText("A101")
        XCTAssertTrue(
            element(
                "library-book-00000000-0000-0000-0000-000000000101",
                in: app
            ).waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            element(
                "library-book-00000000-0000-0000-0000-000000000202",
                in: app
            ).waitForNonExistence(timeout: 3)
        )
    }

    @MainActor
    func testCreateCollectionAndSourceWithKeyboardNavigation() {
        let app = launchInMemoryApp()
        XCTAssertTrue(element("library-empty-state", in: app).waitForExistence(timeout: 3))

        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(element("page-title-collections", in: app).waitForExistence(timeout: 3))
        element("add-collection-button", in: app).click()
        replaceText(
            in: element("collection-name-field", in: app),
            with: "North Shelf",
            using: app
        )
        app.typeKey(.tab, modifierFlags: [])
        app.typeText("Fictional collection")
        app.typeKey(.tab, modifierFlags: [])
        element("collection-save-button", in: app).click()
        XCTAssertTrue(catalogRow(named: "North Shelf", in: app).waitForExistence(timeout: 3))

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
        replaceText(
            in: element("source-name-field", in: app),
            with: "Paper Signal",
            using: app
        )
        app.typeKey(.tab, modifierFlags: [])
        app.typeText("Fictional source")
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
        replaceText(
            in: element("tag-name-field", in: app),
            with: "Harbor Revised",
            using: app
        )
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
        replaceText(
            in: element("editor-title", in: app),
            with: "A101 Incoming",
            using: app
        )
        app.typeKey(.tab, modifierFlags: [])
        app.typeText("Harbor Author")
        app.typeKey(.tab, modifierFlags: [])
        app.typeKey(.tab, modifierFlags: [])
        app.typeText("978-0-00000-000-2")

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
        replaceText(
            in: element("editor-title", in: app),
            with: "A101 Recoverable Draft",
            using: app
        )
        app.typeKey(.tab, modifierFlags: [])
        app.typeKey("a", modifierFlags: .command)
        app.typeText("Harbor Author")
        app.typeKey(.tab, modifierFlags: [])
        app.typeKey(.tab, modifierFlags: [])
        app.typeKey("a", modifierFlags: .command)
        app.typeText("978-0-00000-000-2")
        scrollToElement("editor-note", in: app)
        replaceText(
            in: element("editor-note", in: app),
            with: "Fixed fictional draft note",
            using: app
        )

        app.typeKey("s", modifierFlags: .command)
        XCTAssertTrue(element("duplicate-review-sheet", in: app).waitForExistence(timeout: 3))
        app.typeKey("o", modifierFlags: .command)
        let preview = element("duplicate-existing-preview", in: app)
        XCTAssertTrue(preview.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["A101"].exists)

        let explicitBack = element("duplicate-existing-back", in: app)
        XCTAssertTrue(explicitBack.waitForExistence(timeout: 3))
        explicitBack.click()
        XCTAssertTrue(preview.waitForNonExistence(timeout: 3))
        XCTAssertTrue(element("duplicate-review-sheet", in: app).exists)
        XCTAssertFalse(element("editor-discard-changes", in: app).exists)

        app.typeKey("o", modifierFlags: .command)
        XCTAssertTrue(preview.waitForExistence(timeout: 3))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("duplicate-review-sheet", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(preview.waitForNonExistence(timeout: 3))
        XCTAssertTrue(
            element("duplicate-existing-back", in: app).waitForNonExistence(timeout: 3)
        )
        XCTAssertFalse(element("editor-discard-changes", in: app).exists)

        app.typeKey(.escape, modifierFlags: [])

        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(
            element("duplicate-review-sheet", in: app).waitForNonExistence(timeout: 3)
        )
        XCTAssertFalse(element("editor-discard-changes", in: app).exists)
        XCTAssertEqual(
            element("editor-title", in: app).value as? String,
            "A101 Recoverable Draft"
        )
        XCTAssertEqual(
            element("editor-author", in: app).value as? String,
            "Harbor Author"
        )
        XCTAssertEqual(
            element("editor-isbn", in: app).value as? String,
            "978-0-00000-000-2"
        )
        XCTAssertEqual(
            element("editor-note", in: app).value as? String,
            "Fixed fictional draft note"
        )
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
        XCTAssertTrue(accessibilityText(of: targetLink).contains("example.invalid"))
        XCTAssertTrue(accessibilityText(of: sourceLink).contains("example.invalid"))
        XCTAssertFalse(accessibilityText(of: targetLink).contains("/retained"))
        XCTAssertFalse(accessibilityText(of: sourceLink).contains("/incoming"))
        let relationText = accessibilityText(of: relation)
        XCTAssertTrue(relationText.contains("本书指向"), relationText)
        XCTAssertTrue(relationText.contains("回应"), relationText)
        XCTAssertTrue(relationText.contains("《虚构灯塔》"), relationText)
        XCTAssertTrue(relationText.contains("有备注"), relationText)
    }

    @MainActor
    func testDatabaseUnavailableUsesGenericErrorState() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            "-BookAtlasForceUnavailableStore",
        ]
        app.launch()

        XCTAssertTrue(element("library-load-error", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["无法打开本地书库"].exists)
    }

    @MainActor
    func testImportPreviewExposesCountsMappingRowsAndKeyboardCancellation() {
        let app = launchInMemoryApp(seedPortabilityPreview: true)
        app.typeKey("5", modifierFlags: .command)

        XCTAssertTrue(element("data-portability-page", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("import-preview", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("import-preview-counts", in: app).exists)
        XCTAssertTrue(element("import-field-mapping", in: app).exists)
        XCTAssertTrue(element("import-preview-row-0", in: app).exists)
        XCTAssertTrue(element("confirm-import-button", in: app).exists)
        XCTAssertTrue(
            accessibilityText(of: element("import-preview-row-0", in: app))
                .contains("虚构导入港湾")
        )

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("import-preview", in: app).waitForNonExistence(timeout: 3))
        XCTAssertTrue(element("portability-status", in: app).waitForExistence(timeout: 3))
    }

    @MainActor
    func testRestorePreviewExposesWarningAndKeyboardCancellation() {
        let app = launchInMemoryApp(seedRestorePreview: true)
        app.typeKey("5", modifierFlags: .command)

        XCTAssertTrue(element("restore-preview", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("restore-preview-details", in: app).exists)
        XCTAssertTrue(element("restore-replacement-warning", in: app).exists)
        XCTAssertTrue(element("confirm-restore-button", in: app).exists)

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("restore-preview", in: app).waitForNonExistence(timeout: 3))
        XCTAssertTrue(element("portability-status", in: app).waitForExistence(timeout: 3))
    }

    @MainActor
    func testSafeReplacementDisablesCancelAndEscapeWhileRemainingAccessible() {
        let app = launchInMemoryApp(seedSafeReplacement: true)
        app.typeKey("5", modifierFlags: .command)

        XCTAssertTrue(element("restore-preview", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("restore-safe-replacement", in: app).waitForExistence(timeout: 3))
        let cancel = element("cancel-restore-button", in: app)
        XCTAssertTrue(cancel.exists)
        XCTAssertFalse(cancel.isEnabled)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("restore-preview", in: app).exists)
        XCTAssertTrue(element("restore-safe-replacement", in: app).exists)
    }

    @MainActor
    func testRestoreInspectionIsAccessibleAndCancellableWithEscape() {
        let app = launchInMemoryApp(seedRestoreInspection: true)
        app.typeKey("5", modifierFlags: .command)

        XCTAssertTrue(element("restore-progress", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("restore-progress-phase", in: app).exists)
        XCTAssertTrue(element("cancel-restore-button", in: app).isEnabled)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("restore-progress", in: app).waitForNonExistence(timeout: 3))
        XCTAssertTrue(element("portability-status", in: app).waitForExistence(timeout: 3))
    }

    @MainActor
    func testLocalGraphOpensFromDetailExposesConcreteEvidenceAndReturnsToBookDetail() {
        let app = launchInMemoryApp(seedGraph: true)
        selectGraphCenter(in: app)
        element("show-local-graph-button", in: app).click()

        XCTAssertTrue(element("local-graph-page", in: app).waitForExistence(timeout: 3))
        let relation = element(
            "graph-relation-00000000-0000-0000-0000-000000000601-00000000-0000-0000-0000-000000000602",
            in: app
        )
        XCTAssertTrue(relation.waitForExistence(timeout: 3))
        let relationText = accessibilityText(of: relation)
        for expected in ["同作者", "共同标签", "同一书单", "同一来源", "手动关系", "含备注"] {
            XCTAssertTrue(relationText.contains(expected), "\(expected): \(relationText)")
        }

        let directNode = element(
            "graph-node-00000000-0000-0000-0000-000000000602",
            in: app
        )
        XCTAssertTrue(directNode.waitForExistence(timeout: 3))
        directNode.click()
        XCTAssertTrue(app.staticTexts["《雾港直接邻居》"].waitForExistence(timeout: 3))
        element("graph-open-detail", in: app).click()
        XCTAssertTrue(element("book-detail-view", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["《雾港直接邻居》"].exists)
    }

    @MainActor
    func testLocalGraphReloadsAfterLeavingEditingAndReturning() {
        let app = launchInMemoryApp(seedGraph: true)
        selectGraphCenter(in: app)
        element("show-local-graph-button", in: app).click()

        let neighbor = element(
            "graph-node-00000000-0000-0000-0000-000000000602",
            in: app
        )
        XCTAssertTrue(neighbor.waitForExistence(timeout: 3))
        neighbor.click()
        element("graph-open-detail", in: app).click()
        XCTAssertTrue(element("book-detail-view", in: app).waitForExistence(timeout: 3))

        element("edit-book-button", in: app).click()
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))
        replaceText(
            in: element("editor-title", in: app),
            with: "《雾港刷新邻居》",
            using: app
        )
        app.typeKey("s", modifierFlags: .command)
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForNonExistence(timeout: 3))

        element("navigation-graph", in: app).click()
        XCTAssertTrue(element("local-graph-page", in: app).waitForExistence(timeout: 3))
        let refreshedNeighbor = element(
            "graph-node-00000000-0000-0000-0000-000000000602",
            in: app
        )
        XCTAssertTrue(refreshedNeighbor.waitForExistence(timeout: 5))
        XCTAssertTrue(accessibilityText(of: refreshedNeighbor).contains("雾港刷新邻居"))
        XCTAssertFalse(accessibilityText(of: refreshedNeighbor).contains("雾港直接邻居"))
    }

    @MainActor
    func testLocalGraphKeyboardSelectionTwoLayersFilteringCenterAndReset() {
        let app = launchInMemoryApp(seedGraph: true)
        selectGraphCenter(in: app)
        element("show-local-graph-button", in: app).click()
        XCTAssertTrue(
            element("graph-node-00000000-0000-0000-0000-000000000601", in: app)
                .waitForExistence(timeout: 3)
        )

        let secondLayer = element(
            "graph-node-00000000-0000-0000-0000-000000000603",
            in: app
        )
        XCTAssertFalse(secondLayer.exists)
        element("graph-depth-2", in: app).click()
        XCTAssertTrue(secondLayer.waitForExistence(timeout: 3))

        let sharedTagFilter = element("graph-filter-sharedTag", in: app)
        XCTAssertTrue(sharedTagFilter.waitForExistence(timeout: 3))
        sharedTagFilter.click()
        XCTAssertTrue(secondLayer.waitForNonExistence(timeout: 3))

        let centerNode = element(
            "graph-node-00000000-0000-0000-0000-000000000601",
            in: app
        )
        centerNode.click()
        app.typeKey(.downArrow, modifierFlags: .command)
        let selectedNode = element("graph-selected-node", in: app)
        XCTAssertTrue(selectedNode.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: selectedNode).contains("雾港直接邻居"))

        let resetButton = app.buttons["重置视图"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 3))
        resetButton.click()
        XCTAssertTrue(
            element("graph-node-00000000-0000-0000-0000-000000000601", in: app)
                .waitForExistence(timeout: 3)
        )

        let directNode = element(
            "graph-node-00000000-0000-0000-0000-000000000602",
            in: app
        )
        directNode.click()
        element("graph-set-center", in: app).click()
        let newCenterNode = element(
            "graph-node-00000000-0000-0000-0000-000000000602",
            in: app
        )
        XCTAssertTrue(newCenterNode.waitForExistence(timeout: 3))
        let centerPredicate = NSPredicate(format: "label CONTAINS %@", "中心书籍")
        let centerExpectation = XCTNSPredicateExpectation(
            predicate: centerPredicate,
            object: newCenterNode
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [centerExpectation], timeout: 5),
            .completed
        )
        XCTAssertTrue(element("local-graph-page", in: app).waitForExistence(timeout: 3))
    }

    @MainActor
    func testLocalGraphEmptyStateIsExplicit() {
        let emptyApp = launchInMemoryApp(seedFictionalBooks: true)
        XCTAssertTrue(element("library-book-list", in: emptyApp).waitForExistence(timeout: 3))
        element("show-local-graph-button", in: emptyApp).click()
        XCTAssertTrue(emptyApp.staticTexts["这本书暂无有效关系"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testLocalGraphLimitStateIsExplicit() {
        let limitedApp = launchInMemoryApp(seedGraphLimit: true)
        selectGraphCenter(in: limitedApp)
        element("show-local-graph-button", in: limitedApp).click()
        let limitStatus = limitedApp.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "图谱状态：")
        ).firstMatch
        XCTAssertTrue(limitStatus.waitForExistence(timeout: 5))
        XCTAssertTrue(accessibilityText(of: limitStatus).contains("截断"))
        XCTAssertTrue(
            element("graph-node-00000000-0000-0000-0000-000000000601", in: limitedApp)
                .exists
        )
    }

    @MainActor
    func testReadingEntryEmptyStateRejectsUnsafeURLsAndEscapeCancelsEditor() {
        let app = launchInMemoryApp(seedFictionalBooks: true)
        let addLink = element("add-reading-link", in: app)
        XCTAssertTrue(addLink.waitForExistence(timeout: 3))
        scrollToReadingEntries(in: app)
        XCTAssertTrue(element("reading-entry-empty", in: app).exists)

        addLink.click()
        XCTAssertTrue(element("reading-link-editor", in: app).waitForExistence(timeout: 3))
        replaceText(
            in: element("reading-link-value", in: app),
            with: "javascript:alert(1)",
            using: app
        )
        element("save-reading-link", in: app).click()
        XCTAssertTrue(element("reading-link-validation", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(
            accessibilityText(of: element("reading-link-validation", in: app))
                .contains("仅允许 HTTPS")
        )

        replaceText(
            in: element("reading-link-value", in: app),
            with: "http://example.invalid/unsafe",
            using: app
        )
        element("save-reading-link", in: app).click()
        XCTAssertTrue(
            accessibilityText(of: element("reading-link-validation", in: app))
                .contains("HTTP")
        )
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("reading-link-editor", in: app).waitForNonExistence(timeout: 3))
        XCTAssertTrue(element("reading-entry-empty", in: app).exists)
    }

    @MainActor
    func testReadingEntryHTTPSCRUDShowsOnlySafeHostAndConfirmsDeletion() {
        let app = launchInMemoryApp(seedFictionalBooks: true)
        scrollToReadingEntries(in: app)
        element("add-reading-link", in: app).click()
        replaceText(
            in: element("reading-link-label", in: app),
            with: "fictional reader",
            using: app
        )
        app.typeKey(.tab, modifierFlags: [])
        app.typeKey("a", modifierFlags: .command)
        app.typeText("https://reader.example.invalid/private-segment")
        element("save-reading-link", in: app).click()

        let savedLinkRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "reading-link-row-")
        ).firstMatch
        XCTAssertTrue(savedLinkRow.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: savedLinkRow).contains("reader.example.invalid"))
        XCTAssertFalse(accessibilityText(of: savedLinkRow).contains("private-segment"))
        let open = app.buttons["打开"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 3))
        open.click()
        let openStatus = element("reading-entry-status", in: app)
        XCTAssertTrue(openStatus.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: openStatus).contains("reader.example.invalid"))
        XCTAssertFalse(accessibilityText(of: openStatus).contains("private-segment"))
        let edit = app.buttons["编辑"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 3))
        edit.click()
        replaceText(
            in: element("reading-link-label", in: app),
            with: "fictional reader revised",
            using: app
        )
        element("save-reading-link", in: app).click()
        XCTAssertTrue(element("reading-link-editor", in: app).waitForNonExistence(timeout: 3))
        let revisedLinkRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "reading-link-row-")
        ).firstMatch
        XCTAssertTrue(revisedLinkRow.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: revisedLinkRow).contains("fictional reader revised"))

        app.buttons["删除"].firstMatch.click()
        XCTAssertTrue(
            element("confirm-delete-reading-link", in: app).waitForExistence(timeout: 3)
        )
        element("confirm-delete-reading-link", in: app).click()
        XCTAssertTrue(revisedLinkRow.waitForNonExistence(timeout: 3))
        XCTAssertTrue(element("reading-entry-empty", in: app).exists)
    }

    @MainActor
    func testReadingEntryAppleBooksCopyAndLocalFileFailureUseTestDoubles() {
        let app = launchInMemoryApp(seedReadingEntries: true)
        scrollToReadingEntries(in: app)

        scrollToElement(
            "reading-link-row-00000000-0000-0000-0000-000000000901",
            in: app
        )
        XCTAssertTrue(
            element(
                "reading-link-row-00000000-0000-0000-0000-000000000901",
                in: app
            ).waitForExistence(timeout: 3)
        )
        XCTAssertFalse(
            accessibilityText(
                of: element(
                    "reading-link-row-00000000-0000-0000-0000-000000000901",
                    in: app
                )
            ).contains("private-segment")
        )
        scrollToElement(
            "local-file-row-00000000-0000-0000-0000-000000000902",
            in: app
        )
        XCTAssertTrue(
            element(
                "local-file-row-00000000-0000-0000-0000-000000000902",
                in: app
            ).exists
        )
        scrollToElement("apple-books-capability-note", in: app)
        XCTAssertTrue(element("apple-books-capability-note", in: app).exists)

        scrollToElement("copy-book-isbn", in: app)
        element("copy-book-isbn", in: app).click()
        scrollToElement("reading-entry-status", in: app)
        XCTAssertTrue(element("reading-entry-status", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(
            accessibilityText(of: element("reading-entry-status", in: app)).contains("复制 ISBN")
        )
        scrollToElement("copy-book-title", in: app)
        element("copy-book-title", in: app).click()
        scrollToElement("reading-entry-status", in: app)
        XCTAssertTrue(
            accessibilityText(of: element("reading-entry-status", in: app)).contains("复制书名")
        )

        scrollToElement("apple-books-fallback", in: app)
        element("apple-books-fallback", in: app).click()
        XCTAssertTrue(
            element("confirm-apple-books-fallback", in: app).waitForExistence(timeout: 3)
        )
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(
            element("confirm-apple-books-fallback", in: app).waitForNonExistence(timeout: 3)
        )

        scrollToElement(
            "open-local-file-00000000-0000-0000-0000-000000000902",
            in: app
        )
        element("open-local-file-00000000-0000-0000-0000-000000000902", in: app).click()
        scrollToElement("reading-entry-error", in: app)
        XCTAssertTrue(element("reading-entry-error", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(
            accessibilityText(of: element("reading-entry-error", in: app))
                .contains("授权已损坏")
        )
        scrollToElement("choose-local-file", in: app)
        element("choose-local-file", in: app).click()
        scrollToElement("reading-entry-status", in: app)
        XCTAssertTrue(
            accessibilityText(of: element("reading-entry-status", in: app))
                .contains("已取消选择")
        )

        scrollToElement(
            "remove-local-file-00000000-0000-0000-0000-000000000902",
            in: app
        )
        element("remove-local-file-00000000-0000-0000-0000-000000000902", in: app).click()
        XCTAssertTrue(element("confirm-remove-local-file", in: app).waitForExistence(timeout: 3))
        element("confirm-remove-local-file", in: app).click()
        XCTAssertTrue(
            element(
                "local-file-row-00000000-0000-0000-0000-000000000902",
                in: app
            ).waitForNonExistence(timeout: 3)
        )
    }

    @MainActor
    func testDuplicateCandidateReadingEntriesAreReadOnlyAndDoNotPolluteMainDetail() {
        let app = launchInMemoryApp(seedReadingEntries: true)
        let primaryBookRow = element(
            "library-book-00000000-0000-0000-0000-000000000101",
            in: app
        )
        XCTAssertTrue(primaryBookRow.waitForExistence(timeout: 3))
        primaryBookRow.click()
        element("review-duplicates-button", in: app).click()
        XCTAssertTrue(
            element("duplicate-review-sheet", in: app).waitForExistence(timeout: 3)
        )
        let candidateRow = app.staticTexts
            .matching(
                identifier: "duplicate-candidate-00000000-0000-0000-0000-000000000202"
            )
            .firstMatch
        XCTAssertTrue(candidateRow.waitForExistence(timeout: 3))
        candidateRow.click()
        let viewExisting = element("duplicate-view-existing-inline", in: app)
        XCTAssertTrue(viewExisting.waitForExistence(timeout: 3))
        viewExisting.click()
        let preview = element("duplicate-existing-preview", in: app)
        XCTAssertTrue(preview.waitForExistence(timeout: 3))
        XCTAssertTrue(
            preview.descendants(matching: .any)[
                "reading-link-row-00000000-0000-0000-0000-000000000903"
            ].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            preview.descendants(matching: .any)[
                "local-file-row-00000000-0000-0000-0000-000000000904"
            ].exists
        )
        XCTAssertTrue(
            preview.descendants(matching: .any)["reading-entries-read-only"].exists
        )
        XCTAssertFalse(
            preview.descendants(matching: .any)["add-reading-link"].exists
        )
        XCTAssertFalse(
            preview.descendants(matching: .any)[
                "edit-reading-link-00000000-0000-0000-0000-000000000903"
            ].exists
        )
        XCTAssertFalse(
            preview.descendants(matching: .any)[
                "remove-local-file-00000000-0000-0000-0000-000000000904"
            ].exists
        )
        for unavailableAction in [
            "open-reading-link-00000000-0000-0000-0000-000000000903",
            "delete-reading-link-00000000-0000-0000-0000-000000000903",
            "open-local-file-00000000-0000-0000-0000-000000000904",
            "choose-local-file",
            "apple-books-fallback",
            "copy-book-isbn",
            "copy-book-title"
        ] {
            XCTAssertFalse(preview.descendants(matching: .any)[unavailableAction].exists)
        }

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(preview.waitForNonExistence(timeout: 3))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(
            element("duplicate-review-sheet", in: app).waitForNonExistence(timeout: 3)
        )
        scrollToElement(
            "reading-link-row-00000000-0000-0000-0000-000000000901",
            in: app
        )
        XCTAssertTrue(
            element(
                "reading-link-row-00000000-0000-0000-0000-000000000901",
                in: app
            ).waitForExistence(timeout: 3)
        )
        XCTAssertFalse(
            element(
                "reading-link-row-00000000-0000-0000-0000-000000000903",
                in: app
            ).exists
        )
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func measureColdLaunch(bookCount: Int) {
        let sessionID = UUID()
        preparePerformanceLibrary(
            sessionID: sessionID,
            bookCount: bookCount
        )
        var measuredApplication: XCUIApplication?
        defer {
            measuredApplication?.terminate()
            cleanupPerformanceLibrary(sessionID: sessionID)
        }

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(
            metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)],
            options: options
        ) {
            measuredApplication?.terminate()
            let app = performanceApplication(
                mode: .useExisting,
                sessionID: sessionID,
                bookCount: bookCount
            )
            measuredApplication = app
            app.launch()
            XCTAssertTrue(
                element("library-book-list", in: app)
                    .waitForExistence(timeout: 30)
            )
            XCTAssertTrue(
                waitForLibraryCount(
                    displayed: LibraryQueryPageSize.value,
                    total: bookCount,
                    in: app,
                    timeout: 30
                ),
                "Measured process must open the pre-generated \(bookCount)-book library"
            )
        }
    }

    @MainActor
    private func measureSustainedListScrolling(bookCount: Int) {
        let sessionID = UUID()
        preparePerformanceLibrary(
            sessionID: sessionID,
            bookCount: bookCount
        )
        var activeApplication: XCUIApplication?
        defer {
            activeApplication?.terminate()
            cleanupPerformanceLibrary(sessionID: sessionID)
        }

        for run in 1 ... 3 {
            let pageApplication = performanceApplication(
                mode: .useExisting,
                sessionID: sessionID,
                bookCount: bookCount
            )
            activeApplication = pageApplication
            pageApplication.launch()
            XCTAssertTrue(
                waitForLibraryCount(
                    displayed: LibraryQueryPageSize.value,
                    total: bookCount,
                    in: pageApplication,
                    timeout: 30
                )
            )

            let pageStart = ContinuousClock.now
            guard loadNextPerformancePage(
                expectedDisplayed: LibraryQueryPageSize.value * 2,
                total: bookCount,
                in: pageApplication,
                timeout: 30
            ) else {
                XCTFail("The measured next page did not finish loading")
                return
            }
            let pageDuration = pageStart.duration(to: .now)
            print(
                """
                P10_PAGE_LOAD_BASELINE configuration=\(buildConfiguration) \
                books=\(bookCount) run=\(run) from=\(LibraryQueryPageSize.value) \
                to=\(LibraryQueryPageSize.value * 2) \
                next_page=\(seconds(pageDuration))
                """
            )
            pageApplication.terminate()
            activeApplication = nil
        }

        let app = performanceApplication(
            mode: .useExisting,
            sessionID: sessionID,
            bookCount: bookCount
        )
        activeApplication = app
        app.launch()
        let list = element("library-book-list", in: app)
        XCTAssertTrue(list.waitForExistence(timeout: 30))
        XCTAssertTrue(
            waitForLibraryCount(
                displayed: LibraryQueryPageSize.value,
                total: bookCount,
                in: app,
                timeout: 30
            )
        )

        let targetLoadedRows: Int
        switch bookCount {
        case 1_000:
            targetLoadedRows = 1_000
        case 5_000:
            targetLoadedRows = 2_000
        default:
            targetLoadedRows = 3_000
        }
        var loadedRows = LibraryQueryPageSize.value
        while loadedRows < targetLoadedRows {
            let expectedRows = min(
                loadedRows + LibraryQueryPageSize.value,
                targetLoadedRows
            )
            guard loadNextPerformancePage(
                expectedDisplayed: expectedRows,
                total: bookCount,
                in: app,
                timeout: 30
            ) else {
                XCTFail(
                    "Paging stopped at \(loadedRows) of \(targetLoadedRows) rows"
                )
                return
            }
            loadedRows = expectedRows
        }

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        var metrics: [any XCTMetric] = [
            XCTClockMetric(),
            XCTCPUMetric(application: app),
            XCTMemoryMetric(application: app)
        ]
        if #available(macOS 26.0, *) {
            metrics.append(XCTHitchMetric(application: app))
        }

        list.click()
        app.typeKey(.upArrow, modifierFlags: .command)
        print(
            """
            P10_SCROLL_WORKLOAD configuration=\(buildConfiguration) \
            books=\(bookCount) \
            loaded_pages=\(targetLoadedRows / LibraryQueryPageSize.value) \
            loaded_rows=\(targetLoadedRows) scroll_events=4 \
            absolute_delta_per_event=4800
            """
        )
        measure(metrics: metrics, options: options) {
            list.scroll(byDeltaX: 0, deltaY: -4_800)
            list.scroll(byDeltaX: 0, deltaY: -4_800)
            list.scroll(byDeltaX: 0, deltaY: 4_800)
            list.scroll(byDeltaX: 0, deltaY: 4_800)
        }
        app.terminate()
        activeApplication = nil
    }

    @MainActor
    private func preparePerformanceLibrary(
        sessionID: UUID,
        bookCount: Int
    ) {
        let preparationApp = performanceApplication(
            mode: .prepare,
            sessionID: sessionID,
            bookCount: bookCount
        )
        preparationApp.launch()
        XCTAssertTrue(
            preparationApp.wait(for: .runningForeground, timeout: 30),
            "Performance data preparation process must initialize"
        )
        preparationApp.terminate()

        let verificationApp = performanceApplication(
            mode: .useExisting,
            sessionID: sessionID,
            bookCount: bookCount
        )
        verificationApp.launch()
        XCTAssertTrue(
            waitForLibraryCount(
                displayed: LibraryQueryPageSize.value,
                total: bookCount,
                in: verificationApp,
                timeout: 30
            ),
            "An untimed use-existing process must verify the prepared library before measurement"
        )
        verificationApp.terminate()
    }

    @MainActor
    private func cleanupPerformanceLibrary(sessionID: UUID) {
        let app = performanceApplication(
            mode: .cleanup,
            sessionID: sessionID,
            bookCount: nil
        )
        app.launch()
        XCTAssertTrue(
            element("library-empty-state", in: app)
                .waitForExistence(timeout: 30),
            "The controlled performance library and SQLite sidecars must be removed"
        )
        app.terminate()
    }

    @MainActor
    private func performanceApplication(
        mode: PerformanceLibraryMode,
        sessionID: UUID,
        bookCount: Int?
    ) -> XCUIApplication {
        let app = XCUIApplication()
        switch mode {
        case .prepare:
            app.launchArguments = [
                "-ApplePersistenceIgnoreState", "YES",
                "-BookAtlasPerformancePrepareLibrary",
                sessionID.uuidString,
                String(bookCount ?? 0)
            ]
        case .useExisting:
            app.launchArguments = [
                "-ApplePersistenceIgnoreState", "YES",
                "-BookAtlasPerformanceUseExistingLibrary",
                sessionID.uuidString
            ]
        case .cleanup:
            app.launchArguments = [
                "-ApplePersistenceIgnoreState", "YES",
                "-BookAtlasPerformanceCleanupLibrary",
                sessionID.uuidString
            ]
        }
        return app
    }

    @MainActor
    private func waitForLibraryCount(
        displayed: Int,
        total: Int,
        in app: XCUIApplication,
        timeout: TimeInterval
    ) -> Bool {
        let status = app.staticTexts["library-result-count"]
        guard status.waitForExistence(timeout: timeout) else {
            return false
        }
        let state = displayed < total ? "可以继续加载" : "已全部加载"
        return waitForAccessibilityText(
            status,
            containing: "已显示 \(displayed) 本，共 \(total) 本，\(state)",
            timeout: timeout
        )
    }

    @MainActor
    private func loadNextPerformancePage(
        expectedDisplayed: Int,
        total: Int,
        in app: XCUIApplication,
        timeout: TimeInterval
    ) -> Bool {
        app.activate()
        app.typeKey("l", modifierFlags: [.command, .shift])
        return waitForLibraryCount(
            displayed: expectedDisplayed,
            total: total,
            in: app,
            timeout: timeout
        )
    }

    private var buildConfiguration: String {
        Bundle(for: BookAtlasUITests.self).bundleURL.pathComponents
            .contains("Debug") ? "Debug" : "Release"
    }

    private func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    @MainActor
    private func launchInMemoryApp(
        seedFictionalBooks: Bool = false,
        seedMergePreviewAssociations: Bool = false,
        seedPortabilityPreview: Bool = false,
        seedRestorePreview: Bool = false,
        seedSafeReplacement: Bool = false,
        seedRestoreInspection: Bool = false,
        seedGraph: Bool = false,
        seedGraphLimit: Bool = false,
        seedReadingEntries: Bool = false,
        seedPagination: Bool = false,
        focusMissingBook: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            "-BookAtlasUseInMemoryStore",
        ]
        if seedFictionalBooks {
            app.launchArguments.append("-BookAtlasSeedFictionalUITestBooks")
        }
        if seedMergePreviewAssociations {
            app.launchArguments.append("-BookAtlasSeedMergePreviewAssociations")
        }
        if seedPortabilityPreview {
            app.launchArguments.append("-BookAtlasSeedPortabilityPreview")
        }
        if seedRestorePreview {
            app.launchArguments.append("-BookAtlasSeedRestorePreview")
        }
        if seedSafeReplacement {
            app.launchArguments.append("-BookAtlasSeedSafeReplacement")
        }
        if seedRestoreInspection {
            app.launchArguments.append("-BookAtlasSeedRestoreInspection")
        }
        if seedGraph {
            app.launchArguments.append("-BookAtlasSeedGraphUITestData")
        }
        if seedGraphLimit {
            app.launchArguments.append("-BookAtlasSeedGraphLimitUITestData")
        }
        if seedReadingEntries {
            app.launchArguments.append("-BookAtlasSeedReadingEntryUITestData")
        }
        if seedPagination {
            app.launchArguments.append("-BookAtlasSeedPaginationUITestData")
        }
        if focusMissingBook {
            app.launchArguments.append("-BookAtlasFocusMissingBookUITestState")
        }
        app.launch()
        return app
    }

    @MainActor
    private func scrollToReadingEntries(in app: XCUIApplication) {
        let section = element("reading-entries-section", in: app)
        XCTAssertTrue(section.waitForExistence(timeout: 3))
        scrollToElement("add-reading-link", in: app)
    }

    @MainActor
    private func scrollToElement(_ identifier: String, in app: XCUIApplication) {
        let target = element(identifier, in: app)
        let editorScrollView = element("book-editor-sheet", in: app).scrollViews.firstMatch
        let scrollView = editorScrollView.exists
            ? editorScrollView
            : app.scrollViews.firstMatch
        for _ in 0..<8 {
            if target.exists, target.isHittable { return }
            scrollView.scroll(byDeltaX: 0, deltaY: -250)
        }
        for _ in 0..<16 {
            if target.exists, target.isHittable { return }
            scrollView.scroll(byDeltaX: 0, deltaY: 250)
        }
        XCTAssertTrue(target.exists)
        XCTAssertTrue(target.isHittable)
    }

    @MainActor
    private func createFictionalBook(
        in app: XCUIApplication,
        title: String = "A101",
        author: String = "L101"
    ) {
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(element("book-editor-sheet", in: app).waitForExistence(timeout: 3))
        replaceText(
            in: element("editor-title", in: app),
            with: title,
            using: app
        )
        app.typeKey(.tab, modifierFlags: [])
        app.typeText(author)
        app.typeKey("s", modifierFlags: .command)
        XCTAssertTrue(element("book-detail-view", in: app).waitForExistence(timeout: 3))
    }

    @MainActor
    private func replaceText(
        in element: XCUIElement,
        with value: String,
        using app: XCUIApplication
    ) {
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 3))
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        element.click()
        if !waitForKeyboardFocus(element, timeout: 1) {
            app.activate()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 3))
            XCTAssertTrue(element.waitForExistence(timeout: 3))
            element.click()
        }
        XCTAssertTrue(
            waitForKeyboardFocus(element, timeout: 3),
            "Text input must have keyboard focus before replacing its value"
        )
        element.typeKey("a", modifierFlags: .command)
        element.typeText(value)
    }

    @MainActor
    private func selectGraphCenter(in app: XCUIApplication) {
        XCTAssertTrue(element("library-book-list", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("show-local-graph-button", in: app).waitForExistence(timeout: 3))
    }

    @MainActor
    private func createTag(named name: String, in app: XCUIApplication) {
        element("add-tag-button", in: app).click()
        replaceText(
            in: element("tag-name-field", in: app),
            with: name,
            using: app
        )
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
    private func waitForKeyboardFocus(
        _ element: XCUIElement,
        timeout: TimeInterval = 3
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hasKeyboardFocus == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func clickEditorSave(in app: XCUIApplication) {
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 3))
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 3))
        let button = app.buttons["保存书籍"]
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        button.click()
    }

    @MainActor
    private func assertVisibleEditorValidation(
        _ expectedMessage: String,
        fieldIdentifier: String?,
        fieldErrorIdentifier: String,
        in app: XCUIApplication
    ) {
        let editor = element("book-editor-sheet", in: app)
        let summary = element("editor-validation-error", in: app)
        let fieldError = element(fieldErrorIdentifier, in: app)

        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        XCTAssertTrue(summary.waitForExistence(timeout: 3))
        XCTAssertTrue(
            waitForAccessibilityText(
                summary,
                containing: expectedMessage,
                timeout: 3
            )
        )
        XCTAssertTrue(fieldError.waitForExistence(timeout: 3))
        XCTAssertTrue(
            waitForAccessibilityText(
                fieldError,
                containing: expectedMessage,
                timeout: 3
            )
        )
        XCTAssertFalse(summary.frame.isEmpty)
        XCTAssertTrue(
            summary.frame.intersects(editor.frame),
            "Validation summary must be visible inside the current editor viewport"
        )
        XCTAssertTrue(
            summary.frame.intersects(app.windows.firstMatch.frame),
            "Validation summary must be visible without scrolling"
        )

        if let fieldIdentifier {
            XCTAssertTrue(
                waitForKeyboardFocus(
                    element(fieldIdentifier, in: app),
                    timeout: 3
                ),
                "The invalid required field must receive keyboard focus"
            )
        }
    }

    @MainActor
    private func waitForAccessibilityText(
        _ element: XCUIElement,
        containing text: String,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate(
            format: "label CONTAINS %@ OR value CONTAINS %@",
            text,
            text
        )
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func accessibilityText(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
