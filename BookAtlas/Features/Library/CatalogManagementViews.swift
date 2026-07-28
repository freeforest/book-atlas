import SwiftUI

enum CatalogManagementSection: String, CaseIterable, Identifiable {
    case tags
    case collections
    case sources

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tags: "标签"
        case .collections: "书单"
        case .sources: "来源"
        }
    }
}

struct CatalogManagementView: View {
    @ObservedObject var store: LibraryStore
    @ObservedObject private var organizer: CatalogOrganizerStore
    let showsSectionPicker: Bool

    @State private var selection: CatalogManagementSection
    @Environment(\.dismiss) private var dismiss

    init(
        store: LibraryStore,
        initialSection: CatalogManagementSection = .tags,
        showsSectionPicker: Bool = true
    ) {
        self.store = store
        _organizer = ObservedObject(wrappedValue: store.organizer)
        self.showsSectionPicker = showsSectionPicker
        _selection = State(initialValue: initialSection)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsSectionPicker {
                HStack {
                    Picker("整理类型", selection: $selection) {
                        ForEach(CatalogManagementSection.allCases) { section in
                            Text(section.title)
                                .tag(section)
                                .accessibilityIdentifier("catalog-management-tab-\(section.rawValue)")
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("catalog-management-tabs")

                    Button("完成", action: dismiss.callAsFunction)
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("close-catalog-management")
                }
                .padding()
                Divider()
            }

            switch selection {
            case .tags:
                TagManagementView(store: store)
            case .collections:
                CollectionManagementView(store: store)
            case .sources:
                SourceManagementView(store: store)
            }
        }
        .frame(minWidth: 560, minHeight: 440)
        .task {
            organizer.load()
        }
        .alert(
            organizer.error?.title ?? "",
            isPresented: Binding(
                get: { organizer.error != nil },
                set: { if !$0 { organizer.dismissError() } }
            )
        ) {
            Button("好", action: organizer.dismissError)
        } message: {
            Text(organizer.error?.message ?? "")
        }
    }
}

private struct TagManagementView: View {
    @ObservedObject var store: LibraryStore
    @ObservedObject private var organizer: CatalogOrganizerStore

    @State private var selection: UUID?
    @State private var editor: TagEditorContext?
    @State private var deleteCandidate: Tag?
    @State private var mergeSource: Tag?

    init(store: LibraryStore) {
        self.store = store
        _organizer = ObservedObject(wrappedValue: store.organizer)
    }

    private var selectedTag: Tag? {
        organizer.snapshot.tags.first { $0.id == selection }?.tag
    }

    var body: some View {
        VStack(spacing: 0) {
            managementHeader(
                title: "标签",
                titleIdentifier: "page-title-tags",
                addIdentifier: "add-tag-button",
                add: { editor = TagEditorContext(tag: nil) }
            )

            List(selection: $selection) {
                ForEach(organizer.snapshot.tags) { summary in
                    metadataRow(name: summary.tag.name, count: summary.bookCount)
                        .tag(summary.id)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(summary.tag.name)，\(summary.bookCount) 本")
                        .accessibilityIdentifier("tag-row-\(summary.id.uuidString)")
                }
            }
            .overlay {
                if organizer.snapshot.tags.isEmpty {
                    ContentUnavailableView("尚无标签", systemImage: "tag")
                }
            }

            managementActions {
                Button("重命名") {
                    if let selectedTag {
                        editor = TagEditorContext(tag: selectedTag)
                    }
                }
                .disabled(selectedTag == nil)
                .accessibilityIdentifier("rename-tag-button")

                Button("合并") {
                    mergeSource = selectedTag
                }
                .disabled(selectedTag == nil || organizer.snapshot.tags.count < 2)
                .accessibilityIdentifier("merge-tag-button")

                Button("删除", role: .destructive) {
                    deleteCandidate = selectedTag
                }
                .disabled(selectedTag == nil)
                .accessibilityIdentifier("delete-tag-button")
            }
        }
        .sheet(item: $editor) { context in
            MetadataEditorSheet(
                title: context.tag == nil ? "新建标签" : "重命名标签",
                name: context.tag?.name ?? "",
                details: nil,
                detailsLabel: nil,
                identifierPrefix: "tag"
            ) { name, _ in
                if let tag = context.tag {
                    return await organizer.renameTag(tag, name: name)
                }
                return await organizer.createTag(name: name)
            }
        }
        .sheet(item: $mergeSource) { source in
            TagMergeSheet(
                source: source,
                targets: organizer.snapshot.tags.map(\.tag).filter { $0.id != source.id }
            ) { target in
                let succeeded = await organizer.mergeTag(source, into: target)
                if succeeded {
                    store.catalogDidMergeTag(source.id, into: target.id)
                    selection = target.id
                }
                return succeeded
            }
        }
        .confirmationDialog(
            "删除标签？",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ),
            titleVisibility: .visible,
            presenting: deleteCandidate
        ) { tag in
            Button("删除", role: .destructive) {
                Task { @MainActor in
                    if await organizer.deleteTag(tag) {
                        store.catalogDidDeleteTag(tag.id)
                        selection = nil
                    }
                    deleteCandidate = nil
                }
            }
            .accessibilityIdentifier("confirm-delete-tag")
        } message: { tag in
            Text("“\(tag.name)”会从所有书籍移除，但不会删除书籍。")
        }
    }
}

