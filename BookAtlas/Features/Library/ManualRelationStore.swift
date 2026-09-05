import Foundation
import SwiftUI

enum ManualRelationLoadState: Equatable {
    case idle
    case loading
    case content
    case failed
}

enum ManualRelationTargetSearchState: Equatable {
    case idle
    case loading
    case content
    case failed
}

protocol ManualRelationAccessing: Sendable {
    func relations(for bookID: UUID) async throws -> [ManualRelationSummary]
    func targetPage(
        matching query: LibraryQuery,
        excludingBookID: UUID
    ) async throws -> LibraryPage
    func add(_ relation: ManualBookRelation) async throws -> ManualBookRelation
    func delete(_ relation: ManualBookRelation) async throws
}

private struct CatalogManualRelationAccess: ManualRelationAccessing {
    let catalog: any LibraryCataloging

    func relations(for bookID: UUID) async throws -> [ManualRelationSummary] {
        try await catalog.manualRelationSummaries(for: bookID)
    }

    func targetPage(
        matching query: LibraryQuery,
        excludingBookID: UUID
    ) async throws -> LibraryPage {
        try await catalog.manualRelationTargetPage(
            query,
            excludingBookID: excludingBookID
        )
    }

    func add(_ relation: ManualBookRelation) async throws -> ManualBookRelation {
        try await catalog.addManualRelation(relation)
    }

    func delete(_ relation: ManualBookRelation) async throws {
        try await catalog.deleteManualRelation(relation)
    }
}

@MainActor
final class ManualRelationStore: ObservableObject {
    @Published private(set) var currentBookID: UUID?
    @Published private(set) var loadState: ManualRelationLoadState = .idle
    @Published private(set) var outgoingRelations: [ManualRelationSummary] = []
    @Published private(set) var incomingRelations: [ManualRelationSummary] = []
    @Published private(set) var statusMessage: String?

    @Published private(set) var isCreating = false
    @Published private(set) var targetSearchText = ""
    @Published private(set) var targetSearchState: ManualRelationTargetSearchState = .idle
    @Published private(set) var targetBooks: [Book] = []
    @Published private(set) var targetTotalCount = 0
    @Published private(set) var hasMoreTargets = false
    @Published private(set) var isLoadingMoreTargets = false
    @Published private(set) var targetLoadMoreFailed = false
    @Published private(set) var selectedTargetID: UUID?
    @Published private(set) var selectedKind: ManualRelationKind = .related
    @Published private(set) var relationNote = ""
    @Published private(set) var isSaving = false
    @Published private(set) var creationErrorMessage: String?

    @Published private(set) var deletionCandidate: ManualRelationSummary?
    @Published private(set) var isDeleting = false
    @Published private(set) var deletionErrorMessage: String?

    private let access: (any ManualRelationAccessing)?
    private var loadTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var loadGeneration: UInt64 = 0
    private var searchGeneration: UInt64 = 0
    private var targetQuery = LibraryQuery()
    private var nextTargetOffset = 0

    init(catalog: (any LibraryCataloging)?) {
        access = catalog.map(CatalogManualRelationAccess.init(catalog:))
    }

    init(access: (any ManualRelationAccessing)?) {
        self.access = access
    }

    deinit {
        loadTask?.cancel()
        searchTask?.cancel()
    }

    var allRelations: [ManualRelationSummary] {
        outgoingRelations + incomingRelations
    }

    var selectedTarget: Book? {
        guard let selectedTargetID else { return nil }
        return targetBooks.first { $0.id == selectedTargetID }
    }

    var targetResultDescription: String {
        "已显示 \(targetBooks.count) 本，共 \(targetTotalCount) 本可选目标"
    }

    var canLoadMoreTargets: Bool {
        isCreating
            && targetSearchState == .content
            && hasMoreTargets
            && !isLoadingMoreTargets
    }

