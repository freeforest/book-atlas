import Foundation
import XCTest
@testable import BookAtlas

@MainActor
final class ReadingEntryTests: XCTestCase {
    func testStrictHTTPSValidationAcceptsSafeWebAndAppleBooksHosts() throws {
        let validator = StrictHTTPSLinkValidator()
        let web = try validator.validate("https://example.invalid/fictional?q=1")
        let store = try validator.validate("https://books.apple.com/us/book/id123")

        XCTAssertEqual(web.safeHost, "example.invalid")
        XCTAssertEqual(web.kind, .web)
        XCTAssertEqual(store.safeHost, "books.apple.com")
        XCTAssertEqual(store.kind, .appleBooksStore)
        XCTAssertEqual(
            try validator.appleBooksSearchURL(term: "固定虚构书").kind,
            .appleBooksStore
        )
    }

    func testStrictHTTPSValidationRejectsDangerousSchemesAndMissingScheme() {
        let validator = StrictHTTPSLinkValidator()
        let rejected = [
            "http://example.invalid",
            "javascript:alert(1)",
            "data:text/plain,hello",
            "vbscript:msgbox(1)",
            "file:///private/tmp/fictional",
            "ibooks://fictional",
            "ssh://example.invalid",
            "telnet://example.invalid",
            "shell://example.invalid",
            "custom://example.invalid"
        ]
        for value in rejected {
            XCTAssertThrowsError(try validator.validate(value), value) {
                XCTAssertEqual($0 as? ExternalLinkValidationError, .rejectedScheme)
            }
        }
        XCTAssertThrowsError(try validator.validate("example.invalid/path")) {
            XCTAssertEqual($0 as? ExternalLinkValidationError, .missingScheme)
        }
    }

    func testStrictHTTPSValidationRejectsControlsCredentialsLimitsIDNAndBadEncoding() {
        let validator = StrictHTTPSLinkValidator()
        XCTAssertThrowsError(try validator.validate("https://example.invalid/a\nb")) {
            XCTAssertEqual($0 as? ExternalLinkValidationError, .controlCharacter)
        }
        XCTAssertThrowsError(try validator.validate("https://user:pass@example.invalid")) {
            XCTAssertEqual($0 as? ExternalLinkValidationError, .embeddedCredentials)
        }
        XCTAssertThrowsError(
            try validator.validate("https://example.invalid/" + String(repeating: "a", count: 2_100))
        ) {
            XCTAssertEqual($0 as? ExternalLinkValidationError, .tooLong)
        }
        for value in [
            "https://例子.invalid/path",
            "https://xn--fsqu00a.invalid/path"
        ] {
            XCTAssertThrowsError(try validator.validate(value), value) {
                XCTAssertEqual($0 as? ExternalLinkValidationError, .invalidHost)
            }
        }
        XCTAssertThrowsError(try validator.validate("https://example.invalid/%ZZ")) {
            XCTAssertEqual($0 as? ExternalLinkValidationError, .invalidEncoding)
        }
        XCTAssertThrowsError(try validator.validate(" https://example.invalid/path")) {
            XCTAssertEqual($0 as? ExternalLinkValidationError, .invalidEncoding)
        }
    }

    func testStrictHTTPSValidationRejectsPercentEncodedControlsInPathAndQuery() {
        let validator = StrictHTTPSLinkValidator()
        for encoded in ["%00", "%09", "%0A", "%0a", "%0D", "%0d%0A", "%7F", "%7f"] {
            for value in [
                "https://example.invalid/path/\(encoded)",
                "https://example.invalid/path?value=\(encoded)"
            ] {
                XCTAssertThrowsError(try validator.validate(value), value) {
                    XCTAssertEqual(
                        $0 as? ExternalLinkValidationError,
                        .controlCharacter
                    )
                }
            }
        }
    }