private struct CollectionManagementView: View {
    @ObservedObject var store: LibraryStore
    @ObservedObject private var organizer: CatalogOrganizerStore

    @State private var selection: UUID?
    @State private var editor: CollectionEditorContext?
    @State private var deleteCandidate: BookCollection?

    init(store: LibraryStore) {
        self.store = store
        _organizer = ObservedObject(wrappedValue: store.organizer)
    }

    private var selectedCollection: BookCollection? {
        organizer.snapshot.collections.first { $0.id == selection }?.collection
    }

    var body: some View {
        VStack(spacing: 0) {
            managementHeader(
                title: "书单",
                titleIdentifier: "page-title-collections",
                addIdentifier: "add-collection-button",
                add: { editor = CollectionEditorContext(collection: nil) }
            )

            List(selection: $selection) {
                ForEach(organizer.snapshot.collections) { summary in
                    metadataRow(
                        name: summary.collection.name,
                        subtitle: summary.collection.description,
                        count: summary.bookCount
                    )
                    .tag(summary.id)
                }
            }
            .overlay {
                if organizer.snapshot.collections.isEmpty {
                    ContentUnavailableView("尚无书单", systemImage: "rectangle.stack")
                }
            }

            managementActions {
                Button("编辑") {
                    if let selectedCollection {
                        editor = CollectionEditorContext(collection: selectedCollection)
                    }
                }
                .disabled(selectedCollection == nil)
                .accessibilityIdentifier("rename-collection-button")

                Button("删除", role: .destructive) {
                    deleteCandidate = selectedCollection
                }
                .disabled(selectedCollection == nil)
                .accessibilityIdentifier("delete-collection-button")
            }
        }
        .sheet(item: $editor) { context in
            MetadataEditorSheet(
                title: context.collection == nil ? "新建书单" : "编辑书单",
                name: context.collection?.name ?? "",
                details: context.collection?.description,
                detailsLabel: "描述",
                identifierPrefix: "collection"
            ) { name, details in
                if let collection = context.collection {
                    return await organizer.renameCollection(
                        collection,
                        name: name,
                        description: details
                    )
                }
                return await organizer.createCollection(name: name, description: details)
            }
        }
        .confirmationDialog(
            "删除书单？",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ),
            titleVisibility: .visible,
            presenting: deleteCandidate
        ) { collection in
            Button("删除", role: .destructive) {
                Task { @MainActor in
                    if await organizer.deleteCollection(collection) {
                        store.catalogDidDeleteCollection(collection.id)
                        selection = nil
                    }
                    deleteCandidate = nil
                }
            }
            .accessibilityIdentifier("confirm-delete-collection")
        } message: { collection in
            Text("“\(collection.name)”会被删除，其中的书籍仍保留在书库。")
        }
    }
}

private struct SourceManagementView: View {
    @ObservedObject var store: LibraryStore
    @ObservedObject private var organizer: CatalogOrganizerStore

    @State private var selection: UUID?
    @State private var editor: SourceEditorContext?
    @State private var deleteCandidate: RecommendationSource?

    init(store: LibraryStore) {
        self.store = store
        _organizer = ObservedObject(wrappedValue: store.organizer)
    }

