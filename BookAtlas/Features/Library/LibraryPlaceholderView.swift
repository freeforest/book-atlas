import SwiftUI

struct LibraryView: View {
    @ObservedObject var store: LibraryStore

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
    }

    @ViewBuilder
    private var libraryContent: some View {
        if store.books.isEmpty {
            ContentUnavailableView {
                Label("书库尚无内容", systemImage: "books.vertical")
            } description: {
                Text("新增第一本书后，可以在这里查看和维护书目。")
            } actions: {
                Button("新增书籍", action: store.beginCreate)
            }
            .accessibilityIdentifier("library-empty-state")
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
                    BookDetailView(book: book)
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
