import AppKit
import Foundation

public enum ExternalLinkDecision: Equatable, Sendable {
    case allowedHTTPS(URL)
    case allowedAppleBooksStore(URL)
    case rejected
}

public enum ExternalLinkPolicy {
    public static func decision(for rawValue: String) -> ExternalLinkDecision {
        guard
            let url = URL(string: rawValue),
            url.scheme?.lowercased() == "https",
            url.host != nil
        else {
            return .rejected
        }
        if url.host?.lowercased() == "books.apple.com" {
            return .allowedAppleBooksStore(url)
        }
        return .allowedHTTPS(url)
    }

    public static func experimentalSearchURL(term: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "books.apple.com"
        components.path = "/us/search"
        components.queryItems = [
            URLQueryItem(name: "term", value: term)
        ]
        return components.url
    }

    public static func booksApplicationURL() -> URL? {
        NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.iBooksX"
        )
    }

    @discardableResult
    public static func open(
        _ decision: ExternalLinkDecision,
        userInitiated: Bool
    ) -> Bool {
        guard userInitiated else {
            return false
        }
        switch decision {
        case .allowedHTTPS(let url), .allowedAppleBooksStore(let url):
            return NSWorkspace.shared.open(url)
        case .rejected:
            return false
        }
    }
}

