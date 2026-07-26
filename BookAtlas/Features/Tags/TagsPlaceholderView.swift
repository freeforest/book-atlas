import SwiftUI

struct TagsPlaceholderView: View {
    var body: some View {
        PlaceholderPage(
            section: .tags,
            description: "标签管理将在后续目录功能阶段实现。"
        ) {
            EmptyStateView(
                title: "标签尚未建立",
                message: "这里将帮助你用自定义标签整理书目。",
                symbolName: "tag"
            )
        }
    }
}