    func load(bookID: UUID) {
        loadGeneration &+= 1
        let generation = loadGeneration
        currentBookID = bookID
        loadTask?.cancel()
        clearCreationState()
        deletionCandidate = nil
        isDeleting = false
        deletionErrorMessage = nil
        outgoingRelations = []
        incomingRelations = []
        statusMessage = nil
        loadState = .loading

        guard let access else {
            loadState = .failed
            return
        }
        loadTask = Task { @MainActor [weak self] in
            do {
                let relations = try await access.relations(for: bookID)
                try Task.checkCancellation()
                guard let self,
                      self.isCurrentLoad(bookID: bookID, generation: generation),
                      relations.allSatisfy({ summary in
                          switch summary.direction {
                          case .outgoing:
                              summary.relation.sourceBookID == bookID
                                  && summary.relation.targetBookID == summary.otherBookID
                          case .incoming:
                              summary.relation.targetBookID == bookID
                                  && summary.relation.sourceBookID == summary.otherBookID
                          }
                      })
                else { return }
                self.outgoingRelations = relations.filter { $0.direction == .outgoing }
                self.incomingRelations = relations.filter { $0.direction == .incoming }
                self.loadState = .content
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      self.isCurrentLoad(bookID: bookID, generation: generation)
                else { return }
                self.outgoingRelations = []
                self.incomingRelations = []
                self.loadState = .failed
            }
        }
    }

    func retryLoad() {
        guard let currentBookID else { return }
        load(bookID: currentBookID)
    }

    func reset() {
        loadGeneration &+= 1
        loadTask?.cancel()
        loadTask = nil
        currentBookID = nil
        outgoingRelations = []
        incomingRelations = []
        loadState = .idle
        statusMessage = nil
        clearCreationState()
        deletionCandidate = nil
        isDeleting = false
        deletionErrorMessage = nil
    }

    func beginCreate() {
        guard currentBookID != nil else {
            creationErrorMessage = "当前书籍不可用，无法新增关系。"
            return
        }
        clearCreationState()
        isCreating = true
        statusMessage = nil
        targetSearchState = .loading
        scheduleTargetSearch(delay: nil, appending: false)
    }

    func cancelCreate() {
        guard isCreating else { return }
        clearCreationState()
        statusMessage = "已取消新增关系；书库未更改。"
    }

    func updateTargetSearchText(
        _ text: String,
        delay: Duration? = .milliseconds(250)
    ) {
        guard isCreating else { return }
        guard targetSearchText != text else { return }
        targetSearchText = text
        targetQuery.searchText = text
        targetQuery.offset = 0
        selectedTargetID = nil
        scheduleTargetSearch(delay: delay, appending: false)
    }

    func retryTargetSearch() {
        guard isCreating else { return }
        targetQuery.offset = 0
        scheduleTargetSearch(delay: nil, appending: false)
    }

    func loadMoreTargets() {
        guard canLoadMoreTargets else { return }
        targetQuery.offset = nextTargetOffset
        scheduleTargetSearch(delay: nil, appending: true)
    }

    func selectTarget(_ id: UUID?) {
        guard let id else {
            selectedTargetID = nil
            return
        }
        guard id != currentBookID else {
            creationErrorMessage = "不能选择当前书籍作为关系目标。"
            return
        }
        guard targetBooks.contains(where: { $0.id == id }) else {
            creationErrorMessage = "目标搜索结果已改变；请重新选择。"
            return
        }
        selectedTargetID = id
        creationErrorMessage = nil
    }

    func selectFirstTargetFromKeyboard() {
        guard let target = targetBooks.first else {
            creationErrorMessage = "当前没有可选择的目标书籍。"
            return
        }
        selectTarget(target.id)
    }

    func setKind(_ kind: ManualRelationKind) {
        selectedKind = kind
        creationErrorMessage = nil
    }

    func setNote(_ note: String) {
        relationNote = note
    }

