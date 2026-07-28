import CoreGraphics
import Foundation

enum GraphRelationType: String, CaseIterable, Codable, Sendable {
    case sameAuthor
    case sharedTag
    case sameCollection
    case sameSource
    case manual

    var displayTitle: String {
        switch self {
        case .sameAuthor: "同作者"
        case .sharedTag: "共同标签"
        case .sameCollection: "同一书单"
        case .sameSource: "同一来源"
        case .manual: "手动关系"
        }
    }
}

enum GraphDepth: Int, CaseIterable, Sendable {
    case direct = 1
    case secondDegree = 2

    var displayTitle: String {
        switch self {
        case .direct: "一层"
        case .secondDegree: "两层"
        }
    }
}

struct GraphBuildOptions: Equatable, Sendable {
    static let defaultMaximumNodes = 80
    static let defaultMaximumEdges = 200
    static let hardMaximumNodes = 250
    static let hardMaximumEdges = 500

    var depth: GraphDepth
    var relationTypes: Set<GraphRelationType>
    var maximumNodes: Int
    var maximumEdges: Int

    init(
        depth: GraphDepth = .direct,
        relationTypes: Set<GraphRelationType> = Set(GraphRelationType.allCases),
        maximumNodes: Int = defaultMaximumNodes,
        maximumEdges: Int = defaultMaximumEdges
    ) {
        self.depth = depth
        self.relationTypes = relationTypes
        self.maximumNodes = min(max(maximumNodes, 1), Self.hardMaximumNodes)
        self.maximumEdges = min(max(maximumEdges, 0), Self.hardMaximumEdges)
    }

    var candidateLimitPerExpansion: Int {
        min(max(maximumNodes * 2, 20), Self.hardMaximumNodes)
    }
}

enum GraphManualDirection: String, Codable, Sendable {
    case firstToSecond
    case secondToFirst
}

enum GraphRelationEvidence: Hashable, Sendable {
    case sameAuthor(author: String)
    case sharedTag(id: UUID, name: String)
    case sameCollection(id: UUID, name: String)
    case sameSource(id: UUID, name: String)
    case manual(
        relationID: UUID,
        kind: ManualRelationKind,
        direction: GraphManualDirection,
        sourceBookID: UUID,
        targetBookID: UUID,
        hasNote: Bool
    )

    var relationType: GraphRelationType {
        switch self {
        case .sameAuthor: .sameAuthor
        case .sharedTag: .sharedTag
        case .sameCollection: .sameCollection
        case .sameSource: .sameSource
        case .manual: .manual
        }
    }

    var sortKey: String {
        switch self {
        case let .sameAuthor(author):
            "0|\(author)"
        case let .sharedTag(id, name):
            "1|\(name)|\(id.uuidString)"
        case let .sameCollection(id, name):
            "2|\(name)|\(id.uuidString)"
        case let .sameSource(id, name):
            "3|\(name)|\(id.uuidString)"
        case let .manual(relationID, kind, direction, source, target, hasNote):
            "4|\(kind.rawValue)|\(direction.rawValue)|\(source.uuidString)|\(target.uuidString)|\(hasNote)|\(relationID.uuidString)"
        }
    }

    var explanation: String {
        switch self {
        case let .sameAuthor(author):
            return "同作者：\(author)"
        case let .sharedTag(_, name):
            return "共同标签：\(name)"
        case let .sameCollection(_, name):
            return "同一书单：\(name)"
        case let .sameSource(_, name):
            return "同一来源：\(name)"
        case let .manual(_, kind, direction, _, _, hasNote):
            let directionText = direction == .firstToSecond ? "第一端指向第二端" : "第二端指向第一端"
            return "手动关系：\(kind.graphDisplayTitle)，\(directionText)\(hasNote ? "，含备注" : "")"
        }
    }
}

extension ManualRelationKind {
    var graphDisplayTitle: String {
        switch self {
        case .related: "相关"
        case .inspiredBy: "受其启发"
        case .respondsTo: "回应"
        case .companion: "伴读"
        }
    }
}

struct GraphNode: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String?
    let isCenter: Bool
    var isSelected: Bool
    let distance: Int
}

struct GraphEdgeID: Hashable, Comparable, Sendable {
    let firstBookID: UUID
    let secondBookID: UUID

    init(_ first: UUID, _ second: UUID) {
        if first.uuidString < second.uuidString {
            firstBookID = first
            secondBookID = second
        } else {
            firstBookID = second
            secondBookID = first
        }
    }

    static func < (lhs: GraphEdgeID, rhs: GraphEdgeID) -> Bool {
        if lhs.firstBookID.uuidString != rhs.firstBookID.uuidString {
            return lhs.firstBookID.uuidString < rhs.firstBookID.uuidString
        }
        return lhs.secondBookID.uuidString < rhs.secondBookID.uuidString
    }
}