    func testStrictHTTPSValidationRejectsMalformedPortsAndAcceptsDeclaredRange() throws {
        let validator = StrictHTTPSLinkValidator()
        for value in [
            "https://example.invalid:/path",
            "https://example.invalid:not-a-port/path",
            "https://example.invalid:-1/path",
            "https://example.invalid:+443/path",
            "https://example.invalid:0/path",
            "https://example.invalid:65536/path"
        ] {
            XCTAssertThrowsError(try validator.validate(value), value) {
                XCTAssertEqual($0 as? ExternalLinkValidationError, .invalidPort)
            }
        }
        for port in [1, 443, 65_535] {
            let result = try validator.validate(
                "https://example.invalid:\(port)/合法路径?q=%E4%B8%AD"
            )
            XCTAssertEqual(result.safeHost, "example.invalid:\(port)")
        }
        XCTAssertNoThrow(
            try validator.validate("https://example.invalid/阅读?q=固定虚构内容")
        )
        XCTAssertNoThrow(
            try validator.validate("https://example.invalid/%E9%98%85%E8%AF%BB?q=%E4%B8%AD")
        )
    }

    func testAppleBooksSearchRejectsControlCharactersBeforeExternalDispatch() async throws {
        let book = try Book(
            draft: BookDraft(title: "《虚构\n搜索》", author: "林雾"),
            createdAt: FictionalLibraryFixtures.timestamp
        )
        let opener = SpyResourceOpener()
        let appleBooks = SpyAppleBooks(isAvailable: true)
        let coordinator = AppleBooksFallbackCoordinator(
            validator: StrictHTTPSLinkValidator(),
            opener: opener,
            appleBooks: appleBooks,
            clipboard: SpyClipboard()
        )

        let result = try await coordinator.perform(book: book, links: [])
        XCTAssertEqual(result, .launchApplication)
        XCTAssertTrue(opener.openedURLs.isEmpty)
        XCTAssertEqual(appleBooks.launchCount, 1)
    }

    func testWebLinkCRUDValidatesBeforeSaveAndAgainBeforeOpen() async throws {
        let repository = try BookRepository.inMemory()
        let book = try repository.create(FictionalLibraryFixtures.draft())
        let catalog = LibraryCatalogService(repository: repository)
        let opener = SpyResourceOpener()
        let store = ReadingEntryStore(catalog: catalog, opener: opener)
        store.load(bookID: book.id)
        await store.waitForPendingLoad()

        let rejectedSave = await store.saveWebLink(
            bookID: book.id,
            label: "危险入口",
            rawValue: "javascript:alert(1)"
        )
        XCTAssertFalse(rejectedSave)
        let linksAfterRejectedSave = try await catalog.externalLinks(for: book.id)
        XCTAssertEqual(linksAfterRejectedSave, [])

        let createdSave = await store.saveWebLink(
            bookID: book.id,
            label: "虚构入口",
            rawValue: "https://example.invalid/first"
        )
        XCTAssertTrue(createdSave)
        let created = try XCTUnwrap(store.webLinks.first)
        let updatedSave = await store.saveWebLink(
            id: created.id,
            bookID: book.id,
            label: "虚构入口（修订）",
            rawValue: "https://example.invalid/revised"
        )
        XCTAssertTrue(updatedSave)
        XCTAssertEqual(store.webLinks.first?.label, "虚构入口（修订）")

        let unsafe = try ExternalLink(
            id: created.id,
            bookID: book.id,
            kind: .web,
            value: "https://example.invalid/%0Anever-open"
        )
        await store.openWebLink(unsafe)
        XCTAssertTrue(opener.openedURLs.isEmpty)

        await store.deleteWebLink(try XCTUnwrap(store.webLinks.first))
        let linksAfterDelete = try await catalog.externalLinks(for: book.id)
        XCTAssertEqual(linksAfterDelete, [])
    }

    func testAppleBooksCapabilityStatesDoNotPromoteUnsupportedOrUnverified() {
        let appleBooks = SpyAppleBooks(isAvailable: false)
        let store = ReadingEntryStore(catalog: nil, appleBooks: appleBooks)
        let states = Dictionary(
            uniqueKeysWithValues: store.capabilityStates.map { ($0.capability, $0.status) }
        )
        XCTAssertEqual(states[.savedStoreHTTPS], .supported)
        XCTAssertEqual(states[.publicSearchHTTPS], .supported)
        XCTAssertEqual(states[.launchApplication], .unavailable)
        XCTAssertEqual(states[.privateLibraryItem], .unsupported)
        XCTAssertEqual(states[.customIBooksScheme], .unverified)
        XCTAssertEqual(appleBooks.launchCount, 0)
    }

