import Foundation
import SwiftUI

enum CatalogUserFacingError: Error, Equatable {
    case invalidName
    case nameConflict
    case invalidMerge
    case operationFailed

    var title: String {
        switch self {
        case .invalidName:
            "名称不能为空"
        case .nameConflict:
            "名称已存在"
        case .invalidMerge:
            "无法合并标签"
        case .operationFailed:
            "无法更新整理信息"
        }
    }

    var message: String {
        switch self {
        case .invalidName:
            "请输入一个有效名称。"
        case .nameConflict:
            "名称忽略大小写和多余空白后必须保持唯一。"
        case .invalidMerge:
            "请选择两个不同的标签后重试。"
        case .operationFailed:
            "本地书库没有完成本次操作，现有数据保持不变。"
        }
    }
}

@MainActor
final class CatalogOrganizerStore: ObservableObject {
    @Published private(set) var snapshot = CatalogSnapshot.empty
    @Published private(set) var membership = BookMembership.empty
    @Published private(set) var membershipBookID: UUID?
    @Published private(set) var isLoading = false
    @Published var error: CatalogUserFacingError?

    private let catalog: (any LibraryCataloging)?
    private var pendingTask: Task<Void, Never>?
    private var activeRequestID = UUID()

    init(catalog: (any LibraryCataloging)?) {
        self.catalog = catalog
    }

    func load() {
        guard let catalog else {
            error = .operationFailed
            return
        }
        pendingTask?.cancel()
        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        pendingTask = Task { [weak self] in
            do {
                let snapshot = try await catalog.catalogSnapshot()
                try Task.checkCancellation()
                guard let self, self.activeRequestID == requestID else {
                    return
                }
                self.snapshot = snapshot
                self.isLoading = false
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.activeRequestID == requestID else {
                    return
                }
                self.isLoading = false
                self.error = .operationFailed
            }
        }
    }

    func loadMembership(for bookID: UUID) async {
        guard let catalog else {
            error = .operationFailed
            return
        }
        do {
            membership = try await catalog.membership(for: bookID)
            membershipBookID = bookID
        } catch {
            membership = .empty
            membershipBookID = nil
            self.error = .operationFailed
        }
    }

    @discardableResult
    func setAssociation(_ association: BookAssociation, included: Bool, bookID: UUID) async -> Bool {
        guard let catalog else {
            error = .operationFailed
            return false
        }
        pendingTask?.cancel()
        activeRequestID = UUID()
        do {
            try await catalog.setAssociation(association, included: included, bookID: bookID)
            await loadMembership(for: bookID)
            snapshot = try await catalog.catalogSnapshot()
            return true
        } catch {
            self.error = .operationFailed
            return false
        }
    }

    @discardableResult
    func createTag(name: String) async -> Bool {
        await performMutation {
            _ = try await $0.createTag(name: name)
        }
    }

    @discardableResult
    func renameTag(_ tag: Tag, name: String) async -> Bool {
        await performMutation {
            _ = try await $0.renameTag(tag, name: name)
        }
    }

    @discardableResult
    func deleteTag(_ tag: Tag) async -> Bool {
        await performMutation {
            try await $0.deleteTag(tag)
        }
    }

    @discardableResult
    func mergeTag(_ source: Tag, into target: Tag) async -> Bool {
        await performMutation {
            try await $0.mergeTag(source, into: target)
        }
    }

    @discardableResult
    func createCollection(name: String, description: String?) async -> Bool {
        await performMutation {
            _ = try await $0.createCollection(name: name, description: description)
        }
    }

    @discardableResult
    func renameCollection(
        _ collection: BookCollection,
        name: String,
        description: String?
    ) async -> Bool {
        await performMutation {
            _ = try await $0.renameCollection(collection, name: name, description: description)
        }
    }

    @discardableResult
    func deleteCollection(_ collection: BookCollection) async -> Bool {
        await performMutation {
            try await $0.deleteCollection(collection)
        }
    }

    @discardableResult
    func createSource(name: String, details: String?) async -> Bool {
        await performMutation {
            _ = try await $0.createSource(name: name, details: details)
        }
    }

    @discardableResult
    func renameSource(
        _ source: RecommendationSource,
        name: String,
        details: String?
    ) async -> Bool {
        await performMutation {
            _ = try await $0.renameSource(source, name: name, details: details)
        }
    }

    @discardableResult
    func deleteSource(_ source: RecommendationSource) async -> Bool {
        await performMutation {
            try await $0.deleteSource(source)
        }
    }

    func dismissError() {
        error = nil
    }

    func waitForPendingWork() async {
        await pendingTask?.value
    }

    private func performMutation(
        _ operation: (any LibraryCataloging) async throws -> Void
    ) async -> Bool {
        guard let catalog else {
            error = .operationFailed
            return false
        }
        pendingTask?.cancel()
        activeRequestID = UUID()
        do {
            try await operation(catalog)
            snapshot = try await catalog.catalogSnapshot()
            return true
        } catch DomainValidationError.blankName {
            error = .invalidName
        } catch CatalogServiceError.nameConflict {
            error = .nameConflict
        } catch CatalogServiceError.invalidMerge {
            error = .invalidMerge
        } catch {
            self.error = .operationFailed
        }
        return false
    }
}
