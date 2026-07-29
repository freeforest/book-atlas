import SwiftUI

struct BookDetailView: View {
    let book: Book
    @ObservedObject var readingEntries: ReadingEntryStore
    var onShowGraph: ((UUID) -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.title2.weight(.semibold))
                        .accessibilityIdentifier("book-detail-title")
                        .accessibilityLabel(book.title)
                    Text(book.author)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    if let onShowGraph {
                        Button("查看局部书图", systemImage: "point.3.connected.trianglepath.dotted") {
                            onShowGraph(book.id)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("show-local-graph-button")
                    }
                }

                GroupBox("书目信息") {
                    DetailFields {
                        DetailField("阅读状态", value: book.readingStatus.displayTitle)
                        if let priority = book.priority {
                            DetailField("优先级", value: "\(priority.rawValue)")
                        }
                        if let originalTitle = book.originalTitle {
                            DetailField("原书名", value: originalTitle)
                        }
                        if let isbn = book.isbn {
                            DetailField("ISBN", value: isbn)
                        }
                        if let publisher = book.publisher {
                            DetailField("出版社", value: publisher)
                        }
                        if let publicationDate = book.publicationDate {
                            DetailField("出版日期", value: publicationDate.storageValue)
                        }
                    }
                }

                if let note = book.note {
                    GroupBox("备注") {
                        Text(note)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }

                ReadingEntriesSection(book: book, store: readingEntries)

                GroupBox("时间") {
                    DetailFields {
                        DetailField("添加时间", value: displayTimestamp(book.createdAt))
                        DetailField("修改时间", value: displayTimestamp(book.updatedAt))
                        if let startedAt = book.startedAt {
                            DetailField("开始阅读", value: displayTimestamp(startedAt))
                        }
                        if let finishedAt = book.finishedAt {
                            DetailField("完成阅读", value: displayTimestamp(finishedAt))
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 720, alignment: .leading)
        }
        .accessibilityIdentifier("book-detail-view")
        .task(id: book.id) {
            readingEntries.load(bookID: book.id)
        }
    }
}

private struct ReadingEntriesSection: View {
    let book: Book
    @ObservedObject var store: ReadingEntryStore
    @State private var editedLink: ExternalLink?
    @State private var showsLinkEditor = false
    @State private var linkToDelete: ExternalLink?
    @State private var fileToDelete: LocalFileReference?
    @State private var confirmsAppleBooksFallback = false

    var body: some View {
        GroupBox("阅读入口") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Book Atlas 只保存并打开你主动配置的外部入口，不是内置阅读器。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if store.webLinks.isEmpty, store.localFiles.isEmpty {
                    ContentUnavailableView {
                        Label("尚无阅读入口", systemImage: "arrow.up.right.square")
                    } description: {
                        Text("可以添加经过验证的 HTTPS 链接，或主动选择一个本地文件。")
                    }
                    .accessibilityIdentifier("reading-entry-empty")
                }

                ForEach(store.webLinks) { link in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(link.label ?? "HTTPS 阅读链接")
                                .accessibilityIdentifier(
                                    "reading-link-label-\(link.id.uuidString)"
                                )
                            Text(safeHost(for: link))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier(
                                    "reading-link-host-\(link.id.uuidString)"
                                )
                        }
                        Spacer()
                        Button("打开") {
                            Task { await store.openWebLink(link) }
                        }
                        .accessibilityIdentifier("open-reading-link-\(link.id.uuidString)")
                        Button("编辑") {
                            editedLink = link
                            showsLinkEditor = true
                        }
                        .accessibilityIdentifier("edit-reading-link-\(link.id.uuidString)")
                        Button("删除", role: .destructive) {
                            linkToDelete = link
                        }
                        .accessibilityIdentifier("delete-reading-link-\(link.id.uuidString)")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(
                        "\(link.label ?? "HTTPS 阅读链接")，主机 \(safeHost(for: link))"
                    )
                    .accessibilityIdentifier("reading-link-row-\(link.id.uuidString)")
                }

                ForEach(store.localFiles) { reference in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reference.displayName)
                                .accessibilityIdentifier(
                                    "local-file-name-\(reference.id.uuidString)"
                                )
                            Text("本地只读文件引用")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("打开") {
                            Task { await store.openLocalFile(reference) }
                        }
                        .accessibilityIdentifier("open-local-file-\(reference.id.uuidString)")
                        Button("重新选择") {
                            Task { await store.reselectLocalFile(reference) }
                        }
                        .accessibilityIdentifier("reselect-local-file-\(reference.id.uuidString)")
                        Button("移除", role: .destructive) {
                            fileToDelete = reference
                        }
                        .accessibilityIdentifier("remove-local-file-\(reference.id.uuidString)")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("\(reference.displayName)，本地只读文件引用")
                    .accessibilityIdentifier("local-file-row-\(reference.id.uuidString)")
                }

                HStack {
                    Button("添加 HTTPS 链接…", systemImage: "link.badge.plus") {
                        editedLink = nil
                        showsLinkEditor = true
                    }
                    .accessibilityIdentifier("add-reading-link")
                    Button("选择本地文件…", systemImage: "doc.badge.plus") {
                        Task { await store.chooseLocalFile(for: book.id) }
                    }
                    .accessibilityIdentifier("choose-local-file")
                }