    func testAppleBooksFallbackUsesSavedStoreThenSearchThenLaunch() async throws {
        let book = try Book(
            draft: BookDraft(title: "《虚构降级书》", author: "林雾"),
            createdAt: FictionalLibraryFixtures.timestamp
        )
        let storeLink = try ExternalLink(
            bookID: book.id,
            kind: .web,
            value: "https://books.apple.com/us/book/id123"
        )

        let savedOpener = SpyResourceOpener(outcomes: [.success])
        var coordinator = AppleBooksFallbackCoordinator(
            validator: StrictHTTPSLinkValidator(),
            opener: savedOpener,
            appleBooks: SpyAppleBooks(isAvailable: true),
            clipboard: SpyClipboard()
        )
        let savedResult = try await coordinator.perform(book: book, links: [storeLink])
        XCTAssertEqual(savedResult, .savedStore)
        XCTAssertEqual(savedOpener.openedURLs.count, 1)

        let searchOpener = SpyResourceOpener(outcomes: [.failure, .success])
        coordinator = AppleBooksFallbackCoordinator(
            validator: StrictHTTPSLinkValidator(),
            opener: searchOpener,
            appleBooks: SpyAppleBooks(isAvailable: true),
            clipboard: SpyClipboard()
        )
        let searchResult = try await coordinator.perform(book: book, links: [storeLink])
        XCTAssertEqual(searchResult, .publicSearch)
        XCTAssertEqual(searchOpener.openedURLs.last?.host, "books.apple.com")

        let launchOpener = SpyResourceOpener(outcomes: [.failure])
        let appleBooks = SpyAppleBooks(isAvailable: true)
        coordinator = AppleBooksFallbackCoordinator(
            validator: StrictHTTPSLinkValidator(),
            opener: launchOpener,
            appleBooks: appleBooks,
            clipboard: SpyClipboard()
        )
        let launchResult = try await coordinator.perform(book: book, links: [])
        XCTAssertEqual(launchResult, .launchApplication)
        XCTAssertEqual(appleBooks.launchCount, 1)
    }

    func testAppleBooksFallbackCopiesISBNThenTitleThenUsesSavedHTTPS() async throws {
        let isbnBook = try Book(
            draft: BookDraft(
                title: "《虚构 ISBN 降级书》",
                author: "林雾",
                isbn: "9780000000002"
            ),
            createdAt: FictionalLibraryFixtures.timestamp
        )
        let clipboard = SpyClipboard()
        var coordinator = AppleBooksFallbackCoordinator(
            validator: StrictHTTPSLinkValidator(),
            opener: SpyResourceOpener(outcomes: [.failure]),
            appleBooks: SpyAppleBooks(isAvailable: false),
            clipboard: clipboard
        )
        let isbnResult = try await coordinator.perform(book: isbnBook, links: [])
        XCTAssertEqual(isbnResult, .copiedISBN)
        XCTAssertEqual(clipboard.values, ["9780000000002"])

        let titleBook = try Book(
            draft: BookDraft(title: "《虚构标题降级书》", author: "林雾"),
            createdAt: FictionalLibraryFixtures.timestamp
        )
        let titleClipboard = SpyClipboard()
        coordinator = AppleBooksFallbackCoordinator(
            validator: StrictHTTPSLinkValidator(),
            opener: SpyResourceOpener(outcomes: [.failure]),
            appleBooks: SpyAppleBooks(isAvailable: false),
            clipboard: titleClipboard
        )
        let titleResult = try await coordinator.perform(book: titleBook, links: [])
        XCTAssertEqual(titleResult, .copiedTitle)
        XCTAssertEqual(titleClipboard.values, [titleBook.title])

        let custom = try ExternalLink(
            bookID: titleBook.id,
            kind: .web,
            value: "https://reader.example.invalid/fictional"
        )
        let finalOpener = SpyResourceOpener(outcomes: [.failure, .success])
        coordinator = AppleBooksFallbackCoordinator(
            validator: StrictHTTPSLinkValidator(),
            opener: finalOpener,
            appleBooks: SpyAppleBooks(isAvailable: false),
            clipboard: SpyClipboard(alwaysFails: true)
        )
        let customResult = try await coordinator.perform(book: titleBook, links: [custom])
        XCTAssertEqual(customResult, .savedHTTPS)
    }

