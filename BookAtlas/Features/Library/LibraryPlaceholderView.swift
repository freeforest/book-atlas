import SwiftUI

struct LibraryPlaceholderView: View {
    var body: some View {
        PlaceholderPage(
            section: .library,
            description: "书籍将保存在本地；数据层将在后续阶段加入。"
        ) {
            EmptyStateView(
                title: "书库尚无内容",
                message: "稍后可以在这里浏览和维护你的书目。",
                symbolName: "books.vertical"
            )
        }
    }
}
