import AppKit
import SwiftUI
import XCTest
@testable import BookAtlas

final class AppNavigationTests: XCTestCase {
    func testNavigationContainsTheFiveExpectedSections() {
        XCTAssertEqual(
            AppSection.allCases,
            [.library, .collections, .tags, .graph, .settings]
        )
    }

    func testDefaultSelectionIsLibrary() {
        XCTAssertEqual(AppNavigationState().selection, .library)
    }

    func testTitlesAndIdentifiersAreStable() {
        let expected: [(AppSection, String, String)] = [
            (.library, "书库", "library"),
            (.collections, "书单", "collections"),
            (.tags, "标签", "tags"),
            (.graph, "书图", "graph"),
            (.settings, "设置", "settings")
        ]

        for (section, title, identifier) in expected {
            XCTAssertEqual(section.title, title)
            XCTAssertEqual(section.id, identifier)
            XCTAssertEqual(section.pageIdentifier, "page-title-\(identifier)")
        }
    }

    @MainActor
    func testShellLaysOutAtSmallAndLargeWindowSizes() {
        for size in [CGSize(width: 520, height: 360), CGSize(width: 1280, height: 800)] {
            let host = NSHostingView(
                rootView: AppShellView(selection: .constant(.library))
            )
            host.frame = CGRect(origin: .zero, size: size)
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            XCTAssertEqual(host.bounds.size, size)
        }
    }

    @MainActor
    func testShellSupportsLightAndDarkAppearances() {
        for appearanceName in [NSAppearance.Name.aqua, .darkAqua] {
            let host = NSHostingView(
                rootView: AppShellView(selection: .constant(.library))
            )
            host.appearance = NSAppearance(named: appearanceName)
            host.frame = CGRect(x: 0, y: 0, width: 720, height: 480)
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            XCTAssertEqual(host.effectiveAppearance.name, appearanceName)
        }
    }
}
