import SpikeCore
import SwiftUI

public struct GraphCanvasView: View {
    @State private var fixture: GraphFixture
    @State private var viewport = GraphViewport()
    @State private var selectedNodeID: Int?
    @State private var draggedNodeID: Int?
    @State private var isPanning = false
    @State private var panStartTranslation = CGSize.zero

    public init(nodeCount: Int = 100) {
        _fixture = State(initialValue: .fictional(count: nodeCount))
    }

    public var body: some View {
        Canvas(rendersAsynchronously: true) { context, _ in
            context.translateBy(
                x: viewport.translation.width,
                y: viewport.translation.height
            )
            context.scaleBy(x: viewport.scale, y: viewport.scale)

            for edge in fixture.edges {
                guard
                    let source = fixture.nodes.first(
                        where: { $0.id == edge.source }
                    ),
                    let target = fixture.nodes.first(
                        where: { $0.id == edge.target }
                    )
                else {
                    continue
                }
                var path = Path()
                path.move(to: source.position)
                path.addLine(to: target.position)
                context.stroke(path, with: .color(.secondary), lineWidth: 1)
            }

            for node in fixture.nodes {
                let rect = CGRect(
                    x: node.position.x - 8,
                    y: node.position.y - 8,
                    width: 16,
                    height: 16
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(
                        selectedNodeID == node.id ? .accentColor : .blue
                    )
                )
            }
        }
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    viewport.scale = min(max(value.magnification, 0.5), 3)
                }
        )
        .onTapGesture { location in
            let graphPoint = CGPoint(
                x: (location.x - viewport.translation.width) / viewport.scale,
                y: (location.y - viewport.translation.height) / viewport.scale
            )
            selectedNodeID = fixture.hitTest(point: graphPoint)
        }
        .accessibilityRepresentation {
            List(fixture.nodes) { node in
                Button("虚构图书节点 \(node.id + 1)") {
                    selectedNodeID = node.id
                }
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if draggedNodeID == nil, !isPanning {
                    let startPoint = graphPoint(for: value.startLocation)
                    draggedNodeID = fixture.hitTest(point: startPoint)
                    if draggedNodeID == nil {
                        isPanning = true
                        panStartTranslation = viewport.translation
                    }
                }

                if let nodeID = draggedNodeID {
                    fixture.move(nodeID: nodeID, to: graphPoint(for: value.location))
                    selectedNodeID = nodeID
                } else {
                    viewport.translation = CGSize(
                        width: panStartTranslation.width + value.translation.width,
                        height: panStartTranslation.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                draggedNodeID = nil
                isPanning = false
            }
    }

    private func graphPoint(for location: CGPoint) -> CGPoint {
        CGPoint(
            x: (location.x - viewport.translation.width) / viewport.scale,
            y: (location.y - viewport.translation.height) / viewport.scale
        )
    }
}
