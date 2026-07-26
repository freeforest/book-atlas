import AppKit
import CoreGraphics
import SpikeCore
import SpikeUI
import SwiftUI
import XCTest

final class GraphTests: XCTestCase {
    func testFixturesAndHitTestingAtRequiredSizes() {
        for count in [50, 100, 250] {
            var fixture = GraphFixture.fictional(count: count)
            XCTAssertEqual(fixture.nodes.count, count)
            XCTAssertEqual(fixture.edges.count, count - 1)
            XCTAssertEqual(
                fixture.hitTest(point: fixture.nodes[0].position),
                fixture.nodes[0].id
            )
            fixture.move(nodeID: 0, to: CGPoint(x: 500, y: 300))
            XCTAssertEqual(fixture.nodes[0].position, CGPoint(x: 500, y: 300))
        }
    }

    func testPanAndZoomTransform() {
        let viewport = GraphViewport(
            scale: 2,
            translation: CGSize(width: 10, height: 20)
        )
        XCTAssertEqual(
            viewport.screenPoint(for: CGPoint(x: 5, y: 8)),
            CGPoint(x: 20, y: 36)
        )
    }

    func testNoRelationshipState() {
        let fixture = GraphFixture(
            nodes: [GraphNode(id: 0, position: .zero)],
            edges: []
        )
        XCTAssertTrue(fixture.edges.isEmpty)
    }

    @MainActor
    func testCanvasCanBeHostedAndLaidOut() {
        let host = NSHostingView(rootView: GraphCanvasView(nodeCount: 50))
        host.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        XCTAssertEqual(host.bounds.size, CGSize(width: 640, height: 480))
    }
}
