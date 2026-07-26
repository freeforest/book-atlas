import SwiftUI

struct CollectionsPlaceholderView: View {
    var body: some View {
        PlaceholderPage(
            section: .collections,
            description: "书单组织功能将在书籍数据层稳定后实现。"
        ) {
            EmptyStateView(
                title: "书单尚未建立",
                message: "这里将展示用户维护的阅读书单。",
                symbolName: "rectangle.stack"
            )
        }
    }
}
