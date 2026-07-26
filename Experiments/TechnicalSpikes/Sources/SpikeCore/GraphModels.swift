import CoreGraphics
import Darwin.Mach
import Foundation

public struct GraphNode: Identifiable, Equatable, Sendable {
    public let id: Int
    public var position: CGPoint

    public init(id: Int, position: CGPoint) {
        self.id = id
        self.position = position
    }
}

public struct GraphEdge: Equatable, Sendable {
    public let source: Int
    public let target: Int

    public init(source: Int, target: Int) {
        self.source = source
        self.target = target
    }
}

public struct GraphFixture: Sendable {
    public var nodes: [GraphNode]
    public var edges: [GraphEdge]

    public init(nodes: [GraphNode], edges: [GraphEdge]) {
        self.nodes = nodes
        self.edges = edges
    }

    public static func fictional(count: Int) -> GraphFixture {
        let columns = max(1, Int(Double(count).squareRoot().rounded(.up)))
        let nodes = (0..<count).map { index in
            GraphNode(
                id: index,
                position: CGPoint(
                    x: Double(index % columns) * 72 + 36,
                    y: Double(index / columns) * 58 + 36
                )
            )
        }
        let edges = (1..<count).map { index in
            GraphEdge(source: index - 1, target: index)
        }
        return GraphFixture(nodes: nodes, edges: edges)
    }

    public func hitTest(point: CGPoint, radius: CGFloat = 18) -> Int? {
        nodes.first { node in
            hypot(
                node.position.x - point.x,
                node.position.y - point.y
            ) <= radius
        }?.id
    }

    public mutating func move(nodeID: Int, to point: CGPoint) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else {
            return
        }
        nodes[index].position = point
    }
}

public struct GraphViewport: Equatable, Sendable {
    public var scale: CGFloat
    public var translation: CGSize

    public init(scale: CGFloat = 1, translation: CGSize = .zero) {
        self.scale = scale
        self.translation = translation
    }

    public func screenPoint(for graphPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: graphPoint.x * scale + translation.width,
            y: graphPoint.y * scale + translation.height
        )
    }
}

public enum ProcessMemory {
    public static func residentBytes() -> UInt64 {
        var information = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size
                / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &information) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        return result == KERN_SUCCESS ? UInt64(information.resident_size) : 0
    }
}

