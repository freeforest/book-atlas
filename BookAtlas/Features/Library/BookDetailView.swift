import SwiftUI

enum ReadingEntryPresentationMode {
    case manage
    case readOnly
}

struct BookDetailView: View {
    let book: Book
    @ObservedObject var readingEntries: ReadingEntryStore
    var readingEntryMode: ReadingEntryPresentationMode = .manage
    var manualRelations: ManualRelationStore? = nil
    var onShowGraph: ((UUID) -> Void)? = nil
    var onOpenRelatedBook: ((UUID) -> Void)? = nil

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

                if let manualRelations {
                    ManualRelationsSection(
                        book: book,
                        store: manualRelations,
                        openBook: onOpenRelatedBook
                    )
                }

                ReadingEntriesSection(
                    book: book,
                    store: readingEntries,
                    mode: readingEntryMode
                )

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
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("book-detail-view")
        }
        .accessibilityIdentifier("book-detail-scroll")
        .task(id: book.id) {
            readingEntries.load(bookID: book.id)
            manualRelations?.load(bookID: book.id)
        }
        .onDisappear {
            if manualRelations?.currentBookID == book.id {
                manualRelations?.reset()
            }
        }
    }
}

private struct ManualRelationsSection: View {
    let book: Book
    @ObservedObject var store: ManualRelationStore
    let openBook: ((UUID) -> Void)?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                switch store.loadState {
                case .idle, .loading:
                    ProgressView("正在读取手动关系…")
                        .accessibilityIdentifier("manual-relations-loading")
                case .failed:
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            "无法读取手动关系；书籍记录未被更改。",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("manual-relations-load-error")
                        Button("重试读取", action: store.retryLoad)
                            .accessibilityIdentifier("retry-manual-relations")
                    }
                case .content:
                    if store.allRelations.isEmpty {
                        VStack(spacing: 8) {
                            Label("尚无手动关系", systemImage: "link")
                            Text("可以主动选择另一本文献，建立有方向、可删除的关系。")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            "尚无手动关系。可以主动选择另一本文献，建立有方向、可删除的关系。"
                        )
                        .accessibilityIdentifier("manual-relations-empty")
                    } else {
                        relationGroup(
                            title: "传出关系",
                            emptyText: "没有从当前书籍传出的关系。",
                            relations: store.outgoingRelations
                        )
                        Divider()
                        relationGroup(
                            title: "传入关系",
                            emptyText: "没有指向当前书籍的关系。",
                            relations: store.incomingRelations
                        )
                    }
                }

                if let statusMessage = store.statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle")
                        .font(.caption)
                        .accessibilityIdentifier("manual-relation-status")
                }
                if let deletionErrorMessage = store.deletionErrorMessage {
                    Label(deletionErrorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("manual-relation-delete-error")
                }
            }
            .padding(.vertical, 6)
        } label: {
            HStack {
                Label("手动关系", systemImage: "point.3.connected.trianglepath.dotted")
                Spacer()
                Button("新增关系…", systemImage: "plus") {
                    store.beginCreate()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(store.loadState != .content || store.isDeleting || store.isSaving)
                .accessibilityIdentifier("add-manual-relation")
            }
        }
        .accessibilityIdentifier("manual-relations-section")
        .sheet(
            isPresented: Binding(
                get: { store.isCreating },
                set: { if !$0 { store.cancelCreate() } }
            )
        ) {
            ManualRelationEditorSheet(sourceBook: book, store: store)
        }
        .confirmationDialog(
            "删除这条手动关系？",
            isPresented: Binding(
                get: { store.deletionCandidate != nil },
                set: { if !$0 { store.cancelDelete() } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除关系", role: .destructive) {
                if let candidate = store.deletionCandidate {
                    Task { await store.confirmDelete(candidate) }
                }
            }
            .accessibilityIdentifier("confirm-delete-manual-relation")
            Button("取消", role: .cancel, action: store.cancelDelete)
                .accessibilityIdentifier("cancel-delete-manual-relation")
        } message: {
            Text("只删除关系记录，两本书都会保留。")
        }
    }

    @ViewBuilder
    private func relationGroup(
        title: String,
        emptyText: String,
        relations: [ManualRelationSummary]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .accessibilityIdentifier(
                    title == "传出关系"
                        ? "manual-relations-outgoing-heading"
                        : "manual-relations-incoming-heading"
                )
            if relations.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(relations) { relation in
                    relationRow(relation)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            title == "传出关系"
                ? "manual-relations-outgoing"
                : "manual-relations-incoming"
        )
    }

    private func relationRow(_ summary: ManualRelationSummary) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                guard let target = store.navigationTarget(for: summary) else { return }
                openBook?(target)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.otherBookTitle)
                        .fontWeight(.medium)
                    Text(summary.otherBookAuthor)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(
                        "\(summary.relation.kind.userFacingTitle) · "
                            + directionDescription(summary)
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if let note = summary.relation.note {
                        Text("备注：\(note)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .contentShape(Rectangle())
            .accessibilityLabel(accessibilityLabel(summary))
            .accessibilityHint("打开对端书籍详情")
            .accessibilityIdentifier(relationRowIdentifier(summary))

            Button("删除", systemImage: "trash", role: .destructive) {
                store.beginDelete(summary)
            }
            .labelStyle(.iconOnly)
            .accessibilityLabel("删除这条手动关系")
            .accessibilityHint("只删除关系记录，两本书都会保留")
            .accessibilityIdentifier(relationDeleteIdentifier(summary))
        }
        .accessibilityElement(children: .contain)
    }

    private func directionDescription(_ summary: ManualRelationSummary) -> String {
        switch summary.direction {
        case .outgoing:
            "方向：当前书籍 → 目标书籍"
        case .incoming:
            "方向：来源书籍 → 当前书籍"
        }
    }

    private func accessibilityLabel(_ summary: ManualRelationSummary) -> String {
        var values = [
            "\(summary.direction.userFacingTitle)关系",
            summary.otherBookTitle,
            "作者 \(summary.otherBookAuthor)",
            "类型 \(summary.relation.kind.userFacingTitle)",
            directionDescription(summary)
        ]
        if let note = summary.relation.note {
            values.append("备注 \(note)")
        }
        return values.joined(separator: "，")
    }

    private func relationRowIdentifier(_ summary: ManualRelationSummary) -> String {
        "manual-relation-row-\(summary.direction.identifierComponent)-"
            + "\(summary.otherBookID.uuidString)-\(summary.relation.kind.rawValue)"
    }

    private func relationDeleteIdentifier(_ summary: ManualRelationSummary) -> String {
        "delete-manual-relation-\(summary.direction.identifierComponent)-"
            + "\(summary.otherBookID.uuidString)-\(summary.relation.kind.rawValue)"
    }
}

