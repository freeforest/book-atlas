import Foundation
import SpikeCore
import SwiftDataCandidate
import XCTest

final class IntegrationPolicyTests: XCTestCase {
    @MainActor
    func testSwiftDataInMemoryRelationship() throws {
        XCTAssertEqual(try SwiftDataProbe.exerciseInMemory(), 1)
    }

    func testExternalURLAllowlist() {
        XCTAssertEqual(
            ExternalLinkPolicy.decision(for: "not a url"),
            .rejected
        )
        XCTAssertEqual(
            ExternalLinkPolicy.decision(for: "file:///tmp/private"),
            .rejected
        )
        XCTAssertEqual(
            ExternalLinkPolicy.decision(for: "ibooks://fictional"),
            .rejected
        )
        guard
            case .allowedHTTPS = ExternalLinkPolicy.decision(
                for: "https://example.invalid/fiction"
            ),
            case .allowedAppleBooksStore = ExternalLinkPolicy.decision(
                for: "https://books.apple.com/us/book/id000000000"
            )
        else {
            return XCTFail("Expected allowlisted HTTPS decisions")
        }
        XCTAssertFalse(
            ExternalLinkPolicy.open(.rejected, userInitiated: true)
        )
    }

    func testAppleBooksApplicationCanBeLocated() {
        XCTAssertNotNil(ExternalLinkPolicy.booksApplicationURL())
    }

    func testBookmarkCreationResolutionAndMissingFileFailure() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: folder) }

        let file = folder.appendingPathComponent("fictional.txt")
        try Data("虚构内容".utf8).write(to: file)
        let bookmark = try BookmarkService.makeReadOnlyBookmark(for: file)
        let resolved = try BookmarkService.resolve(bookmark)
        let contents = try BookmarkService.withAccess(to: resolved) {
            try Data(contentsOf: $0)
        }
        XCTAssertEqual(contents, Data("虚构内容".utf8))

        try FileManager.default.removeItem(at: file)
        XCTAssertThrowsError(
            try BookmarkService.withAccess(
                to: BookmarkService.resolve(bookmark)
            ) {
                try Data(contentsOf: $0)
            }
        )
    }
}