    @discardableResult
    func saveCreation() async -> Bool {
        guard isCreating,
              let sourceBookID = currentBookID,
              let target = selectedTarget
        else {
            creationErrorMessage = "请选择一本目标书籍。"
            return false
        }
        guard let access else {
            creationErrorMessage = "书库当前不可用；关系未保存。"
            return false
        }

        let generation = loadGeneration
        isSaving = true
        creationErrorMessage = nil
        do {
            let relation = try ManualBookRelation(
                sourceBookID: sourceBookID,
                targetBookID: target.id,
                kind: selectedKind,
                note: relationNote
            )
            _ = try await access.add(relation)
            guard isCurrentContext(bookID: sourceBookID, generation: generation) else {
                return false
            }
            clearCreationState()
            load(bookID: sourceBookID)
            let pendingLoad = loadTask
            await pendingLoad?.value
            guard currentBookID == sourceBookID else { return true }
            statusMessage = loadState == .content
                ? "手动关系已保存。"
                : "手动关系已保存，但列表刷新失败；可以重试读取。"
            return true
        } catch DomainValidationError.selfRelation {
            guard isCurrentContext(bookID: sourceBookID, generation: generation) else {
                return false
            }
            creationErrorMessage = "不能把当前书籍关联到自身。"
        } catch CatalogServiceError.manualRelationConflict {
            guard isCurrentContext(bookID: sourceBookID, generation: generation) else {
                return false
            }
            creationErrorMessage = "相同方向和类型的关系已存在；书库未更改。"
        } catch CatalogServiceError.manualRelationEndpointMissing {
            guard isCurrentContext(bookID: sourceBookID, generation: generation) else {
                return false
            }
            creationErrorMessage = "源书籍或目标书籍已不存在；请重新搜索。"
        } catch {
            guard isCurrentContext(bookID: sourceBookID, generation: generation) else {
                return false
            }
            creationErrorMessage = "未能保存手动关系；书库未更改。"
        }
        isSaving = false
        return false
    }

    func beginDelete(_ relation: ManualRelationSummary) {
        guard allRelations.contains(where: { $0.id == relation.id }) else {
            deletionErrorMessage = "当前关系已发生变化；请重新读取。"
            return
        }
        deletionCandidate = relation
        deletionErrorMessage = nil
    }

    func cancelDelete() {
        deletionCandidate = nil
    }

    @discardableResult
    func confirmDelete() async -> Bool {
        guard let candidate = deletionCandidate else {
            deletionErrorMessage = "当前关系已发生变化；请重新读取。"
            return false
        }
        return await confirmDelete(candidate)
    }

    @discardableResult
    func confirmDelete(_ candidate: ManualRelationSummary) async -> Bool {
        guard let bookID = currentBookID,
              allRelations.contains(where: { $0.id == candidate.id })
        else {
            deletionCandidate = nil
            deletionErrorMessage = "当前关系已发生变化；请重新读取。"
            return false
        }
        guard let access else {
            deletionCandidate = nil
            deletionErrorMessage = "书库当前不可用；关系未删除。"
            return false
        }

        let generation = loadGeneration
        deletionCandidate = nil
        isDeleting = true
        deletionErrorMessage = nil
        do {
            try await access.delete(candidate.relation)
            guard isCurrentContext(bookID: bookID, generation: generation) else {
                return false
            }
            load(bookID: bookID)
            let pendingLoad = loadTask
            await pendingLoad?.value
            guard currentBookID == bookID else { return true }
            statusMessage = loadState == .content
                ? "手动关系已删除；两本书均保留。"
                : "手动关系已删除，但列表刷新失败；可以重试读取。"
            return true
        } catch CatalogServiceError.manualRelationNotFound {
            guard isCurrentContext(bookID: bookID, generation: generation) else {
                return false
            }
            deletionErrorMessage = "该关系已不存在；两本书均未更改。"
        } catch {
            guard isCurrentContext(bookID: bookID, generation: generation) else {
                return false
            }
            deletionErrorMessage = "未能删除手动关系；两本书均未更改。"
        }
        isDeleting = false
        return false
    }

    func navigationTarget(for relation: ManualRelationSummary) -> UUID? {
        guard currentBookID != nil,
              allRelations.contains(where: { $0.id == relation.id })
        else {
            deletionErrorMessage = "当前关系已发生变化；请重新读取。"
            return nil
        }
        return relation.otherBookID
    }

