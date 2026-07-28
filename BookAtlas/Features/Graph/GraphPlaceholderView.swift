import SwiftUI

struct LocalGraphView: View {
    @ObservedObject var store: GraphStore
    let defaultCenterBookID: UUID?
    let openBook: (UUID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewport = GraphViewportState()
    @State private var canvasSize = CGSize(width: 800, height: 520)
    @State private var draggedNodeID: UUID?
    @State private var panStart = CGSize.zero
    @State private var magnificationStart: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("书图")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("page-title-graph")

            controls

            if let message = store.statusMessage {
                Label(
                    message,
                    systemImage: store.scene?.snapshot.isLimited == true
                        ? "gauge.with.dots.needle.67percent"
                        : "info.circle"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(3)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("图谱状态：\(message)")
                .accessibilityIdentifier("graph-status")
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("local-graph-page")
        .task {
            store.loadIfNeeded(centerBookID: defaultCenterBookID)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(GraphDepth.allCases, id: \.self) { depth in
                        Button(depth.displayTitle) {
                            store.setDepth(depth)
                        }
                        .buttonStyle(.bordered)
                        .tint(store.options.depth == depth ? .accentColor : .secondary)
                        .accessibilityLabel("显示\(depth.displayTitle)关系")
                        .accessibilityIdentifier("graph-depth-\(depth.rawValue)")
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("关系层级")
                .accessibilityIdentifier("graph-depth-control")

                Button("重置视图", systemImage: "arrow.counterclockwise") {
                    resetViewport()
                    store.resetView()
                }
                .disabled(store.centerBookID == nil)
                .accessibilityIdentifier("graph-reset-button")

                Spacer()

                if store.state == .loading {
                    Button("取消构建", role: .cancel, action: store.cancel)
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("graph-cancel-button")
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(GraphRelationType.allCases, id: \.self) { relationType in
                            let isEnabled = store.options.relationTypes.contains(relationType)
                            Button {
                                store.toggleRelationType(relationType)
                            } label: {
                                Label(
                                    relationType.displayTitle,
                                    systemImage: isEnabled ? "checkmark.circle.fill" : "circle"
                                )
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel(
                                "\(relationType.displayTitle)，\(isEnabled ? "已启用" : "已停用")"
                            )
                            .accessibilityIdentifier("graph-filter-\(relationType.rawValue)")
                        }
                    }
                }
            .accessibilityLabel("关系筛选")
            .accessibilityIdentifier("graph-filter-control")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .needsCenter:
            ContentUnavailableView {
                Label("请选择中心书籍", systemImage: "scope")
            } description: {
                Text("从书库详情选择“查看局部书图”，即可从该书的一层真实关系开始探索。")
            }
            .accessibilityIdentifier("graph-needs-center")
        case .loading:
            ProgressView("正在本地构建有限关系图…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("graph-loading")
        case .empty:
            ContentUnavailableView {
                Label(
                    store.options.relationTypes.isEmpty ? "筛选后没有关系" : "这本书暂无有效关系",
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
            } description: {
                Text(
                    store.options.relationTypes.isEmpty
                        ? "至少启用一种关系类型后重试。"
                        : "可以添加共同标签、加入同一书单、记录相同来源，或建立手动关系。"
                )
            } actions: {
                Button("重新构建", action: store.reload)
            }
            .accessibilityIdentifier("graph-empty-state")
        case .cancelled:
            ContentUnavailableView {
                Label("图谱构建已取消", systemImage: "xmark.circle")
            } description: {
                Text("书库没有变化；可以重新构建当前中心书籍。")
            } actions: {
                Button("重新构建", action: store.reload)
            }
            .accessibilityIdentifier("graph-cancelled-state")
        case .failed:
            ContentUnavailableView {
                Label("无法显示局部书图", systemImage: "exclamationmark.triangle")
            } description: {
                Text(store.statusMessage ?? "本地关系数据暂时不可用。")
            } actions: {
                Button("重试", action: store.reload)
            }
            .accessibilityIdentifier("graph-error-state")
        case .content:
            if let scene = store.scene {
                graphContent(scene)
            }
        }
    }

    @ViewBuilder
    private func graphContent(_ scene: GraphScene) -> some View {
        GeometryReader { geometry in
            let horizontal = geometry.size.width >= 760
            Group {
                if horizontal {
                    HStack(spacing: 12) {
                        graphCanvas(scene)
                        GraphAccessibilityPanel(store: store, openBook: openBook)
                            .frame(width: min(340, geometry.size.width * 0.36))
                    }
                } else {
                    VStack(spacing: 12) {
                        graphCanvas(scene)
                            .frame(minHeight: 260)
                        GraphAccessibilityPanel(store: store, openBook: openBook)
                            .frame(minHeight: 220)
                    }
                }
            }
        }
    }

    private func graphCanvas(_ scene: GraphScene) -> some View {
        GeometryReader { geometry in
            Canvas(rendersAsynchronously: true) { context, _ in
                draw(scene: scene, context: &context)
            }
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 1)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(scene: scene))
            .simultaneousGesture(tapGesture(scene: scene))
            .simultaneousGesture(magnificationGesture)
            .onAppear {
                canvasSize = geometry.size
                resetViewport()
            }
            .onChange(of: geometry.size) { _, newSize in
                canvasSize = newSize
                resetViewport()
            }
            .onChange(of: scene.snapshot.centerBookID) { _, _ in
                resetViewport()
            }
            .accessibilityHidden(true)
            .accessibilityIdentifier("graph-canvas")
        }
    }

    private func draw(
        scene: GraphScene,
        context: inout GraphicsContext
    ) {
        let selectedID = scene.snapshot.selectedNode?.id
        let highlighted = selectedID.map {
            scene.snapshot.directNeighborIDs(of: $0)
        } ?? []

        context.translateBy(
            x: viewport.translation.width,
            y: viewport.translation.height
        )
        context.scaleBy(x: viewport.scale, y: viewport.scale)

        for edge in scene.snapshot.edges {
            guard let first = scene.layout.positions[edge.id.firstBookID],
                  let second = scene.layout.positions[edge.id.secondBookID]
            else { continue }
            let touchesSelection =
                selectedID == edge.id.firstBookID || selectedID == edge.id.secondBookID
            var path = Path()
            path.move(to: first)
            path.addLine(to: second)
            let hasManual = edge.relationTypes.contains(.manual)
            context.stroke(
                path,
                with: .color(touchesSelection ? .accentColor : .secondary.opacity(0.55)),
                style: StrokeStyle(
                    lineWidth: touchesSelection ? 3 : max(1, CGFloat(edge.weight) / 90),
                    dash: hasManual ? [8, 4] : []
                )
            )
        }

        for node in scene.snapshot.nodes {
            guard let position = scene.layout.positions[node.id] else { continue }
            let isHighlighted = highlighted.contains(node.id)
            let radius: CGFloat = node.isCenter ? 18 : 14
            if isHighlighted {
                let halo = CGRect(
                    x: position.x - radius - 6,
                    y: position.y - radius - 6,
                    width: (radius + 6) * 2,
                    height: (radius + 6) * 2
                )
                context.stroke(
                    Path(ellipseIn: halo),
                    with: .color(.accentColor.opacity(0.65)),
                    lineWidth: 3
                )
            }
            let rect = CGRect(
                x: position.x - radius,
                y: position.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            let nodePath = node.isCenter
                ? Path(roundedRect: rect, cornerRadius: 5)
                : Path(ellipseIn: rect)
            context.fill(
                nodePath,
                with: .color(node.isCenter ? .orange : .blue)
            )
            if node.isSelected {
                context.stroke(nodePath, with: .color(.primary), lineWidth: 4)
            }
            let text = context.resolve(
                Text(node.title)
                    .font(.system(size: node.isCenter ? 13 : 11, weight: .semibold))
                    .foregroundStyle(.primary)
            )
            context.draw(
                text,
                at: CGPoint(x: position.x, y: position.y + radius + 14),
                anchor: .center
            )
        }
    }

    private func tapGesture(scene: GraphScene) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                if let id = hitTest(
                    at: graphPoint(for: value.location),
                    scene: scene
                ) {
                    store.selectNode(id)
                }
            }
    }

    private func dragGesture(scene: GraphScene) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if draggedNodeID == nil {
                    draggedNodeID = hitTest(
                        at: graphPoint(for: value.startLocation),
                        scene: scene
                    )
                    panStart = viewport.translation
                }
                if let draggedNodeID {
                    store.moveNode(
                        draggedNodeID,
                        to: graphPoint(for: value.location)
                    )
                } else {
                    viewport.translation = CGSize(
                        width: panStart.width + value.translation.width,
                        height: panStart.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                draggedNodeID = nil
            }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if magnificationStart == nil {
                    magnificationStart = viewport.scale
                }
                let base = magnificationStart ?? viewport.scale
                viewport.scale = min(max(base * value.magnification, 0.4), 3)
            }
            .onEnded { _ in
                magnificationStart = nil
            }
    }

    private func hitTest(at graphPoint: CGPoint, scene: GraphScene) -> UUID? {
        scene.snapshot.nodes.first { node in
            guard let point = scene.layout.positions[node.id] else { return false }
            return hypot(point.x - graphPoint.x, point.y - graphPoint.y) <= 24
        }?.id
    }

    private func graphPoint(for location: CGPoint) -> CGPoint {
        CGPoint(
            x: (location.x - viewport.translation.width) / viewport.scale,
            y: (location.y - viewport.translation.height) / viewport.scale
        )
    }

    private func resetViewport() {
        let scale = min(
            max(min(canvasSize.width / 1_200, canvasSize.height / 800) * 0.92, 0.4),
            1
        )
        viewport = GraphViewportState(
            scale: scale,
            translation: CGSize(
                width: (canvasSize.width - 1_200 * scale) / 2,
                height: (canvasSize.height - 800 * scale) / 2
            )
        )
        if reduceMotion {
            magnificationStart = nil
        }
    }
}

private struct GraphAccessibilityPanel: View {
    @ObservedObject var store: GraphStore
    let openBook: (UUID) -> Void
    @FocusState private var focusedNodeID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("可访问的节点与关系")
                .font(.headline)

