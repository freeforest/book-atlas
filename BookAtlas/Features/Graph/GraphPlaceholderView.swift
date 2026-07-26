import SwiftUI

struct GraphPlaceholderView: View {
    var body: some View {
        PlaceholderPage(
            section: .graph,
            description: "书图将始终是本地关系数据的投影，而不是数据来源。"
        ) {
            EmptyStateView(
                title: "书图等待关系数据",
                message: "图谱渲染和交互将在经过验证的后续阶段加入。",
                symbolName: "point.3.connected.trianglepath.dotted"
            )
        }
    }
}
