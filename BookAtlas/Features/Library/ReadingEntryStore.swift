import AppKit
import Foundation

enum IntegrationCapabilityStatus: String, Equatable, Sendable {
    case supported
    case unsupported
    case unavailable
    case unverified
}

enum AppleBooksCapability: String, CaseIterable, Sendable {
    case savedStoreHTTPS
    case publicSearchHTTPS
    case launchApplication
    case copyISBN
    case copyTitle
    case savedHTTPS
    case privateLibraryItem
    case customIBooksScheme
}

struct AppleBooksCapabilityState: Equatable, Sendable {
    let capability: AppleBooksCapability
    let status: IntegrationCapabilityStatus
}

enum ExternalDestinationKind: Equatable, Sendable {
    case appleBooksStore
    case web
}

struct ValidatedExternalLink: Equatable, Sendable {
    let url: URL
    let normalizedValue: String
    let safeHost: String
    let kind: ExternalDestinationKind
}

enum ExternalLinkValidationError: Error, Equatable {
    case empty
    case tooLong
    case controlCharacter
    case invalidEncoding
    case missingScheme
    case rejectedScheme
    case embeddedCredentials
    case invalidHost
    case invalidPort

    var message: String {
        switch self {
        case .empty:
            "请输入 HTTPS 阅读链接。"
        case .tooLong:
            "链接超过 2,048 字符的安全上限。"
        case .controlCharacter:
            "链接包含不可见控制字符，已拒绝。"
        case .invalidEncoding:
            "链接包含无效编码，无法安全解析。"
        case .missingScheme:
            "链接必须明确以 https:// 开头。"
        case .rejectedScheme:
            "仅允许 HTTPS；HTTP、file、ibooks 和其他自定义 Scheme 均不受支持。"
        case .embeddedCredentials:
            "链接不得包含用户名或密码。"
        case .invalidHost:
            "链接主机无法安全、确定地显示。Unicode、IDN 和混淆域名不被接受。"
        case .invalidPort:
            "链接端口无效。"
        }
    }
}

protocol ExternalLinkValidating: Sendable {
    func validate(_ rawValue: String) throws -> ValidatedExternalLink
    func appleBooksSearchURL(term: String) throws -> ValidatedExternalLink
}

struct StrictHTTPSLinkValidator: ExternalLinkValidating {
    static let maximumLength = 2_048