private struct ManualRelationEditorSheet: View {
    let sourceBook: Book
    @ObservedObject var store: ManualRelationStore
    @FocusState private var searchIsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("新增手动关系")
                .font(.title2.bold())
                .accessibilityIdentifier("manual-relation-editor")
            Text("当前书籍固定为关系来源。搜索结果按确定性分页读取。")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                "按标题、作者或 ISBN 搜索目标书籍",
                text: Binding(
                    get: { store.targetSearchText },
                    set: { store.updateTargetSearchText($0) }
                )
            )
            .focused($searchIsFocused)
            .accessibilityHint("输入搜索条件后，按 Command-Return 选择第一个已显示结果")
            .accessibilityIdentifier("manual-relation-target-search")

            targetResults
                .frame(minHeight: 180, idealHeight: 220)

            Picker(
                "关系类型",
                selection: Binding(
                    get: { store.selectedKind },
                    set: { store.setKind($0) }
                )
            ) {
                ForEach(ManualRelationKind.allCases, id: \.rawValue) { kind in
                    Text(kind.userFacingTitle).tag(kind)
                }
            }
            .accessibilityIdentifier("manual-relation-kind")

            VStack(alignment: .leading, spacing: 4) {
                Text("备注（可选）")
                    .font(.caption)
                TextEditor(
                    text: Binding(
                        get: { store.relationNote },
                        set: { store.setNote($0) }
                    )
                )
                .frame(height: 70)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.quaternary)
                }
                .accessibilityLabel("关系备注（可选）")
                .accessibilityIdentifier("manual-relation-note")
            }

            if let target = store.selectedTarget {
                Text(
                    "方向：\(sourceBook.title) → \(target.title)；"
                        + "类型：\(store.selectedKind.userFacingTitle)"
                )
                .font(.callout.weight(.medium))
                .accessibilityIdentifier("manual-relation-direction-preview")
            } else {
                Text("选择目标后会在保存前显示完整方向。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("manual-relation-direction-placeholder")
            }

            if let creationErrorMessage = store.creationErrorMessage {
                Label(creationErrorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("manual-relation-creation-error")
            }

            HStack {
                Button("取消", action: store.cancelCreate)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("cancel-manual-relation")
                Spacer()
                if store.isSaving {
                    ProgressView("正在保存，暂不能取消")
                        .controlSize(.small)
                        .accessibilityLabel("正在保存手动关系，完成前不能取消")
                        .accessibilityIdentifier("manual-relation-saving")
                }
                if store.selectedTarget == nil {
                    saveButton
                        .disabled(true)
                } else {
                    saveButton
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 620)
        .frame(minHeight: 560)
        .disabled(store.isSaving)
        .interactiveDismissDisabled(store.isSaving)
        .onAppear { searchIsFocused = true }
    }

    @ViewBuilder
    private var targetResults: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch store.targetSearchState {
            case .idle, .loading:
                ProgressView("正在搜索本地书库…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("manual-relation-target-loading")
            case .failed:
                ContentUnavailableView {
                    Label("无法搜索目标书籍", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("搜索失败；书库未更改。")
                } actions: {
                    Button("重试", action: store.retryTargetSearch)
                }
                .accessibilityIdentifier("manual-relation-target-error")
            case .content:
                if store.targetBooks.isEmpty {
                    ContentUnavailableView {
                        Label("没有可选的目标书籍", systemImage: "books.vertical")
                    } description: {
                        Text("当前书籍不会出现在目标结果中；可以修改搜索词。")
                    }
                    .accessibilityIdentifier("manual-relation-target-empty")
                } else {
                    List(store.targetBooks) { target in
                        targetButton(for: target)
                    }
                    .accessibilityIdentifier("manual-relation-target-list")

                    HStack {
                        Text(store.targetResultDescription)
                            .font(.caption)
                            .accessibilityIdentifier("manual-relation-target-count")
                        Spacer()
                        if store.isLoadingMoreTargets {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("正在载入更多目标书籍")
                        } else if store.hasMoreTargets {
                            Button(
                                store.targetLoadMoreFailed ? "重试" : "加载更多",
                                action: store.loadMoreTargets
                            )
                            .accessibilityHint("载入下一页，已显示的目标保持不变")
                            .accessibilityIdentifier("manual-relation-target-load-more")
                        } else {
                            Text("已全部显示")
                                .font(.caption)
                                .accessibilityIdentifier("manual-relation-target-all-loaded")
                        }
                        if store.selectedTarget == nil {
                            Button(
                                "选择首个显示结果",
                                action: store.selectFirstTargetFromKeyboard
                            )
                            .keyboardShortcut(.return, modifiers: [.command])
                            .accessibilityHint("快捷键 Command-Return")
                            .accessibilityIdentifier(
                                "select-first-manual-relation-target"
                            )
                        }
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        Button("保存关系") {
            Task { await store.saveCreation() }
        }
        .disabled(store.isSaving)
        .accessibilityIdentifier("save-manual-relation")
    }

    private func targetButton(for target: Book) -> some View {
        let isSelected = store.selectedTargetID == target.id
        return Button {
            store.selectTarget(target.id)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(target.title)
                Text(target.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let isbn = target.isbn {
                    Text("ISBN \(isbn)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.14)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "目标书籍 \(target.title)，作者 \(target.author)，\(isSelected ? "已选择" : "未选择")"
        )
        .accessibilityValue(isSelected ? "已选择" : "未选择")
        .accessibilityIdentifier(
            "manual-relation-target-\(target.id.uuidString)"
        )
    }
}

private extension ManualRelationDirection {
    var identifierComponent: String {
        switch self {
        case .outgoing: "outgoing"
        case .incoming: "incoming"
        }
    }
}

private struct ReadingEntriesSection: View {
    let book: Book
    @ObservedObject var store: ReadingEntryStore
    let mode: ReadingEntryPresentationMode
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

                if mode == .readOnly {
                    Text("候选记录中的阅读入口仅供核对；返回主详情后才能管理入口。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("reading-entries-read-only")
                }

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
                        if mode == .manage {
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
                        if mode == .manage {
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
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("\(reference.displayName)，本地只读文件引用")
                    .accessibilityIdentifier("local-file-row-\(reference.id.uuidString)")
                }

                if mode == .manage {
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
