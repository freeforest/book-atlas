import SwiftUI

struct SettingsPlaceholderView: View {
    var body: some View {
        PlaceholderPage(
            section: .settings,
            description: "Book Atlas 默认离线，不收集使用数据。"
        ) {
            EmptyStateView(
                title: "设置将在此显示",
                message: "隐私、数据和外观选项会在相应功能准备好后加入。",
                symbolName: "gearshape"
            )
        }
    }
}