struct GraphEdge: Identifiable, Equatable, Sendable {
    let id: GraphEdgeID
    let evidence: [GraphRelationEvidence]
    let weight: Int

    var relationTypes: Set<GraphRelationType> {
        Set(evidence.map(\.relationType))
    }
}

struct GraphSnapshot: Equatable, Sendable {
    let centerBookID: UUID
    var nodes: [GraphNode]
    let edges: [GraphEdge]
    let nodeLimitReached: Bool
    let edgeLimitReached: Bool
    let sourceCandidatesWereTruncated: Bool

    var isLimited: Bool {
        nodeLimitReached || edgeLimitReached || sourceCandidatesWereTruncated
    }

    var selectedNode: GraphNode? {
        nodes.first(where: \.isSelected)
    }

    func directNeighborIDs(of bookID: UUID) -> Set<UUID> {
        var result: Set<UUID> = []
        for edge in edges {
            if edge.id.firstBookID == bookID {
                result.insert(edge.id.secondBookID)
            } else if edge.id.secondBookID == bookID {
                result.insert(edge.id.firstBookID)
            }
        }
        return result
    }

    func edge(between first: UUID, and second: UUID) -> GraphEdge? {
        let id = GraphEdgeID(first, second)
        return edges.first { $0.id == id }
    }
}

struct GraphNeighbor: Equatable, Sendable {
    let book: Book
    let evidence: [GraphRelationEvidence]
}

struct GraphNeighborBatch: Equatable, Sendable {
    let neighbors: [GraphNeighbor]
    let wasTruncated: Bool
}

enum GraphBuildError: Error, Equatable, Sendable {
    case centerBookNotFound
    case cancelled
    case invalidRelationshipData
    case databaseUnavailable
}

struct GraphBuildCancellation: Sendable {
    let isCancelled: @Sendable () -> Bool

    static let never = GraphBuildCancellation(isCancelled: { false })
}

struct LocalGraphBuilder {
    typealias BookLookup = (UUID) throws -> Book?
    typealias NeighborLookup = (
        UUID,
        Set<GraphRelationType>,
        Int
    ) throws -> GraphNeighborBatch

    func build(
        centerBookID: UUID,
        options: GraphBuildOptions,
        cancellation: GraphBuildCancellation = .never,
        book: BookLookup,
        neighbors: NeighborLookup
    ) throws -> GraphSnapshot {
        try checkCancellation(cancellation)
        guard let center = try book(centerBookID) else {
            throw GraphBuildError.centerBookNotFound
        }

        var nodesByID: [UUID: GraphNode] = [
            center.id: GraphNode(
                id: center.id,
                title: center.title,
                subtitle: center.author,
                isCenter: true,
                isSelected: true,
                distance: 0
            )
        ]
        var edgeEvidence: [GraphEdgeID: Set<GraphRelationEvidence>] = [:]
        var frontier = [center.id]
        var nodeLimitReached = false
        var edgeLimitReached = false
        var sourceCandidatesWereTruncated = false

        guard !options.relationTypes.isEmpty else {
            return GraphSnapshot(
                centerBookID: center.id,
                nodes: Array(nodesByID.values),
                edges: [],
                nodeLimitReached: false,
                edgeLimitReached: false,
                sourceCandidatesWereTruncated: false
            )
        }

        for distance in 1 ... options.depth.rawValue {
            try checkCancellation(cancellation)
            var proposals: [GraphProposal] = []
            for sourceID in frontier.sorted(by: uuidLessThan) {
                try checkCancellation(cancellation)
                let batch = try neighbors(
                    sourceID,
                    options.relationTypes,
                    options.candidateLimitPerExpansion
                )
                sourceCandidatesWereTruncated =
                    sourceCandidatesWereTruncated || batch.wasTruncated
                for neighbor in batch.neighbors where neighbor.book.id != sourceID {
                    let evidence = normalizedEvidence(
                        neighbor.evidence,
                        allowed: options.relationTypes
                    )
                    guard !evidence.isEmpty else { continue }
                    proposals.append(
                        GraphProposal(
                            sourceBookID: sourceID,
                            neighbor: neighbor.book,
                            evidence: evidence,
                            weight: GraphWeightModel.weight(for: evidence)
                        )
                    )
                }
            }

            proposals.sort {
                if $0.weight != $1.weight { return $0.weight > $1.weight }
                if $0.neighbor.title != $1.neighbor.title {
                    return $0.neighbor.title < $1.neighbor.title
                }
                if $0.neighbor.id != $1.neighbor.id {
                    return uuidLessThan($0.neighbor.id, $1.neighbor.id)
                }
                return uuidLessThan($0.sourceBookID, $1.sourceBookID)
            }

            var nextFrontier: Set<UUID> = []
            for proposal in proposals {
                try checkCancellation(cancellation)
                let targetID = proposal.neighbor.id
                let edgeID = GraphEdgeID(proposal.sourceBookID, targetID)
                if edgeEvidence[edgeID] == nil,
                   edgeEvidence.count >= options.maximumEdges
                {
                    edgeLimitReached = true
                    continue
                }
                if nodesByID[targetID] == nil {
                    guard nodesByID.count < options.maximumNodes else {
                        nodeLimitReached = true
                        continue
                    }
                    nodesByID[targetID] = GraphNode(
                        id: targetID,
                        title: proposal.neighbor.title,
                        subtitle: proposal.neighbor.author,
                        isCenter: false,
                        isSelected: false,
                        distance: distance
                    )
                    nextFrontier.insert(targetID)
                }

                edgeEvidence[edgeID, default: []].formUnion(proposal.evidence)
            }
            frontier = nextFrontier.sorted(by: uuidLessThan)
            if frontier.isEmpty { break }
        }

        let nodes = nodesByID.values.sorted {
            if $0.distance != $1.distance { return $0.distance < $1.distance }
            if $0.title != $1.title { return $0.title < $1.title }
            return uuidLessThan($0.id, $1.id)
        }
        let edges = edgeEvidence.map { id, evidenceSet in
            let evidence = evidenceSet.sorted { $0.sortKey < $1.sortKey }
            return GraphEdge(
                id: id,
                evidence: evidence,
                weight: GraphWeightModel.weight(for: evidence)
            )
        }.sorted {
            if $0.weight != $1.weight { return $0.weight > $1.weight }
            return $0.id < $1.id
        }
        return GraphSnapshot(
            centerBookID: center.id,
            nodes: nodes,
            edges: edges,
            nodeLimitReached: nodeLimitReached,
            edgeLimitReached: edgeLimitReached,
            sourceCandidatesWereTruncated: sourceCandidatesWereTruncated
        )
    }

