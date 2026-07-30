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
        replaceText(in: element("collection-name-field", in: app), with: "North Shelf")
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
        replaceText(in: element("source-name-field", in: app), with: "Paper Signal")
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
        replaceText(in: element("editor-title", in: app), with: "A101 Recoverable Draft")
        replaceText(in: element("editor-author", in: app), with: "Harbor Author")
        replaceText(in: element("editor-isbn", in: app), with: "978-0-00000-000-2")
        scrollToElement("editor-note", in: app)
        replaceText(in: element("editor-note", in: app), with: "Fixed fictional draft note")

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
        XCTAssertEqual(element("editor-author", in: app).value as? String, "Harbor Author")
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
        app.launchArguments = ["-BookAtlasForceUnavailableStore"]
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
        replaceText(in: element("editor-title", in: app), with: "《雾港刷新邻居》")
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
            with: "javascript:alert(1)"
        )
        element("save-reading-link", in: app).click()
        XCTAssertTrue(element("reading-link-validation", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(
            accessibilityText(of: element("reading-link-validation", in: app))
                .contains("仅允许 HTTPS")
        )

        replaceText(
            in: element("reading-link-value", in: app),
            with: "http://example.invalid/unsafe"
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
        replaceText(in: element("reading-link-label", in: app), with: "Fictional Reader")
        replaceText(
            in: element("reading-link-value", in: app),
            with: "https://reader.example.invalid/private-segment"
        )
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
        replaceText(in: element("reading-link-label", in: app), with: "Fictional Reader Revised")
        element("save-reading-link", in: app).click()
        XCTAssertTrue(element("reading-link-editor", in: app).waitForNonExistence(timeout: 3))
        let revisedLinkRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "reading-link-row-")
        ).firstMatch
        XCTAssertTrue(revisedLinkRow.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: revisedLinkRow).contains("Fictional Reader Revised"))

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
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        var invocation = 0
        measure(
            metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)],
            options: options
        ) {
            invocation += 1
            let app = performanceApplication(bookCount: bookCount)
            app.terminate()
            let start = ContinuousClock.now
            app.launch()
            XCTAssertTrue(
                element("library-book-list", in: app)
                    .waitForExistence(timeout: 45)
            )
            let duration = start.duration(to: .now)
            print(
                """
                P10_COLD_LAUNCH_BASELINE configuration=\(buildConfiguration) \
                books=\(bookCount) invocation=\(invocation) \
                launch_to_loaded_list=\(seconds(duration))
                """
            )
        }
    }

    @MainActor
    private func measureSustainedListScrolling(bookCount: Int) {
        let app = performanceApplication(bookCount: bookCount)
        app.launch()
        let list = element("library-book-list", in: app)
        XCTAssertTrue(list.waitForExistence(timeout: 45))

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
        var invocation = 0
        measure(metrics: metrics, options: options) {
            invocation += 1
            let start = ContinuousClock.now
            for _ in 0 ..< 2 {
                list.scroll(byDeltaX: 0, deltaY: -4_800)
            }
            for _ in 0 ..< 2 {
                list.scroll(byDeltaX: 0, deltaY: 4_800)
            }
            let duration = start.duration(to: .now)
            print(
                """
                P10_SCROLL_BASELINE configuration=\(buildConfiguration) \
                books=\(bookCount) invocation=\(invocation) \
                round_trip=\(seconds(duration))
                """
            )
        }
        app.terminate()
    }

    @MainActor
    private func performanceApplication(bookCount: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-BookAtlasUseInMemoryStore",
            "-BookAtlasPerformanceBookCount",
            String(bookCount)
        ]
        return app
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
        seedReadingEntries: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-BookAtlasUseInMemoryStore"]
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
        for _ in 0..<8 {
            if target.exists, target.isHittable { return }
            app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -250)
        }
        for _ in 0..<16 {
            if target.exists, target.isHittable { return }
            app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: 250)
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
        replaceText(in: element("editor-title", in: app), with: title)
        app.typeKey(.tab, modifierFlags: [])
        app.typeText(author)
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
    private func selectGraphCenter(in app: XCUIApplication) {
        XCTAssertTrue(element("library-book-list", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("show-local-graph-button", in: app).waitForExistence(timeout: 3))
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
    private func waitForKeyboardFocus(
        _ element: XCUIElement,
        timeout: TimeInterval = 3
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hasKeyboardFocus == true")
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