    func validate(_ rawValue: String) throws -> ValidatedExternalLink {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw ExternalLinkValidationError.empty }
        guard value == rawValue else {
            throw ExternalLinkValidationError.invalidEncoding
        }
        guard value.utf8.count <= Self.maximumLength else {
            throw ExternalLinkValidationError.tooLong
        }
        guard !value.unicodeScalars.contains(where: {
            CharacterSet.controlCharacters.contains($0)
        }) else {
            throw ExternalLinkValidationError.controlCharacter
        }
        guard !value.contains(where: \.isWhitespace) else {
            throw ExternalLinkValidationError.invalidEncoding
        }
        guard hasValidPercentEncoding(value) else {
            throw ExternalLinkValidationError.invalidEncoding
        }
        guard let components = URLComponents(string: value) else {
            throw ExternalLinkValidationError.invalidEncoding
        }
        guard let scheme = components.scheme else {
            throw ExternalLinkValidationError.missingScheme
        }
        guard scheme.lowercased() == "https" else {
            throw ExternalLinkValidationError.rejectedScheme
        }
        guard components.user == nil, components.password == nil else {
            throw ExternalLinkValidationError.embeddedCredentials
        }
        guard let host = components.host?.lowercased(),
              isSafeASCIIHost(host)
        else {
            throw ExternalLinkValidationError.invalidHost
        }
        if let port = components.port, !(1 ... 65_535).contains(port) {
            throw ExternalLinkValidationError.invalidPort
        }
        guard let url = components.url, url.scheme == "https" else {
            throw ExternalLinkValidationError.invalidEncoding
        }
        let safeHost = components.port.map { "\(host):\($0)" } ?? host
        return ValidatedExternalLink(
            url: url,
            normalizedValue: url.absoluteString,
            safeHost: safeHost,
            kind: host == "books.apple.com" ? .appleBooksStore : .web
        )
    }

    func appleBooksSearchURL(term: String) throws -> ValidatedExternalLink {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "books.apple.com"
        components.path = "/us/search"
        components.queryItems = [URLQueryItem(name: "term", value: term)]
        guard let value = components.string else {
            throw ExternalLinkValidationError.invalidEncoding
        }
        return try validate(value)
    }

    private func hasValidPercentEncoding(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        var index = 0
        while index < bytes.count {
            if bytes[index] == 0x25 {
                guard index + 2 < bytes.count,
                      bytes[index + 1].isHexDigit,
                      bytes[index + 2].isHexDigit
                else { return false }
                index += 3
            } else {
                index += 1
            }
        }
        return true
    }

    private func isSafeASCIIHost(_ host: String) -> Bool {
        guard !host.isEmpty,
              host.utf8.count <= 253,
              host.unicodeScalars.allSatisfy(\.isASCII),
              !host.contains("..")
        else { return false }
        return host.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { label in
            guard !label.isEmpty,
                  label.utf8.count <= 63,
                  !label.hasPrefix("-"),
                  !label.hasSuffix("-"),
                  !label.lowercased().hasPrefix("xn--")
            else { return false }
            return label.utf8.allSatisfy {
                ($0 >= 0x61 && $0 <= 0x7A)
                    || ($0 >= 0x30 && $0 <= 0x39)
                    || $0 == 0x2D
            }
        }
    }
}

private extension UInt8 {
    var isHexDigit: Bool {
        (self >= 0x30 && self <= 0x39)
            || (self >= 0x41 && self <= 0x46)
            || (self >= 0x61 && self <= 0x66)
    }
}

enum ReadingEntrySystemError: Error, Equatable {
    case externalOpenFailed
    case appleBooksUnavailable
    case appleBooksLaunchFailed
    case clipboardWriteFailed
    case selectionInvalid
    case bookmarkCreateFailed
    case bookmarkCorrupt
    case fileUnavailable
    case permissionDenied
    case allFallbacksUnavailable

    var message: String {
        switch self {
        case .externalOpenFailed:
            "系统未能打开所选阅读入口。链接内容未由 Book Atlas 请求。"
        case .appleBooksUnavailable:
            "此 Mac 上无法使用 Apple Books；可以改为复制书名或 ISBN。"
        case .appleBooksLaunchFailed:
            "Apple Books 未能启动；可以改为复制书名或 ISBN。"
        case .clipboardWriteFailed:
            "未能写入剪贴板。"
        case .selectionInvalid:
            "只能选择一个普通本地文件。"
        case .bookmarkCreateFailed:
            "未能保存该文件的只读授权。"
        case .bookmarkCorrupt:
            "本地文件授权已损坏，请重新选择文件。"
        case .fileUnavailable:
            "本地文件已移动或删除，请重新选择。"
        case .permissionDenied:
            "本地文件权限已撤销，请重新选择。"
        case .allFallbacksUnavailable:
            "当前没有可用的 Apple Books 或复制降级入口。"
        }
    }
}

@MainActor
protocol ExternalResourceOpening {
    func open(_ url: URL) async throws
}

@MainActor
protocol AppleBooksIntegrating {
    var isApplicationAvailable: Bool { get }
    func launchApplication() async throws
}

@MainActor
protocol ClipboardWriting {
    func write(_ value: String) throws
}

@MainActor
protocol LocalFileSelecting {
    func selectFile() async -> URL?
}

struct ResolvedSecurityScopedBookmark: Sendable {
    let url: URL
    let isStale: Bool
}