    private func checkCancellation(_ cancellation: GraphBuildCancellation) throws {
        if cancellation.isCancelled() {
            throw GraphBuildError.cancelled
        }
    }

    private func normalizedEvidence(
        _ evidence: [GraphRelationEvidence],
        allowed: Set<GraphRelationType>
    ) -> [GraphRelationEvidence] {
        Array(Set(evidence.filter { allowed.contains($0.relationType) }))
            .sorted { $0.sortKey < $1.sortKey }
    }
}

enum GraphWeightModel {
    static let maximumCombinedWeight = 250

    static func weight(for evidence: [GraphRelationEvidence]) -> Int {
        let grouped = Dictionary(grouping: evidence, by: \.relationType)
        var result = 0
        if let manual = grouped[.manual], !manual.isEmpty {
            result += min(120, 100 + max(0, manual.count - 1) * 10)
        }
        if grouped[.sameAuthor]?.isEmpty == false {
            result += 80
        }
        if let collections = grouped[.sameCollection], !collections.isEmpty {
            result += min(60, 40 + max(0, collections.count - 1) * 10)
        }
        if let sources = grouped[.sameSource], !sources.isEmpty {
            result += min(50, 35 + max(0, sources.count - 1) * 5)
        }
        if let tags = grouped[.sharedTag], !tags.isEmpty {
            result += min(60, tags.count * 20)
        }
        return min(maximumCombinedWeight, result)
    }
}

struct GraphLayoutOptions: Equatable, Sendable {
    var size: CGSize = CGSize(width: 1_200, height: 800)
    var maximumIterations = 80
}

struct GraphLayoutResult: Equatable, Sendable {
    var positions: [UUID: CGPoint]
    let completedIterations: Int
}

