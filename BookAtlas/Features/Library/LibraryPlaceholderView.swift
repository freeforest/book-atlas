import SwiftUI

struct LibraryListSelectionState: Equatable {
    enum Source: Equatable {
        case store
        case list
    }

    private(set) var selectedBookID: UUID?
    private(set) var source: Source = .store
    private(set) var generation = 0

    mutating func synchronizeFromStore(_ id: UUID?) {
        guard selectedBookID != id else {
            return
        }
        selectedBookID = id
        source = .store
        generation &+= 1
    }

    mutating func selectFromList(_ id: UUID?) {
        guard selectedBookID != id else {
            return
        }
        selectedBookID = id
        source = .list
        generation &+= 1
    }
}

struct LibraryView: View {
    @ObservedObject var store: LibraryStore
    let onShowGraph: (UUID) -> Void
    @State private var showsManagement = false
    @State private var membershipBook: Book?
    @State private var listSelection = LibraryListSelectionState()

    var body: some View {
        Group {
            switch store.loadingState {
            case .loading:
                ProgressView("正在载入书库…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("library-loading")
            case let .failed(error):
                ErrorPlaceholderView(title: error.title, message: error.message)
                    .overlay(alignment: .bottom) {
                        Button("重试", action: store.load)
                            .padding(.bottom, 36)
                    }
                    .accessibilityIdentifier("library-load-error")
            case .content:
                libraryContent
            }
        }
        .navigationTitle("书库")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("管理标签、书单和来源", systemImage: "slider.horizontal.3") {
                    showsManagement = true
                }
                .accessibilityIdentifier("catalog-management-button")
                Button("整理所选书籍", systemImage: "tray.full") {
                    membershipBook = store.selectedBook
                }
                .disabled(!store.hasSelection)
                .accessibilityIdentifier("book-membership-button")
                Button("检查重复书籍", systemImage: "square.on.square") {
                    store.reviewSelectedBookForDuplicates()
                }
                .disabled(!store.hasSelection || store.isDuplicateOperationInProgress)
                .accessibilityIdentifier("review-duplicates-button")
                Button("新增书籍", systemImage: "plus", action: store.beginCreate)
                    .accessibilityIdentifier("new-book-button")
                Button("编辑书籍", systemImage: "pencil", action: store.beginEdit)
                    .disabled(!store.hasSelection)
                    .accessibilityIdentifier("edit-book-button")
                Button("删除书籍", systemImage: "trash", action: store.beginDelete)
                    .disabled(!store.hasSelection)
                    .accessibilityIdentifier("delete-book-button")
            }
        }
        .sheet(item: $store.editorSession) { session in
            BookEditorSheet(session: session, store: store)
        }
        .sheet(
            item: Binding(
                get: { store.editorSession == nil ? store.duplicateReview : nil },
                set: { review in
                    if review == nil, store.editorSession == nil {
                        store.cancelDuplicateReview()
                    }
                }
            )
        ) { review in
            DuplicateReviewSheet(store: store, review: review)
        }
        .sheet(isPresented: $showsManagement) {
            CatalogManagementView(store: store)
        }
        .sheet(item: $membershipBook) { book in
            BookMembershipSheet(book: book, store: store)
        }
        .confirmationDialog(
            "删除这本书？",
            isPresented: Binding(
                get: { store.deletionCandidate != nil },
                set: { isPresented in
                    if !isPresented {
                        store.cancelDelete()
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: store.deletionCandidate
        ) { _ in
            Button("删除", role: .destructive, action: store.confirmDelete)
                .accessibilityIdentifier("confirm-delete-book")
            Button("取消", role: .cancel, action: store.cancelDelete)
                .accessibilityIdentifier("cancel-delete-book")
        } message: { book in
            Text("“\(book.title)”将从本机书库中移除。")
        }
        .alert(
            store.operationError?.title ?? "",
            isPresented: Binding(
                get: { store.operationError != nil },
                set: { isPresented in
                    if !isPresented {
                        store.dismissOperationError()
                    }
                }
            )
        ) {
            Button("好", action: store.dismissOperationError)
        } message: {
            Text(store.operationError?.message ?? "")
        }
        .onDeleteCommand(perform: store.beginDelete)
        .task {
            store.organizer.load()
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
        VStack(spacing: 0) {
            LibraryFilterBar(store: store)
            Divider()

            if store.books.isEmpty {
                if let issue = store.selectionIssue {
                    LibrarySelectionIssueView(
                        issue: issue,
                        clearFilters: store.clearFilters
                    )
                } else if store.hasActiveFilters {
                    ContentUnavailableView {
                        Label("没有匹配的书籍", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text("当前搜索或筛选条件没有结果，可以清除条件后重试。")
                    } actions: {
                        Button("清除筛选", action: store.clearFilters)
                            .accessibilityIdentifier("clear-filters-empty-state")
                    }
                    .accessibilityIdentifier("library-no-results")
                } else {
                    ContentUnavailableView {
                        Label("书库尚无内容", systemImage: "books.vertical")
                    } description: {
                        Text("新增第一本书后，可以在这里查看和维护书目。")
                    } actions: {
                        Button("新增书籍", action: store.beginCreate)
                    }
                    .accessibilityIdentifier("library-empty-state")
                }
            } else {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        if let focusedBook = store.pinnedFocusedBook {
                            GroupBox("已定位书籍") {
                                Button {
                                    store.selectBook(focusedBook.id)
                                } label: {
                                    LibraryBookRow(book: focusedBook)
                                        .frame(
                                            maxWidth: .infinity,
                                            alignment: .leading
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier(
                                    "library-book-\(focusedBook.id.uuidString)"
                                )
                            }
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                            .accessibilityIdentifier(
                                "library-focused-book-section"
                            )
                        }
                        List(
                            selection: Binding(
                                get: { listSelection.selectedBookID },
                                set: { listSelection.selectFromList($0) }
                            )
                        ) {
                            ForEach(store.books) { book in
                                LibraryBookRow(book: book)
                                    .tag(book.id)
                                    .accessibilityIdentifier("library-book-\(book.id.uuidString)")
                            }
                        }
                        .listStyle(.inset)
                        .accessibilityIdentifier("library-book-list")
                        .onChange(of: listSelection.generation) {
                            guard listSelection.source == .list,
                                  listSelection.selectedBookID
                                    != store.selectedBookID
                            else {
                                return
                            }
                            store.selectBook(listSelection.selectedBookID)
                        }
                        .onChange(
                            of: store.selectedBookID,
                            initial: true
                        ) { _, selectedBookID in
                            listSelection.synchronizeFromStore(selectedBookID)
                        }

                        Divider()
                        LibraryPaginationFooter(store: store)
                    }
                    .frame(minWidth: 250, idealWidth: 310, maxWidth: 390)

                    Divider()

                    if let book = store.selectedBook {
                        BookDetailView(
                            book: book,
                            readingEntries: store.readingEntries,
                            onShowGraph: onShowGraph
                        )
                    } else if let issue = store.selectionIssue {
                        LibrarySelectionIssueView(
                            issue: issue,
                            clearFilters: store.clearFilters
                        )
                    } else if store.isQuerying {
                        ContentUnavailableView(
                            "正在定位书籍",
                            systemImage: "scope",
                            description: Text("正在读取本地书库中的目标记录。")
                        )
                        .accessibilityIdentifier("library-selection-loading")
                    } else {
                        LibrarySelectionEmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct LibrarySelectionEmptyView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.primary)
                .accessibilityHidden(true)

            (
                Text("选择一本书")
                    .font(.title2)
                    .fontWeight(.semibold)
                + Text("\n\n")
                + Text("使用方向键或列表选择书籍以查看详情。")
                    .font(.body)
            )
                .foregroundStyle(.primary)
                .accessibilityLabel("选择一本书")
                .accessibilityValue("使用方向键或列表选择书籍以查看详情。")
                .accessibilityIdentifier("library-selection-empty")
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}

private struct LibrarySelectionIssueView: View {
    let issue: LibrarySelectionIssue
    let clearFilters: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ContentUnavailableView {
                Label(issue.title, systemImage: "book.closed")
            } description: {
                Text(issue.message)
            }
            .accessibilityIdentifier("library-selection-unavailable")

            if issue == .outsideCurrentResults {
                Button("清除搜索和筛选", action: clearFilters)
                    .accessibilityIdentifier(
                        "clear-filters-selection-issue"
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LibraryPaginationFooter: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(store.resultCountDescription)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .accessibilityLabel("书库结果数量")
                    .accessibilityValue(store.accessibleResultDescription)
                    .accessibilityIdentifier("library-result-count")

                Spacer(minLength: 4)

                if store.isLoadingMore {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("正在载入更多书籍")
                } else if store.hasMoreBooks {
                    Button(
                        store.loadMoreError == nil ? "加载更多" : "重试",
                        action: store.loadMore
                    )
                    .controlSize(.small)
                    .accessibilityLabel(
                        store.loadMoreError == nil
                            ? "加载更多书籍"
                            : "重试载入更多书籍"
                    )
                    .accessibilityValue(store.accessibleResultDescription)
                    .accessibilityHint("载入下一页，已显示的结果会保留")
                    .accessibilityIdentifier("library-load-more-button")
                } else {
                    Text("已全部显示")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("library-all-results-loaded")
                }
            }

            if store.loadMoreError != nil {
                Text("载入下一页失败；已显示结果未更改。")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("library-load-more-error")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

private struct LibraryFilterBar: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        HStack(spacing: 10) {
            LibrarySearchField(
                text: Binding(
                    get: { store.query.searchText },
                    set: { value in
                        store.updateSearchText(value)
                    }
                ),
                focusRequestID: store.searchFocusRequestID
            )
            .frame(minWidth: 180, idealWidth: 260, maxWidth: 320)

            filterMenu
            sortMenu

            if store.hasActiveFilters {
                Text(filterSummary)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .accessibilityIdentifier("active-filter-summary")
                Button("清除", action: store.clearFilters)
                    .controlSize(.small)
                    .accessibilityIdentifier("clear-filters-button")
            } else {
                Text("全部书籍")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("library-all-books-summary")
            }

            Spacer()
            if store.isQuerying {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("正在更新结果")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var filterMenu: some View {
        Menu("筛选", systemImage: "line.3.horizontal.decrease.circle") {
            Section("阅读状态（任一）") {
                ForEach(ReadingStatus.allCases, id: \.self) { status in
                    filterButton(
                        status.displayTitle,
                        selected: store.query.readingStatuses.contains(status)
                    ) {
                        store.toggleReadingStatus(status)
                    }
                }
            }
            Section("标签（全部）") {
                if store.organizer.snapshot.tags.isEmpty {
                    Text("尚无标签")
                } else {
                    ForEach(store.organizer.snapshot.tags) { summary in
                        filterButton(
                            summary.tag.name,
                            selected: store.query.tagIDs.contains(summary.id)
                        ) {
                            store.toggleTag(summary.id)
                        }
                    }
                }
            }
            Section("书单（全部）") {
                if store.organizer.snapshot.collections.isEmpty {
                    Text("尚无书单")
                } else {
                    ForEach(store.organizer.snapshot.collections) { summary in
                        filterButton(
                            summary.collection.name,
                            selected: store.query.collectionIDs.contains(summary.id)
                        ) {
                            store.toggleCollection(summary.id)
                        }
                    }
                }
            }
            Section("来源（全部）") {
                if store.organizer.snapshot.sources.isEmpty {
                    Text("尚无来源")
                } else {
                    ForEach(store.organizer.snapshot.sources) { summary in
                        filterButton(
                            summary.source.name,
                            selected: store.query.sourceIDs.contains(summary.id)
                        ) {
                            store.toggleSource(summary.id)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("library-filter-menu")
    }

    private var sortMenu: some View {
        Menu("排序", systemImage: "arrow.up.arrow.down") {
            sortButton("添加时间：新到旧", field: .createdAt, direction: .descending)
            sortButton("添加时间：旧到新", field: .createdAt, direction: .ascending)
            sortButton("修改时间：新到旧", field: .updatedAt, direction: .descending)
            sortButton("修改时间：旧到新", field: .updatedAt, direction: .ascending)
            sortButton("优先级：高到低", field: .priority, direction: .descending)
            sortButton("优先级：低到高", field: .priority, direction: .ascending)
        }
        .accessibilityIdentifier("library-sort-menu")
    }

    private var filterSummary: String {
        var values: [String] = []
        if !store.query.normalizedSearchText.isEmpty {
            values.append("搜索")
        }
        if !store.query.readingStatuses.isEmpty {
            values.append("状态 \(store.query.readingStatuses.count)")
        }
        if !store.query.tagIDs.isEmpty {
            values.append("标签 \(store.query.tagIDs.count)")
        }
        if !store.query.collectionIDs.isEmpty {
            values.append("书单 \(store.query.collectionIDs.count)")
        }
        if !store.query.sourceIDs.isEmpty {
            values.append("来源 \(store.query.sourceIDs.count)")
        }
        return values.joined(separator: " · ")
    }

    private func filterButton(
        _ title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: selected ? "checkmark" : "circle")
        }
    }

    private func sortButton(
        _ title: String,
        field: LibrarySortField,
        direction: LibrarySortDirection
    ) -> some View {
        Button {
            store.setSort(field: field, direction: direction)
        } label: {
            if store.query.sortField == field, store.query.sortDirection == direction {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}

private struct LibraryBookRow: View {
    let book: Book

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .lineLimit(1)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(book.readingStatus.displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                if let priority = book.priority {
                    Text("优先级 \(priority.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.primary)
                } else {
                    Text(book.updatedAt, format: .dateTime.year().month().day())
                        .font(.caption2)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

extension ReadingStatus {
    var displayTitle: String {
        switch self {
        case .wishToRead: "想读"
        case .reading: "在读"
        case .read: "读过"
        case .paused: "暂停"
        case .abandoned: "搁置"
        case .reference: "参考"
        case .archived: "归档"
        }
    }
}