protocol SecurityScopedBookmarking {
    func createReadOnlyBookmark(for url: URL) throws -> Data
    func resolve(_ data: Data) throws -> ResolvedSecurityScopedBookmark
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

@MainActor
struct SystemExternalResourceOpener: ExternalResourceOpening {
    func open(_ url: URL) async throws {
        guard NSWorkspace.shared.open(url) else {
            throw ReadingEntrySystemError.externalOpenFailed
        }
    }
}

@MainActor
struct SystemAppleBooksIntegration: AppleBooksIntegrating {
    private let bundleIdentifier = "com.apple.iBooksX"

    var isApplicationAvailable: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    func launchApplication() async throws {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else {
            throw ReadingEntrySystemError.appleBooksUnavailable
        }
        try await withCheckedThrowingContinuation { continuation in
            NSWorkspace.shared.openApplication(
                at: applicationURL,
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, error in
                if error == nil {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ReadingEntrySystemError.appleBooksLaunchFailed)
                }
            }
        }
    }
}

@MainActor
struct SystemClipboardWriter: ClipboardWriting {
    func write(_ value: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(value, forType: .string) else {
            throw ReadingEntrySystemError.clipboardWriteFailed
        }
    }
}

@MainActor
struct SystemLocalFileSelector: LocalFileSelecting {
    func selectFile() async -> URL? {
        await withCheckedContinuation { continuation in
            let panel = NSOpenPanel()
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowsMultipleSelection = false
            panel.resolvesAliases = true
            panel.begin { response in
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }
}

struct SystemSecurityScopedBookmarkService: SecurityScopedBookmarking {
    func createReadOnlyBookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                relativeTo: nil
            )
        } catch {
            throw ReadingEntrySystemError.bookmarkCreateFailed
        }
    }

    func resolve(_ data: Data) throws -> ResolvedSecurityScopedBookmark {
        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            return ResolvedSecurityScopedBookmark(url: url, isStale: stale)
        } catch {
            throw ReadingEntrySystemError.bookmarkCorrupt
        }
    }

    func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

@MainActor
struct FictionalUITestResourceOpener: ExternalResourceOpening {
    func open(_ url: URL) async throws {}
}

@MainActor
struct FictionalUITestAppleBooksIntegration: AppleBooksIntegrating {
    let isApplicationAvailable = false

    func launchApplication() async throws {
        throw ReadingEntrySystemError.appleBooksUnavailable
    }
}

@MainActor
struct FictionalUITestClipboardWriter: ClipboardWriting {
    func write(_ value: String) throws {}
}

@MainActor
struct FictionalUITestFileSelector: LocalFileSelecting {
    func selectFile() async -> URL? { nil }
}

struct FictionalUITestBookmarkService: SecurityScopedBookmarking {
    func createReadOnlyBookmark(for url: URL) throws -> Data {
        Data("fixed-fictional-ui-bookmark".utf8)
    }

    func resolve(_ data: Data) throws -> ResolvedSecurityScopedBookmark {
        throw ReadingEntrySystemError.bookmarkCorrupt
    }

    func startAccessing(_ url: URL) -> Bool { false }

    func stopAccessing(_ url: URL) {}
}

enum AppleBooksFallbackStep: Equatable, Sendable {
    case savedStore
    case publicSearch
    case launchApplication
    case copiedISBN
    case copiedTitle
    case savedHTTPS

    var message: String {
        switch self {
        case .savedStore: "已将保存的 Apple Books 商店页面交给系统打开。"
        case .publicSearch: "已将公开 Apple Books 搜索交给系统；搜索词可能由外部应用处理。"
        case .launchApplication: "已启动 Apple Books；未尝试定位私人资料库项目。"
        case .copiedISBN: "Apple Books 入口不可用，已复制 ISBN。"
        case .copiedTitle: "Apple Books 入口不可用，已复制书名。"
        case .savedHTTPS: "已改用其他保存的 HTTPS 阅读入口。"
        }
    }
}