    func testAppleBooksFallbackReportsAllUnavailableWithoutAutomaticActionAtInitialization() async throws {
        let book = try Book(
            draft: BookDraft(title: "《全部不可用》", author: "林雾"),
            createdAt: FictionalLibraryFixtures.timestamp
        )
        let opener = SpyResourceOpener(outcomes: [.failure])
        let appleBooks = SpyAppleBooks(isAvailable: false)
        let clipboard = SpyClipboard(alwaysFails: true)
        let coordinator = AppleBooksFallbackCoordinator(
            validator: StrictHTTPSLinkValidator(),
            opener: opener,
            appleBooks: appleBooks,
            clipboard: clipboard
        )

        XCTAssertTrue(opener.openedURLs.isEmpty)
        XCTAssertEqual(appleBooks.launchCount, 0)
        await XCTAssertThrowsErrorAsync(
            try await coordinator.perform(book: book, links: [])
        ) {
            XCTAssertEqual($0 as? ReadingEntrySystemError, .allFallbacksUnavailable)
        }
    }

    func testLocalFileSelectionCancellationNeverWritesDatabase() async throws {
        let repository = try BookRepository.inMemory()
        let book = try repository.create(FictionalLibraryFixtures.draft())
        let catalog = LibraryCatalogService(repository: repository)
        let store = ReadingEntryStore(
            catalog: catalog,
            fileSelector: SpyFileSelector(urls: [nil]),
            bookmarks: SpyBookmarks()
        )
        store.load(bookID: book.id)
        await store.waitForPendingLoad()

        await store.chooseLocalFile(for: book.id)

        let filesAfterCancellation = try await catalog.localFileReferences(for: book.id)
        XCTAssertEqual(filesAfterCancellation, [])
        XCTAssertEqual(store.statusMessage, "已取消选择；书库未更改。")
    }

    func testLocalFileBookmarkPersistsResolvesStaleUpdatesAndBalancesScope() async throws {
        let fixture = try temporaryFile(named: "虚构阅读文件.txt")
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let repository = try BookRepository.inMemory()
        let book = try repository.create(FictionalLibraryFixtures.draft())
        let catalog = LibraryCatalogService(repository: repository)
        let bookmarks = SpyBookmarks(resolvedURL: fixture)
        let opener = SpyResourceOpener()
        let store = ReadingEntryStore(
            catalog: catalog,
            opener: opener,
            fileSelector: SpyFileSelector(urls: [fixture]),
            bookmarks: bookmarks
        )
        store.load(bookID: book.id)
        await store.waitForPendingLoad()

        await store.chooseLocalFile(for: book.id)
        let created = try XCTUnwrap(store.localFiles.first)
        XCTAssertEqual(created.displayName, "虚构阅读文件.txt")
        bookmarks.isStale = true
        bookmarks.createdData = Data(
            count: LocalFileReference.maximumBookmarkBytes
        )

        await store.openLocalFile(created)

        let persistedFiles = try await catalog.localFileReferences(for: book.id)
        let updated = try XCTUnwrap(persistedFiles.first)
        XCTAssertEqual(
            updated.bookmarkData.count,
            LocalFileReference.maximumBookmarkBytes
        )
        XCTAssertEqual(bookmarks.startCount, 1)
        XCTAssertEqual(bookmarks.stopCount, 1)
        XCTAssertEqual(opener.openedURLs, [fixture])
    }

    func testLocalFileMissingPermissionCorruptionReselectAndRemoveAreSafe() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("first.txt")
        let replacement = directory.appendingPathComponent("replacement.txt")
        try Data("fictional".utf8).write(to: first)
        try Data("replacement".utf8).write(to: replacement)

        let repository = try BookRepository.inMemory()
        let book = try repository.create(FictionalLibraryFixtures.draft())
        let reference = try repository.addLocalFileReference(
            LocalFileReference(
                bookID: book.id,
                displayName: "first.txt",
                bookmarkData: Data("bookmark".utf8)
            )
        )
        let catalog = LibraryCatalogService(repository: repository)
        let bookmarks = SpyBookmarks(resolvedURL: first)
        bookmarks.resolveError = .bookmarkCorrupt
        let store = ReadingEntryStore(
            catalog: catalog,
            opener: SpyResourceOpener(),
            fileSelector: SpyFileSelector(urls: [replacement]),
            bookmarks: bookmarks
        )
        store.load(bookID: book.id)
        await store.waitForPendingLoad()

        await store.openLocalFile(reference)
        XCTAssertEqual(store.errorMessage, ReadingEntrySystemError.bookmarkCorrupt.message)