struct DeterministicGraphLayout {
    func layout(
        snapshot: GraphSnapshot,
        options: GraphLayoutOptions = GraphLayoutOptions(),
        cancellation: GraphBuildCancellation = .never
    ) throws -> GraphLayoutResult {
        guard !snapshot.nodes.isEmpty else {
            return GraphLayoutResult(positions: [:], completedIterations: 0)
        }
        let center = CGPoint(x: options.size.width / 2, y: options.size.height / 2)
        var positions = initialPositions(snapshot: snapshot, center: center)
        guard snapshot.nodes.count > 1 else {
            return GraphLayoutResult(positions: positions, completedIterations: 0)
        }

        let orderedIDs = snapshot.nodes.map(\.id)
        let centerID = snapshot.centerBookID
        var completedIterations = 0
        for iteration in 0 ..< max(0, options.maximumIterations) {
            if cancellation.isCancelled() {
                throw GraphBuildError.cancelled
            }
            var displacement = Dictionary(
                uniqueKeysWithValues: orderedIDs.map { ($0, CGVector.zero) }
            )

            for firstIndex in orderedIDs.indices {
                for secondIndex in orderedIDs.indices where secondIndex > firstIndex {
                    let first = orderedIDs[firstIndex]
                    let second = orderedIDs[secondIndex]
                    guard let firstPoint = positions[first], let secondPoint = positions[second] else {
                        continue
                    }
                    var delta = CGVector(
                        dx: firstPoint.x - secondPoint.x,
                        dy: firstPoint.y - secondPoint.y
                    )
                    if abs(delta.dx) < 0.01 && abs(delta.dy) < 0.01 {
                        delta = deterministicNudge(first, second)
                    }
                    let distance = max(24, hypot(delta.dx, delta.dy))
                    let force = 2_200 / (distance * distance)
                    let unit = CGVector(dx: delta.dx / distance, dy: delta.dy / distance)
                    displacement[first, default: .zero].dx += unit.dx * force
                    displacement[first, default: .zero].dy += unit.dy * force
                    displacement[second, default: .zero].dx -= unit.dx * force
                    displacement[second, default: .zero].dy -= unit.dy * force
                }
            }

            for edge in snapshot.edges {
                guard let firstPoint = positions[edge.id.firstBookID],
                      let secondPoint = positions[edge.id.secondBookID]
                else { continue }
                let delta = CGVector(
                    dx: secondPoint.x - firstPoint.x,
                    dy: secondPoint.y - firstPoint.y
                )
                let distance = max(1, hypot(delta.dx, delta.dy))
                let preferred = max(95, 190 - CGFloat(edge.weight) * 0.35)
                let force = (distance - preferred) * 0.0025
                let unit = CGVector(dx: delta.dx / distance, dy: delta.dy / distance)
                displacement[edge.id.firstBookID, default: .zero].dx += unit.dx * force
                displacement[edge.id.firstBookID, default: .zero].dy += unit.dy * force
                displacement[edge.id.secondBookID, default: .zero].dx -= unit.dx * force
                displacement[edge.id.secondBookID, default: .zero].dy -= unit.dy * force
            }

            var maximumMovement: CGFloat = 0
            let cooling = max(0.12, 1 - CGFloat(iteration) / CGFloat(max(options.maximumIterations, 1)))
            for id in orderedIDs where id != centerID {
                guard var point = positions[id], let delta = displacement[id] else { continue }
                let movement = CGVector(
                    dx: min(max(delta.dx * 18 * cooling, -12), 12),
                    dy: min(max(delta.dy * 18 * cooling, -12), 12)
                )
                point.x = min(max(point.x + movement.dx, 44), options.size.width - 44)
                point.y = min(max(point.y + movement.dy, 44), options.size.height - 44)
                positions[id] = point
                maximumMovement = max(maximumMovement, hypot(movement.dx, movement.dy))
            }
            positions[centerID] = center
            completedIterations = iteration + 1
            if iteration >= 12 && maximumMovement < 0.04 {
                break
            }
        }
        return GraphLayoutResult(
            positions: positions,
            completedIterations: completedIterations
        )
    }

    private func initialPositions(
        snapshot: GraphSnapshot,
        center: CGPoint
    ) -> [UUID: CGPoint] {
        var result = [snapshot.centerBookID: center]
        for distance in [1, 2] {
            let nodes = snapshot.nodes
                .filter { $0.distance == distance }
                .sorted { uuidLessThan($0.id, $1.id) }
            let radius: CGFloat = distance == 1 ? 220 : 360
            for (index, node) in nodes.enumerated() {
                let angle = (CGFloat(index) / CGFloat(max(nodes.count, 1))) * 2 * .pi
                    - .pi / 2
                result[node.id] = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
            }
        }
        return result
    }

    private func deterministicNudge(_ first: UUID, _ second: UUID) -> CGVector {
        let value = first.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            + second.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let angle = CGFloat(value % 360) * .pi / 180
        return CGVector(dx: cos(angle), dy: sin(angle))
    }
}

struct GraphSceneMetrics: Equatable, Sendable {
    let querySeconds: Double
    let projectionSeconds: Double
    let layoutSeconds: Double
}

struct GraphScene: Equatable, Sendable {
    var snapshot: GraphSnapshot
    var layout: GraphLayoutResult
    let metrics: GraphSceneMetrics
}

private struct GraphProposal {
    let sourceBookID: UUID
    let neighbor: Book
    let evidence: [GraphRelationEvidence]
    let weight: Int
}

private func uuidLessThan(_ lhs: UUID, _ rhs: UUID) -> Bool {
    lhs.uuidString < rhs.uuidString
}

extension Duration {
    var secondsValue: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
