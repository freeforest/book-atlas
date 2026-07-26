import Foundation

public struct ResolvedBookmark: Sendable {
    public let url: URL
    public let isStale: Bool

    public init(url: URL, isStale: Bool) {
        self.url = url
        self.isStale = isStale
    }
}

public enum BookmarkService {
    public static func makeReadOnlyBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [
                .withSecurityScope,
                .securityScopeAllowOnlyReadAccess
            ],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    public static func resolve(_ data: Data) throws -> ResolvedBookmark {
        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        return ResolvedBookmark(url: url, isStale: stale)
    }

    public static func withAccess<T>(
        to resolved: ResolvedBookmark,
        operation: (URL) throws -> T
    ) throws -> T {
        let didStart = resolved.url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                resolved.url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation(resolved.url)
    }
}

