import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case library
    case collections
    case tags
    case graph
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library: "书库"
        case .collections: "书单"
        case .tags: "标签"
        case .graph: "书图"
        case .settings: "设置"
        }
    }

    var symbolName: String {
        switch self {
        case .library: "books.vertical"
        case .collections: "rectangle.stack"
        case .tags: "tag"
        case .graph: "point.3.connected.trianglepath.dotted"
        case .settings: "gearshape"
        }
    }

    var navigationIdentifier: String { "navigation-\(rawValue)" }
    var pageIdentifier: String { "page-title-\(rawValue)" }
}

struct AppNavigationState: Equatable {
    var selection: AppSection = .library
}