            HStack {
                Button("上一个节点", systemImage: "arrow.up") {
                    moveKeyboardSelection(offset: -1)
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .accessibilityIdentifier("graph-previous-node")
                Button("下一个节点", systemImage: "arrow.down") {
                    moveKeyboardSelection(offset: 1)
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
                .accessibilityIdentifier("graph-next-node")
            }
            .controlSize(.small)

            List {
                ForEach(store.scene?.snapshot.nodes ?? []) { node in
                    Button {
                        store.selectNode(node.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.title)
                                .fontWeight(node.isCenter ? .bold : .regular)
                            Text(
                                [
                                    node.subtitle,
                                    node.isCenter ? "中心书籍" : "距离中心 \(node.distance) 层"
                                ]
                                .compactMap { $0 }
                                .joined(separator: " · ")
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background {
                        if node.isSelected {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.15))
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(node.title)，\(node.subtitle ?? "作者未知")，\(node.isCenter ? "中心书籍" : "距离中心 \(node.distance) 层")"
                    )
                    .accessibilityValue(node.isSelected ? "已选择" : "")
                    .accessibilityIdentifier("graph-node-\(node.id.uuidString)")
                    .focused($focusedNodeID, equals: node.id)
                }
            }
            .accessibilityIdentifier("graph-node-list")
            .onMoveCommand(perform: moveKeyboardSelection)

            if let selected = store.selectedNode {
                GroupBox("当前选择") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selected.title)
                            .font(.headline)
                            .accessibilityIdentifier("graph-selected-node")
                        if store.selectedRelations.isEmpty {
                            Text("当前节点没有显示中的直接关系。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(store.selectedRelations) { relation in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(relation.otherNode.title) · 权重 \(relation.weight)")
                                        .fontWeight(.medium)
                                    ForEach(relation.explanations, id: \.self) { explanation in
                                        Text(explanation)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier(
                                    "graph-relation-\(relation.id.firstBookID.uuidString)-\(relation.id.secondBookID.uuidString)"
                                )
                            }
                        }
                        HStack {
                            Button("打开书籍详情") {
                                openBook(selected.id)
                            }
                            .keyboardShortcut(.defaultAction)
                            .accessibilityIdentifier("graph-open-detail")
                            Button("设为新的中心") {
                                store.useSelectedNodeAsCenter()
                            }
                            .disabled(selected.isCenter)
                            .accessibilityIdentifier("graph-set-center")
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("graph-accessibility-panel")
    }

    private func moveKeyboardSelection(_ direction: MoveCommandDirection) {
        let offset = direction == .down || direction == .right ? 1 : -1
        guard direction == .down || direction == .up || direction == .right || direction == .left
        else { return }
        moveKeyboardSelection(offset: offset)
    }

    private func moveKeyboardSelection(offset: Int) {
        let nodes = store.scene?.snapshot.nodes ?? []
        guard !nodes.isEmpty else { return }
        let currentID = focusedNodeID ?? store.selectedNode?.id
        let currentIndex = nodes.firstIndex { $0.id == currentID } ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), nodes.count - 1)
        focusedNodeID = nodes[nextIndex].id
        store.selectNode(nodes[nextIndex].id)
    }
}

private struct GraphViewportState: Equatable {
    var scale: CGFloat = 1
    var translation: CGSize = .zero
}