@MainActor
struct AppleBooksFallbackCoordinator {
    let validator: any ExternalLinkValidating
    let opener: any ExternalResourceOpening
    let appleBooks: any AppleBooksIntegrating
    let clipboard: any ClipboardWriting

    func capabilityStates() -> [AppleBooksCapabilityState] {
        [
            .init(capability: .savedStoreHTTPS, status: .supported),
            .init(capability: .publicSearchHTTPS, status: .supported),
            .init(
                capability: .launchApplication,
                status: appleBooks.isApplicationAvailable ? .supported : .unavailable
            ),
            .init(capability: .copyISBN, status: .supported),
            .init(capability: .copyTitle, status: .supported),
            .init(capability: .savedHTTPS, status: .supported),
            .init(capability: .privateLibraryItem, status: .unsupported),
            .init(capability: .customIBooksScheme, status: .unverified)
        ]
    }

    func perform(book: Book, links: [ExternalLink]) async throws -> AppleBooksFallbackStep {
        let validated = links.compactMap { link -> (ExternalLink, ValidatedExternalLink)? in
            guard link.kind == .web,
                  let result = try? validator.validate(link.value)
            else { return nil }
            return (link, result)
        }
        for (_, link) in validated where link.kind == .appleBooksStore {
            if (try? await opener.open(link.url)) != nil {
                return .savedStore
            }
        }

        let searchTerm = book.isbn ?? book.title
        if let search = try? validator.appleBooksSearchURL(term: searchTerm),
           (try? await opener.open(search.url)) != nil
        {
            return .publicSearch
        }

        if appleBooks.isApplicationAvailable,
           (try? await appleBooks.launchApplication()) != nil
        {
            return .launchApplication
        }

        if let isbn = book.isbn, (try? clipboard.write(isbn)) != nil {
            return .copiedISBN
        }
        if (try? clipboard.write(book.title)) != nil {
            return .copiedTitle
        }
        for (_, link) in validated where link.kind == .web {
            if (try? await opener.open(link.url)) != nil {
                return .savedHTTPS
            }
        }
        throw ReadingEntrySystemError.allFallbacksUnavailable
    }
}

@MainActor
final class ReadingEntryStore: ObservableObject {
    @Published private(set) var webLinks: [ExternalLink] = []
    @Published private(set) var localFiles: [LocalFileReference] = []
    @Published private(set) var isLoading = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?

    let validator: any ExternalLinkValidating
    private let catalog: (any LibraryCataloging)?
    private let opener: any ExternalResourceOpening
    private let appleBooks: any AppleBooksIntegrating
    private let clipboard: any ClipboardWriting
    private let fileSelector: any LocalFileSelecting
    private let bookmarks: any SecurityScopedBookmarking
    private var currentBookID: UUID?
    private var task: Task<Void, Never>?

    init(
        catalog: (any LibraryCataloging)?,
        validator: any ExternalLinkValidating = StrictHTTPSLinkValidator(),
        opener: any ExternalResourceOpening = SystemExternalResourceOpener(),
        appleBooks: any AppleBooksIntegrating = SystemAppleBooksIntegration(),
        clipboard: any ClipboardWriting = SystemClipboardWriter(),
        fileSelector: any LocalFileSelecting = SystemLocalFileSelector(),
        bookmarks: any SecurityScopedBookmarking = SystemSecurityScopedBookmarkService()
    ) {
        self.catalog = catalog
        self.validator = validator
        self.opener = opener
        self.appleBooks = appleBooks
        self.clipboard = clipboard
        self.fileSelector = fileSelector
        self.bookmarks = bookmarks
    }

    deinit {
        task?.cancel()
    }

    var capabilityStates: [AppleBooksCapabilityState] {
        AppleBooksFallbackCoordinator(
            validator: validator,
            opener: opener,
            appleBooks: appleBooks,
            clipboard: clipboard
        ).capabilityStates()
    }