    private var selectedSource: RecommendationSource? {
        organizer.snapshot.sources.first { $0.id == selection }?.source
    }

    var body: some View {
        VStack(spacing: 0) {
            managementHeader(
                title: "推荐来源",
                titleIdentifier: "page-title-sources",
                addIdentifier: "add-source-button",
                add: { editor = SourceEditorContext(source: nil) }
            )

            List(selection: $selection) {
                ForEach(organizer.snapshot.sources) { summary in
                    metadataRow(
                        name: summary.source.name,
                        subtitle: summary.source.details,
                        count: summary.bookCount
                    )
                    .tag(summary.id)
                }
            }
            .overlay {
                if organizer.snapshot.sources.isEmpty {
                    ContentUnavailableView("尚无来源", systemImage: "quote.bubble")
                }
            }

            managementActions {
                Button("编辑") {
                    if let selectedSource {
                        editor = SourceEditorContext(source: selectedSource)
                    }
                }
                .disabled(selectedSource == nil)
                .accessibilityIdentifier("rename-source-button")

                Button("删除", role: .destructive) {
                    deleteCandidate = selectedSource
                }
                .disabled(selectedSource == nil)
                .accessibilityIdentifier("delete-source-button")
            }
        }
        .sheet(item: $editor) { context in
            MetadataEditorSheet(
                title: context.source == nil ? "新建来源" : "编辑来源",
                name: context.source?.name ?? "",
                details: context.source?.details,
                detailsLabel: "说明",
                identifierPrefix: "source"
            ) { name, details in
                if let source = context.source {
                    return await organizer.renameSource(source, name: name, details: details)
                }
                return await organizer.createSource(name: name, details: details)
            }
        }
        .confirmationDialog(
            "删除来源？",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ),
            titleVisibility: .visible,
            presenting: deleteCandidate
        ) { source in
            Button("删除", role: .destructive) {
                Task { @MainActor in
                    if await organizer.deleteSource(source) {
                        store.catalogDidDeleteSource(source.id)
                        selection = nil
                    }
                    deleteCandidate = nil
                }
            }
            .accessibilityIdentifier("confirm-delete-source")
        } message: { source in
            Text("“\(source.name)”会被删除，关联书籍仍保留在书库。")
        }
    }
}

struct BookMembershipSheet: View {
    let book: Book
    @ObservedObject var store: LibraryStore
    @ObservedObject private var organizer: CatalogOrganizerStore
    @Environment(\.dismiss) private var dismiss

    init(book: Book, store: LibraryStore) {
        self.book = book
        self.store = store
        _organizer = ObservedObject(wrappedValue: store.organizer)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                membershipSection("标签", values: organizer.snapshot.tags) { summary in
                    membershipToggle(
                        summary.tag.name,
                        association: .tag(summary.id),
                        included: organizer.membership.tagIDs.contains(summary.id)
                    )
                }
                membershipSection("书单", values: organizer.snapshot.collections) { summary in
                    membershipToggle(
                        summary.collection.name,
                        association: .collection(summary.id),
                        included: organizer.membership.collectionIDs.contains(summary.id)
                    )
                }
                membershipSection("来源", values: organizer.snapshot.sources) { summary in
                    membershipToggle(
                        summary.source.name,
                        association: .source(summary.id),
                        included: organizer.membership.sourceIDs.contains(summary.id)
                    )
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("完成", action: dismiss.callAsFunction)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 480, minHeight: 420)
        .accessibilityIdentifier("book-membership-sheet")
        .task(id: book.id) {
            organizer.load()
            await organizer.loadMembership(for: book.id)
        }
    }

    @ViewBuilder
    private func membershipSection<Value: Identifiable, Content: View>(
        _ title: String,
        values: [Value],
        @ViewBuilder content: @escaping (Value) -> Content
    ) -> some View {
        Section(title) {
            if values.isEmpty {
                Text("尚无可用项目，请先在管理页创建。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(values) { value in
                    content(value)
                }
            }
        }
    }

    private func membershipToggle(
        _ title: String,
        association: BookAssociation,
        included: Bool
    ) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: { included },
                set: { newValue in
                    Task { @MainActor in
                        if await organizer.setAssociation(
                            association,
                            included: newValue,
                            bookID: book.id
                        ) {
                            store.refresh()
                        }
                    }
                }
            )
        )
    }
}