        bookmarks.resolveError = nil
        bookmarks.canStart = false
        await store.openLocalFile(reference)
        XCTAssertEqual(store.errorMessage, ReadingEntrySystemError.permissionDenied.message)
        XCTAssertEqual(bookmarks.stopCount, 0)

        bookmarks.canStart = true
        bookmarks.resolvedURL = directory.appendingPathComponent("deleted.txt")
        await store.openLocalFile(reference)
        XCTAssertEqual(store.errorMessage, ReadingEntrySystemError.fileUnavailable.message)
        XCTAssertEqual(bookmarks.startCount, 2)
        XCTAssertEqual(bookmarks.stopCount, 1)

        bookmarks.resolvedURL = replacement
        bookmarks.createdData = Data("replacement-bookmark".utf8)
        await store.reselectLocalFile(reference)
        let replaced = try XCTUnwrap(store.localFiles.first)
        XCTAssertEqual(replaced.displayName, "replacement.txt")
        XCTAssertEqual(replaced.bookmarkData, Data("replacement-bookmark".utf8))

        await store.deleteLocalFile(replaced)
        let filesAfterRemoval = try await catalog.localFileReferences(for: book.id)
        XCTAssertEqual(filesAfterRemoval, [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: replacement.path))
    }

    func testLoadGenerationKeepsLateBookAResultFromReplacingBookB() async throws {
        let bookA = UUID()
        let bookB = UUID()
        let linkA = try ExternalLink(
            bookID: bookA,
            kind: .web,
            value: "https://a.example.invalid/private-a"
        )
        let linkB = try ExternalLink(
            bookID: bookB,
            kind: .web,
            value: "https://b.example.invalid/private-b"
        )
        let fileA = try LocalFileReference(
            bookID: bookA,
            displayName: "A-虚构文件.pdf",
            bookmarkData: Data("a".utf8)
        )
        let fileB = try LocalFileReference(
            bookID: bookB,
            displayName: "B-虚构文件.pdf",
            bookmarkData: Data("b".utf8)
        )
        let loader = ControlledReadingEntryLoader(
            snapshots: [
                bookA: .init(bookID: bookA, webLinks: [linkA], localFiles: [fileA]),
                bookB: .init(bookID: bookB, webLinks: [linkB], localFiles: [fileB])
            ]
        )
        let store = ReadingEntryStore(catalog: nil, loader: loader)

        store.load(bookID: bookA)
        await loader.waitUntilRequested(bookA)
        store.load(bookID: bookB)
        XCTAssertEqual(store.currentBookID, bookB)
        XCTAssertEqual(store.webLinks, [])
        XCTAssertEqual(store.localFiles, [])
        await loader.waitUntilRequested(bookB)
        await loader.complete(bookB)
        await store.waitForPendingLoad()
        XCTAssertEqual(store.webLinks, [linkB])
        XCTAssertEqual(store.localFiles, [fileB])

        await loader.complete(bookA)
        await Task.yield()
        XCTAssertEqual(store.currentBookID, bookB)
        XCTAssertEqual(store.webLinks, [linkB])
        XCTAssertEqual(store.localFiles, [fileB])
        XCTAssertNil(store.errorMessage)
    }

    func testOldRowsCannotOpenModifyOrDeleteAnotherBooksEntries() async throws {
        let repository = try BookRepository.inMemory()
        let bookA = try repository.create(
            BookDraft(title: "《入口隔离甲》", author: "林雾")
        )
        let bookB = try repository.create(
            BookDraft(title: "《入口隔离乙》", author: "沈遥")
        )
        let linkA = try repository.addExternalLink(
            ExternalLink(
                bookID: bookA.id,
                kind: .web,
                value: "https://a.example.invalid/private-a"
            )
        )
        let linkB = try repository.addExternalLink(
            ExternalLink(
                bookID: bookB.id,
                kind: .web,
                value: "https://b.example.invalid/private-b"
            )
        )
        let fileA = try repository.addLocalFileReference(
            LocalFileReference(
                bookID: bookA.id,
                displayName: "A-虚构文件.pdf",
                bookmarkData: Data("a".utf8)
            )
        )
        let catalog = LibraryCatalogService(repository: repository)
        let opener = SpyResourceOpener()
        let store = ReadingEntryStore(catalog: catalog, opener: opener)
        store.load(bookID: bookA.id)
        await store.waitForPendingLoad()
        store.load(bookID: bookB.id)
        await store.waitForPendingLoad()

        await store.openWebLink(linkA)
        await store.deleteWebLink(linkA)
        await store.deleteLocalFile(fileA)
        let mismatchedSave = await store.saveWebLink(
            id: linkA.id,
            bookID: bookB.id,
            label: "错误上下文",
            rawValue: "https://changed.example.invalid"
        )
        XCTAssertFalse(mismatchedSave)

        let persistedLinksA = try await catalog.externalLinks(for: bookA.id)
        let persistedLinksB = try await catalog.externalLinks(for: bookB.id)
        let persistedFilesA = try await catalog.localFileReferences(for: bookA.id)
        XCTAssertTrue(opener.openedURLs.isEmpty)
        XCTAssertEqual(persistedLinksA.map(\.id), [linkA.id])
        XCTAssertEqual(persistedLinksA.map(\.value), [linkA.value])
        XCTAssertEqual(persistedLinksB.map(\.id), [linkB.id])
        XCTAssertEqual(persistedLinksB.map(\.value), [linkB.value])
        XCTAssertEqual(persistedFilesA.map(\.id), [fileA.id])
        XCTAssertEqual(persistedFilesA.map(\.bookmarkData), [fileA.bookmarkData])
        XCTAssertEqual(store.webLinks.map(\.id), [linkB.id])
        XCTAssertEqual(store.currentBookID, bookB.id)
        XCTAssertEqual(store.errorMessage, ReadingEntrySystemError.contextChanged.message)
    }

    func testUnavailableCatalogEndsLoadingWithSafeError() async {
        let store = ReadingEntryStore(catalog: nil)
        store.load(bookID: UUID())
        await store.waitForPendingLoad()

        XCTAssertFalse(store.isLoading)
        XCTAssertEqual(store.webLinks, [])
        XCTAssertEqual(store.localFiles, [])
        XCTAssertEqual(store.errorMessage, ReadingEntrySystemError.catalogUnavailable.message)
    }

    func testBookmarkBoundaryAndOversizeCreateOrReselectKeepOriginal() async throws {
        XCTAssertNoThrow(
            try LocalFileReference(
                bookID: UUID(),
                displayName: "边界虚构文件.pdf",
                bookmarkData: Data(count: LocalFileReference.maximumBookmarkBytes)
            )
        )
        XCTAssertThrowsError(
            try LocalFileReference(
                bookID: UUID(),
                displayName: "超限虚构文件.pdf",
                bookmarkData: Data(count: LocalFileReference.maximumBookmarkBytes + 1)
            )
        ) {
            XCTAssertEqual($0 as? DomainValidationError, .invalidBookmarkData)
        }

        let fixture = try temporaryFile(named: "替换虚构文件.pdf")
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let repository = try BookRepository.inMemory()
        let book = try repository.create(FictionalLibraryFixtures.draft())
        let original = try repository.addLocalFileReference(
            LocalFileReference(
                bookID: book.id,
                displayName: "原虚构文件.pdf",
                bookmarkData: Data("original".utf8)
            )
        )
        let catalog = LibraryCatalogService(repository: repository)
        let bookmarks = SpyBookmarks(resolvedURL: fixture)
        bookmarks.createdData = Data(count: LocalFileReference.maximumBookmarkBytes + 1)
        let store = ReadingEntryStore(
            catalog: catalog,
            fileSelector: SpyFileSelector(urls: [fixture, fixture]),
            bookmarks: bookmarks
        )
        store.load(bookID: book.id)
        await store.waitForPendingLoad()

        await store.chooseLocalFile(for: book.id)
        let filesAfterCreate = try await catalog.localFileReferences(for: book.id)
        XCTAssertEqual(filesAfterCreate.map(\.id), [original.id])
        XCTAssertEqual(filesAfterCreate.map(\.bookmarkData), [original.bookmarkData])
        await store.reselectLocalFile(original)
        let filesAfterReselect = try await catalog.localFileReferences(for: book.id)
        XCTAssertEqual(filesAfterReselect.map(\.id), [original.id])
        XCTAssertEqual(filesAfterReselect.map(\.bookmarkData), [original.bookmarkData])
        XCTAssertEqual(store.errorMessage, ReadingEntrySystemError.bookmarkTooLarge.message)
    }

    func testLocalFileDisplayNameRequiresCanonicalStoredForm() {
        for invalid in [
            " 前导空白.pdf",
            "尾随空白.pdf ",
            "控制\n字符.pdf",
            "目录/文件.pdf",
            "目录\\文件.pdf",
            ".",
            ".."
        ] {
            XCTAssertThrowsError(
                try LocalFileReference(
                    bookID: UUID(),
                    displayName: invalid,
                    bookmarkData: Data("opaque".utf8)
                ),
                invalid
            ) {
                XCTAssertEqual(
                    $0 as? DomainValidationError,
                    .invalidLocalFileDisplayName
                )
            }
        }
    }

    private func temporaryFile(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try Data("fixed fictional content".utf8).write(to: url)
        return url
    }
}