    func load(bookID: UUID) {
        currentBookID = bookID
        task?.cancel()
        isLoading = true
        task = Task { @MainActor [weak self] in
            guard let self, let catalog else { return }
            do {
                async let links = catalog.externalLinks(for: bookID)
                async let files = catalog.localFileReferences(for: bookID)
                self.webLinks = try await links.filter { $0.kind == .web }
                self.localFiles = try await files
                self.errorMessage = nil
            } catch {
                self.webLinks = []
                self.localFiles = []
                self.errorMessage = "无法读取阅读入口；书籍记录未被更改。"
            }
            self.isLoading = false
        }
    }

    func saveWebLink(
        id: UUID? = nil,
        bookID: UUID,
        label: String?,
        rawValue: String,
        now: Date = Date()
    ) async -> Bool {
        guard let catalog else { return false }
        do {
            let validated = try validator.validate(rawValue)
            if let id, let existing = webLinks.first(where: { $0.id == id }) {
                let updated = try ExternalLink(
                    id: existing.id,
                    bookID: existing.bookID,
                    kind: .web,
                    label: label,
                    value: validated.normalizedValue,
                    createdAt: existing.createdAt,
                    updatedAt: now
                )
                try await catalog.updateExternalLink(updated)
            } else {
                _ = try await catalog.addExternalLink(
                    ExternalLink(
                        bookID: bookID,
                        kind: .web,
                        label: label,
                        value: validated.normalizedValue,
                        createdAt: now
                    )
                )
            }
            load(bookID: bookID)
            await task?.value
            statusMessage = "阅读链接已保存。"
            return true
        } catch let error as ExternalLinkValidationError {
            errorMessage = error.message
        } catch {
            errorMessage = "未能保存阅读链接；现有入口未被更改。"
        }
        return false
    }

    func deleteWebLink(_ link: ExternalLink) async {
        guard let catalog else { return }
        do {
            try await catalog.deleteExternalLink(link.id)
            load(bookID: link.bookID)
            await task?.value
            statusMessage = "阅读链接已移除。"
        } catch {
            errorMessage = "未能移除阅读链接；现有入口未被更改。"
        }
    }

    func openWebLink(_ link: ExternalLink) async {
        do {
            let validated = try validator.validate(link.value)
            try await opener.open(validated.url)
            statusMessage = "已将 \(validated.safeHost) 交给系统打开。"
            errorMessage = nil
        } catch let error as ExternalLinkValidationError {
            errorMessage = error.message
        } catch {
            errorMessage = ReadingEntrySystemError.externalOpenFailed.message
        }
    }

    func copyTitle(_ title: String) {
        copy(title, success: "已复制书名。")
    }

    func copyISBN(_ isbn: String) {
        copy(isbn, success: "已复制 ISBN。")
    }

    func performAppleBooksFallback(for book: Book) async {
        do {
            let step = try await AppleBooksFallbackCoordinator(
                validator: validator,
                opener: opener,
                appleBooks: appleBooks,
                clipboard: clipboard
            ).perform(book: book, links: webLinks)
            statusMessage = step.message
            errorMessage = nil
        } catch let error as ReadingEntrySystemError {
            errorMessage = error.message
        } catch {
            errorMessage = ReadingEntrySystemError.allFallbacksUnavailable.message
        }
    }

    func chooseLocalFile(for bookID: UUID, now: Date = Date()) async {
        guard let catalog else { return }
        guard let url = await fileSelector.selectFile() else {
            statusMessage = "已取消选择；书库未更改。"
            return
        }
        do {
            try validateSelectedFile(url)
            let data = try bookmarks.createReadOnlyBookmark(for: url)
            _ = try await catalog.addLocalFileReference(
                LocalFileReference(
                    bookID: bookID,
                    displayName: safeDisplayName(url),
                    bookmarkData: data,
                    createdAt: now
                )
            )
            load(bookID: bookID)
            await task?.value
            statusMessage = "本地文件引用已保存；Book Atlas 未读取文件正文。"
        } catch let error as ReadingEntrySystemError {
            errorMessage = error.message
        } catch {
            errorMessage = ReadingEntrySystemError.bookmarkCreateFailed.message
        }
    }