private struct MetadataEditorSheet: View {
    let title: String
    let detailsLabel: String?
    let identifierPrefix: String
    let onSave: (String, String?) async -> Bool

    @State private var name: String
    @State private var details: String
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        name: String,
        details: String?,
        detailsLabel: String?,
        identifierPrefix: String,
        onSave: @escaping (String, String?) async -> Bool
    ) {
        self.title = title
        self.detailsLabel = detailsLabel
        self.identifierPrefix = identifierPrefix
        self.onSave = onSave
        _name = State(initialValue: name)
        _details = State(initialValue: details ?? "")
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
            Form {
                TextField("名称", text: $name)
                    .accessibilityIdentifier("\(identifierPrefix)-name-field")
                if let detailsLabel {
                    TextField(detailsLabel, text: $details, axis: .vertical)
                        .lineLimit(3 ... 6)
                        .accessibilityIdentifier("\(identifierPrefix)-details-field")
                }
            }
            HStack {
                Button("取消", action: dismiss.callAsFunction)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") {
                    Task { @MainActor in
                        isSaving = true
                        if await onSave(name, detailsLabel == nil ? nil : details) {
                            dismiss()
                        }
                        isSaving = false
                    }
                }
                .disabled(isSaving)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("\(identifierPrefix)-save-button")
            }
        }
        .padding()
        .frame(width: 420)
    }
}

private struct TagMergeSheet: View {
    let source: Tag
    let targets: [Tag]
    let onMerge: (Tag) async -> Bool

    @State private var targetID: UUID?
    @State private var confirmsMerge = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("合并标签")
                .font(.headline)
                .accessibilityIdentifier("tag-merge-sheet")
            Text("“\(source.name)”的书籍关联将迁移到目标标签并去重。")
                .foregroundStyle(.secondary)
            Picker("目标标签", selection: $targetID) {
                Text("请选择").tag(UUID?.none)
                ForEach(targets) { tag in
                    Text(tag.name).tag(Optional(tag.id))
                }
            }
            .accessibilityIdentifier("merge-tag-target-picker")
            HStack {
                Button("取消", action: dismiss.callAsFunction)
                Spacer()
                Button("合并", role: .destructive) {
                    confirmsMerge = true
                }
                .disabled(targetID == nil)
                .accessibilityIdentifier("confirm-merge-tag")
            }
        }
        .padding()
        .frame(width: 440)
        .confirmationDialog(
            "确认合并标签？",
            isPresented: $confirmsMerge,
            titleVisibility: .visible
        ) {
            Button("确认合并", role: .destructive) {
                guard let targetID, let target = targets.first(where: { $0.id == targetID }) else {
                    return
                }
                Task { @MainActor in
                    if await onMerge(target) {
                        dismiss()
                    }
                }
            }
            .accessibilityIdentifier("perform-merge-tag")
        }
    }
}

private struct TagEditorContext: Identifiable {
    let id = UUID()
    let tag: Tag?
}

private struct CollectionEditorContext: Identifiable {
    let id = UUID()
    let collection: BookCollection?
}

private struct SourceEditorContext: Identifiable {
    let id = UUID()
    let source: RecommendationSource?
}

private func managementHeader(
    title: String,
    titleIdentifier: String? = nil,
    addIdentifier: String,
    add: @escaping () -> Void
) -> some View {
    HStack {
        if let titleIdentifier {
            Text(title)
                .font(.title3.weight(.semibold))
                .accessibilityIdentifier(titleIdentifier)
        } else {
            Text(title)
                .font(.title3.weight(.semibold))
        }
        Spacer()
        Button("新增", systemImage: "plus", action: add)
            .accessibilityIdentifier(addIdentifier)
    }
    .padding()
}

private func managementActions<Content: View>(
    @ViewBuilder content: () -> Content
) -> some View {
    HStack {
        content()
        Spacer()
    }
    .padding()
    .background(.bar)
}

private func metadataRow(name: String, subtitle: String? = nil, count: Int) -> some View {
    HStack {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        Spacer()
        Text("\(count) 本")
            .foregroundStyle(.secondary)
    }
}