private actor ControlledReadingEntryLoader: ReadingEntryLoading {
    private let snapshots: [UUID: ReadingEntrySnapshot]
    private var requested: Set<UUID> = []
    private var continuations: [UUID: CheckedContinuation<ReadingEntrySnapshot, Error>] = [:]

    init(snapshots: [UUID: ReadingEntrySnapshot]) {
        self.snapshots = snapshots
    }

    func loadEntries(for bookID: UUID) async throws -> ReadingEntrySnapshot {
        requested.insert(bookID)
        return try await withCheckedThrowingContinuation { continuation in
            continuations[bookID] = continuation
        }
    }

    func waitUntilRequested(_ bookID: UUID) async {
        while !requested.contains(bookID) {
            await Task.yield()
        }
    }

    func complete(_ bookID: UUID) {
        guard let continuation = continuations.removeValue(forKey: bookID),
              let snapshot = snapshots[bookID]
        else { return }
        continuation.resume(returning: snapshot)
    }
}

@MainActor
private final class SpyResourceOpener: ExternalResourceOpening {
    enum Outcome { case success, failure }
    var outcomes: [Outcome]
    private(set) var openedURLs: [URL] = []

    init(outcomes: [Outcome] = [.success]) {
        self.outcomes = outcomes
    }

    func open(_ url: URL) async throws {
        openedURLs.append(url)
        let outcome = outcomes.isEmpty ? .success : outcomes.removeFirst()
        if outcome == .failure {
            throw ReadingEntrySystemError.externalOpenFailed
        }
    }
}