    func openLocalFile(_ reference: LocalFileReference, now: Date = Date()) async {
        guard let catalog else { return }
        do {
            let resolved = try bookmarks.resolve(reference.bookmarkData)
            guard bookmarks.startAccessing(resolved.url) else {
                throw ReadingEntrySystemError.permissionDenied
            }
            defer { bookmarks.stopAccessing(resolved.url) }
            try validateSelectedFile(resolved.url)
            if resolved.isStale {
                let refreshed = try LocalFileReference(
                    id: reference.id,
                    bookID: reference.bookID,
                    displayName: safeDisplayName(resolved.url),
                    bookmarkData: bookmarks.createReadOnlyBookmark(for: resolved.url),
                    createdAt: reference.createdAt,
                    updatedAt: now
                )
                try await catalog.updateLocalFileReference(refreshed)
            }
            try await opener.open(resolved.url)
            statusMessage = resolved.isStale
                ? "文件授权已安全更新并交给系统打开。"
                : "本地文件已交给系统打开。"
            if resolved.isStale {
                load(bookID: reference.bookID)
            }
        } catch let error as ReadingEntrySystemError {
            errorMessage = error.message
        } catch {
            errorMessage = ReadingEntrySystemError.fileUnavailable.message
        }
    }

    func reselectLocalFile(_ reference: LocalFileReference, now: Date = Date()) async {
        guard let catalog else { return }
        guard let url = await fileSelector.selectFile() else {
            statusMessage = "已取消重新选择；原引用保持不变。"
            return
        }
        do {
            try validateSelectedFile(url)
            let updated = try LocalFileReference(
                id: reference.id,
                bookID: reference.bookID,
                displayName: safeDisplayName(url),
                bookmarkData: bookmarks.createReadOnlyBookmark(for: url),
                createdAt: reference.createdAt,
                updatedAt: now
            )
            try await catalog.updateLocalFileReference(updated)
            load(bookID: reference.bookID)
            await task?.value
            statusMessage = "本地文件授权已更新。"
        } catch let error as ReadingEntrySystemError {
            errorMessage = error.message
        } catch {
            errorMessage = ReadingEntrySystemError.bookmarkCreateFailed.message
        }
    }

    func deleteLocalFile(_ reference: LocalFileReference) async {
        guard let catalog else { return }
        do {
            try await catalog.deleteLocalFileReference(reference.id)
            load(bookID: reference.bookID)
            await task?.value
            statusMessage = "本地文件引用已移除；文件本身未被删除。"
        } catch {
            errorMessage = "未能移除本地文件引用；文件本身未被修改。"
        }
    }

    func dismissMessage() {
        statusMessage = nil
        errorMessage = nil
    }

    private func copy(_ value: String, success: String) {
        do {
            try clipboard.write(value)
            statusMessage = success
            errorMessage = nil
        } catch {
            errorMessage = ReadingEntrySystemError.clipboardWriteFailed.message
        }
    }

    private func validateSelectedFile(_ url: URL) throws {
        guard url.isFileURL else { throw ReadingEntrySystemError.selectionInvalid }
        let values = try? url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isReadableKey]
        )
        guard values?.isRegularFile == true,
              values?.isSymbolicLink != true
        else { throw ReadingEntrySystemError.fileUnavailable }
        guard values?.isReadable != false else {
            throw ReadingEntrySystemError.permissionDenied
        }
    }

    private func safeDisplayName(_ url: URL) -> String {
        let name = url.lastPathComponent
            .components(separatedBy: .controlCharacters)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String((name.isEmpty ? "所选本地文件" : name).prefix(512))
    }
}