    func dismissMessages() {
        statusMessage = nil
        deletionErrorMessage = nil
    }

    func waitForPendingWork() async {
        await loadTask?.value
        await searchTask?.value
    }

    private func scheduleTargetSearch(delay: Duration?, appending: Bool) {
        guard let access, let bookID = currentBookID, isCreating else {
            targetSearchState = .failed
            return
        }
        searchGeneration &+= 1
        let generation = searchGeneration
        searchTask?.cancel()
        var query = targetQuery
        query.limit = LibraryQuery.defaultPageSize
        query.offset = appending ? nextTargetOffset : 0
        if appending {
            isLoadingMoreTargets = true
            targetLoadMoreFailed = false
        } else {
            targetBooks = []
            targetTotalCount = 0
            hasMoreTargets = false
            nextTargetOffset = 0
            targetSearchState = .loading
            isLoadingMoreTargets = false
            targetLoadMoreFailed = false
        }

        searchTask = Task { @MainActor [weak self] in
            do {
                if let delay {
                    try await Task.sleep(for: delay)
                }
                let page = try await access.targetPage(
                    matching: query,
                    excludingBookID: bookID
                )
                try Task.checkCancellation()
                guard let self,
                      self.isCurrentSearch(
                          bookID: bookID,
                          generation: generation
                      ),
                      page.offset == query.offset,
                      page.books.allSatisfy({ $0.id != bookID })
                else { return }

                if appending {
                    let existingIDs = Set(self.targetBooks.map(\.id))
                    guard page.books.allSatisfy({ !existingIDs.contains($0.id) }) else {
                        self.targetLoadMoreFailed = true
                        self.isLoadingMoreTargets = false
                        return
                    }
                    self.targetBooks.append(contentsOf: page.books)
                } else {
                    self.targetBooks = page.books
                }
                self.targetTotalCount = page.totalCount
                self.hasMoreTargets = page.hasMore
                self.nextTargetOffset = page.offset + page.books.count
                self.targetSearchState = .content
                self.isLoadingMoreTargets = false
                self.targetLoadMoreFailed = false
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      self.isCurrentSearch(
                          bookID: bookID,
                          generation: generation
                      )
                else { return }
                if appending {
                    self.targetLoadMoreFailed = true
                } else {
                    self.targetBooks = []
                    self.targetTotalCount = 0
                    self.hasMoreTargets = false
                    self.targetSearchState = .failed
                }
                self.isLoadingMoreTargets = false
            }
        }
    }

    private func clearCreationState() {
        searchGeneration &+= 1
        searchTask?.cancel()
        searchTask = nil
        isCreating = false
        targetSearchText = ""
        targetSearchState = .idle
        targetBooks = []
        targetTotalCount = 0
        hasMoreTargets = false
        isLoadingMoreTargets = false
        targetLoadMoreFailed = false
        selectedTargetID = nil
        selectedKind = .related
        relationNote = ""
        isSaving = false
        creationErrorMessage = nil
        targetQuery = LibraryQuery()
        nextTargetOffset = 0
    }

    private func isCurrentLoad(bookID: UUID, generation: UInt64) -> Bool {
        !Task.isCancelled
            && currentBookID == bookID
            && loadGeneration == generation
    }

    private func isCurrentContext(bookID: UUID, generation: UInt64) -> Bool {
        currentBookID == bookID && loadGeneration == generation
    }

    private func isCurrentSearch(bookID: UUID, generation: UInt64) -> Bool {
        !Task.isCancelled
            && isCreating
            && currentBookID == bookID
            && searchGeneration == generation
    }
}

extension ManualRelationKind {
    var userFacingTitle: String {
        switch self {
        case .related: "相关"
        case .inspiredBy: "受其启发"
        case .respondsTo: "回应"
        case .companion: "伴读"
        }
    }
}

extension ManualRelationDirection {
    var userFacingTitle: String {
        switch self {
        case .outgoing: "传出"
        case .incoming: "传入"
        }
    }
}