@MainActor
private final class SpyAppleBooks: AppleBooksIntegrating {
    let isApplicationAvailable: Bool
    var launchSucceeds = true
    private(set) var launchCount = 0

    init(isAvailable: Bool) {
        isApplicationAvailable = isAvailable
    }

    func launchApplication() async throws {
        launchCount += 1
        guard launchSucceeds else {
            throw ReadingEntrySystemError.appleBooksLaunchFailed
        }
    }
}

@MainActor
private final class SpyClipboard: ClipboardWriting {
    let alwaysFails: Bool
    private(set) var values: [String] = []

    init(alwaysFails: Bool = false) {
        self.alwaysFails = alwaysFails
    }

    func write(_ value: String) throws {
        if alwaysFails { throw ReadingEntrySystemError.clipboardWriteFailed }
        values.append(value)
    }
}

@MainActor
private final class SpyFileSelector: LocalFileSelecting {
    private var urls: [URL?]

    init(urls: [URL?]) {
        self.urls = urls
    }

    func selectFile() async -> URL? {
        urls.isEmpty ? nil : urls.removeFirst()
    }
}

private final class SpyBookmarks: SecurityScopedBookmarking {
    var resolvedURL: URL?
    var isStale = false
    var createdData = Data("fixed-bookmark".utf8)
    var resolveError: ReadingEntrySystemError?
    var canStart = true
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(resolvedURL: URL? = nil) {
        self.resolvedURL = resolvedURL
    }

    func createReadOnlyBookmark(for url: URL) throws -> Data {
        createdData
    }

    func resolve(_ data: Data) throws -> ResolvedSecurityScopedBookmark {
        if let resolveError { throw resolveError }
        guard let resolvedURL else { throw ReadingEntrySystemError.bookmarkCorrupt }
        return ResolvedSecurityScopedBookmark(url: resolvedURL, isStale: isStale)
    }

    func startAccessing(_ url: URL) -> Bool {
        startCount += 1
        return canStart
    }

    func stopAccessing(_ url: URL) {
        stopCount += 1
    }
}

@MainActor
private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("Expected async expression to throw")
    } catch {
        errorHandler(error)
    }
}
