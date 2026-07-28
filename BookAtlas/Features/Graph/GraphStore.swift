import CoreGraphics
import Foundation

enum GraphViewState: Equatable {
    case needsCenter
    case loading
    case content
    case empty
    case cancelled
    case failed
}

struct GraphAccessibleRelation: Identifiable, Equatable {
    let id: GraphEdgeID
    let otherNode: GraphNode
    let weight: Int
    let explanations: [String]
}

@MainActor
final class GraphStore: ObservableObject {
    @Published private(set) var state: GraphViewState = .needsCenter
    @Published private(set) var scene: GraphScene?
    @Published private(set) var centerBookID: UUID?
    @Published private(set) var options = GraphBuildOptions()
    @Published private(set) var statusMessage: String?

    private let catalog: (any LibraryCataloging)?
    private var task: Task<Void, Never>?
    private var generation: UInt64 = 0

    init(catalog: (any LibraryCataloging)?) {
        self.catalog = catalog
    }

    var selectedNode: GraphNode? {
        scene?.snapshot.selectedNode
    }

    var selectedRelations: [GraphAccessibleRelation] {
        guard let snapshot = scene?.snapshot, let selected = snapshot.selectedNode else {
            return []
        }
        let nodes = Dictionary(uniqueKeysWithValues: snapshot.nodes.map { ($0.id, $0) })
        return snapshot.edges.compactMap { edge in
            let otherID: UUID
            if edge.id.firstBookID == selected.id {
                otherID = edge.id.secondBookID
            } else if edge.id.secondBookID == selected.id {
                otherID = edge.id.firstBookID
            } else {
                return nil
            }
            guard let other = nodes[otherID] else { return nil }
            return GraphAccessibleRelation(
                id: edge.id,
                otherNode: other,
                weight: edge.weight,
                explanations: edge.evidence.map {
                    explanation(for: $0, nodes: nodes)
                }
            )
        }.sorted {
            if $0.weight != $1.weight { return $0.weight > $1.weight }
            return $0.otherNode.title < $1.otherNode.title
        }
    }

    func load(centerBookID: UUID, options: GraphBuildOptions? = nil) {
        if let options {
            self.options = options
        }
        self.centerBookID = centerBookID
        startLoad()
    }

    func loadIfNeeded(centerBookID: UUID?) {
        guard self.centerBookID == nil, let centerBookID else { return }
        load(centerBookID: centerBookID)
    }

    func reload() {
        guard centerBookID != nil else {
            state = .needsCenter
            return
        }
        startLoad()
    }

    func cancel() {
        guard state == .loading else { return }
        generation &+= 1
        task?.cancel()
        state = .cancelled
        statusMessage = "图谱构建已取消；书库未更改。"
    }

    func setDepth(_ depth: GraphDepth) {
        guard options.depth != depth else { return }
        options.depth = depth
        reload()
    }

    func toggleRelationType(_ relationType: GraphRelationType) {
        if options.relationTypes.contains(relationType) {
            options.relationTypes.remove(relationType)
        } else {
            options.relationTypes.insert(relationType)
        }
        reload()
    }

    func selectNode(_ id: UUID) {
        guard var updatedScene = scene,
              updatedScene.snapshot.nodes.contains(where: { $0.id == id })
        else { return }
        for index in updatedScene.snapshot.nodes.indices {
            updatedScene.snapshot.nodes[index].isSelected =
                updatedScene.snapshot.nodes[index].id == id
        }
        scene = updatedScene
    }

    func moveNode(_ id: UUID, to point: CGPoint) {
        guard var updatedScene = scene,
              updatedScene.layout.positions[id] != nil
        else { return }
        updatedScene.layout.positions[id] = point
        scene = updatedScene
        selectNode(id)
    }

    func useSelectedNodeAsCenter() {
        guard let selectedNode else { return }
        load(centerBookID: selectedNode.id)
    }

    func resetView() {
        reload()
    }

    func waitForPendingWork() async {
        await task?.value
    }

    private func startLoad() {
        guard let centerBookID else {
            state = .needsCenter
            return
        }
        guard let catalog else {
            state = .failed
            statusMessage = "无法读取本地图谱数据，请稍后重试。"
            return
        }

        generation &+= 1
        let requestedGeneration = generation
        let requestedOptions = options
        task?.cancel()
        state = .loading
        statusMessage = nil
        task = Task { @MainActor [weak self] in
            do {
                let scene = try await catalog.localGraph(
                    centerBookID: centerBookID,
                    options: requestedOptions
                )
                try Task.checkCancellation()
                guard let self, self.generation == requestedGeneration else { return }
                self.scene = scene
                self.state = scene.snapshot.edges.isEmpty ? .empty : .content
                if scene.snapshot.isLimited {
                    self.statusMessage = Self.limitMessage(
                        for: scene.snapshot,
                        options: requestedOptions
                    )
                }
            } catch is CancellationError {
                return
            } catch GraphBuildError.cancelled {
                guard let self, self.generation == requestedGeneration else { return }
                self.state = .cancelled
                self.statusMessage = "图谱构建已取消；书库未更改。"
            } catch GraphBuildError.centerBookNotFound {
                guard let self, self.generation == requestedGeneration else { return }
                self.scene = nil
                self.state = .failed
                self.statusMessage = "中心书籍已不存在，请返回书库重新选择。"
            } catch {
                guard let self, self.generation == requestedGeneration else { return }
                self.scene = nil
                self.state = .failed
                self.statusMessage = "无法读取本地图谱数据；书库内容未被更改。"
            }
        }
    }

    private static func limitMessage(
        for snapshot: GraphSnapshot,
        options: GraphBuildOptions
    ) -> String {
        var reasons: [String] = []
        if snapshot.nodeLimitReached {
            reasons.append("节点达到 \(options.maximumNodes) 个当前上限")
        }
        if snapshot.edgeLimitReached {
            reasons.append("边达到 \(options.maximumEdges) 条当前上限")
        }
        if snapshot.sourceCandidatesWereTruncated {
            reasons.append("部分关系候选已按权重和稳定顺序截断")
        }
        return reasons.joined(separator: "；") + "。"
    }

    private func explanation(
        for evidence: GraphRelationEvidence,
        nodes: [UUID: GraphNode]
    ) -> String {
        guard case let .manual(_, kind, _, sourceID, targetID, hasNote) = evidence else {
            return evidence.explanation
        }
        let source = nodes[sourceID]?.title ?? "来源书籍"
        let target = nodes[targetID]?.title ?? "目标书籍"
        return "手动关系：\(source) \(kind.graphDisplayTitle) \(target)\(hasNote ? "，含备注" : "")"
    }
}
