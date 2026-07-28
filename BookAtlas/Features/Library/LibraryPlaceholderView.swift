import SwiftUI

struct LibraryView: View {
    @ObservedObject var store: LibraryStore
    let onShowGraph: (UUID) -> Void
    @State private var showsManagement = false
    @State private var membershipBook: Book?

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
        .searchable(
            text: Binding(
                get: { store.query.searchText },
                set: { value in store.updateSearchText(value) }
            ),
            placement: .toolbar,
            prompt: Text("搜索书名、原书名、作者或 ISBN")
        )
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
                if store.hasActiveFilters {
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
                    List(selection: $store.selectedBookID) {
                        ForEach(store.books) { book in
                            LibraryBookRow(book: book)
                                .tag(book.id)
                                .accessibilityIdentifier("library-book-\(book.id.uuidString)")
                        }
                    }
                    .listStyle(.inset)
                    .frame(minWidth: 250, idealWidth: 310, maxWidth: 390)
                    .accessibilityIdentifier("library-book-list")

                    Divider()

                    if let book = store.selectedBook {
                        BookDetailView(book: book, onShowGraph: onShowGraph)
                    } else {
                        ContentUnavailableView(
                            "选择一本书",
                            systemImage: "book.closed",
                            description: Text("使用方向键或列表选择书籍以查看详情。")
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct LibraryFilterBar: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        HStack(spacing: 10) {
            filterMenu
            sortMenu

            if store.hasActiveFilters {
                Text(filterSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityIdentifier("active-filter-summary")
                Button("清除", action: store.clearFilters)
                    .controlSize(.small)
                    .accessibilityIdentifier("clear-filters-button")
            } else {
                Text("全部书籍")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(book.readingStatus.displayTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let priority = book.priority {
                    Text("优先级 \(priority.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(book.updatedAt, format: .dateTime.year().month().day())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