                Divider()

                Text("Apple Books 不支持精确跳转到私人资料库项目。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("apple-books-capability-note")
                HStack {
                    Button("尝试 Apple Books 入口…", systemImage: "books.vertical") {
                        confirmsAppleBooksFallback = true
                    }
                    .accessibilityIdentifier("apple-books-fallback")
                    if let isbn = book.isbn {
                        Button("复制 ISBN") {
                            store.copyISBN(isbn)
                        }
                        .accessibilityIdentifier("copy-book-isbn")
                    }
                    Button("复制书名") {
                        store.copyTitle(book.title)
                    }
                    .accessibilityIdentifier("copy-book-title")
                }

                if let message = store.statusMessage {
                    Label(message, systemImage: "checkmark.circle")
                        .font(.caption)
                        .accessibilityIdentifier("reading-entry-status")
                }
                if let message = store.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("reading-entry-error")
                }
            }
            .padding(.vertical, 6)
        }
        .accessibilityIdentifier("reading-entries-section")
        .sheet(isPresented: $showsLinkEditor) {
            ReadingLinkEditorSheet(
                bookID: book.id,
                link: editedLink,
                store: store
            )
        }
        .confirmationDialog(
            "删除这个 HTTPS 阅读入口？",
            isPresented: Binding(
                get: { linkToDelete != nil },
                set: { if !$0 { linkToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let linkToDelete {
                Button("删除", role: .destructive) {
                    let link = linkToDelete
                    self.linkToDelete = nil
                    Task { await store.deleteWebLink(link) }
                }
                .accessibilityIdentifier("confirm-delete-reading-link")
            }
            Button("取消", role: .cancel) { linkToDelete = nil }
        } message: {
            Text("只移除 Book Atlas 中的引用，不会访问或修改目标网站。")
        }
        .confirmationDialog(
            "移除这个本地文件引用？",
            isPresented: Binding(
                get: { fileToDelete != nil },
                set: { if !$0 { fileToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let fileToDelete {
                Button("移除引用", role: .destructive) {
                    let reference = fileToDelete
                    self.fileToDelete = nil
                    Task { await store.deleteLocalFile(reference) }
                }
                .accessibilityIdentifier("confirm-remove-local-file")
            }
            Button("取消", role: .cancel) { fileToDelete = nil }
        } message: {
            Text("原文件不会被删除或修改。")
        }
        .confirmationDialog(
            "把搜索词交给外部系统？",
            isPresented: $confirmsAppleBooksFallback,
            titleVisibility: .visible
        ) {
            Button("继续") {
                Task { await store.performAppleBooksFallback(for: book) }
            }
            .accessibilityIdentifier("confirm-apple-books-fallback")
            Button("取消", role: .cancel) {}
        } message: {
            Text(
                "将按已保存 Apple Books 商店页、公开搜索、启动应用、复制 ISBN、"
                    + "复制书名、其他 HTTPS 链接的顺序降级。搜索词可能由外部应用处理。"
            )
        }
    }

    private func safeHost(for link: ExternalLink) -> String {
        (try? store.validator.validate(link.value).safeHost) ?? "无效 HTTPS 主机"
    }
}

private struct ReadingLinkEditorSheet: View {
    let bookID: UUID
    let link: ExternalLink?
    @ObservedObject var store: ReadingEntryStore
    @Environment(\.dismiss) private var dismiss
    @State private var label: String
    @State private var value: String
    @State private var validationMessage: String?

    init(bookID: UUID, link: ExternalLink?, store: ReadingEntryStore) {
        self.bookID = bookID
        self.link = link
        self.store = store
        _label = State(initialValue: link?.label ?? "")
        _value = State(initialValue: link?.value ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(link == nil ? "添加 HTTPS 阅读链接" : "编辑 HTTPS 阅读链接")
                .font(.title2.bold())
                .accessibilityIdentifier("reading-link-editor")
            TextField("显示名称（可选）", text: $label)
                .accessibilityIdentifier("reading-link-label")
            TextField("https://…", text: $value)
                .accessibilityIdentifier("reading-link-value")
            Text("仅允许可确定显示主机的 HTTPS。HTTP、file、ibooks 和其他 Scheme 会被拒绝。")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let validationMessage {
                Text(validationMessage)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("reading-link-validation")
            }
            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("cancel-reading-link")
                Spacer()
                Button("保存") {
                    Task {
                        if await store.saveWebLink(
                            id: link?.id,
                            bookID: bookID,
                            label: label,
                            rawValue: value
                        ) {
                            dismiss()
                        } else {
                            validationMessage = store.errorMessage
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("save-reading-link")
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}

private struct DetailFields<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
            content
        }
        .padding(.vertical, 4)
    }
}

private struct DetailField: View {
    let label: String
    let value: String

    init(_ label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}

private func displayTimestamp(_ date: Date) -> String {
    date.formatted(date: .abbreviated, time: .shortened)
}
