import SwiftUI

struct DuplicateReviewSheet: View {
    @ObservedObject var store: LibraryStore
    let review: DuplicateReviewSession

    @State private var confirmsMerge = false

    var body: some View {
        VStack(spacing: 0) {
            if let preview = store.mergePreview {
                mergePreview(preview)
            } else {
                candidateReview
            }
        }
        .frame(minWidth: 720, minHeight: 500)
        .accessibilityIdentifier("duplicate-review-sheet")
        .interactiveDismissDisabled(store.isDuplicateOperationInProgress)
        .background(
            EscapeKeyMonitor {
                store.handleDuplicateReviewEscape()
            }
        )
        .sheet(
            item: Binding(
                get: { store.viewedDuplicateBook },
                set: { book in
                    if book == nil {
                        store.returnFromViewedDuplicate()
                    }
                }
            )
        ) { book in
            viewedExistingBook(book)
        }
        .confirmationDialog(
            "确认合并这两条书籍记录？",
            isPresented: $confirmsMerge,
            titleVisibility: .visible
        ) {
            Button("确认合并", role: .destructive, action: store.confirmMerge)
                .accessibilityIdentifier("confirm-book-merge")
            Button("取消", role: .cancel) {}
                .accessibilityIdentifier("cancel-book-merge-confirmation")
        } message: {
            Text("合并将在单个事务中迁移现有关联并删除来源记录；失败时不会保留部分结果。")
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
    }

    private var candidateReview: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("重复书籍审阅")
                        .font(.title2.weight(.semibold))
                    Text(review.origin == .createdBookContinuation
                         ? "新书已创建；上一次决定只作用于所选候选，以下候选仍需逐项审阅。"
                         : "候选由本机确定性规则生成，不会自动合并。")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("duplicate-review-status")
                }
                Spacer()
                if store.isDuplicateOperationInProgress {
                    ProgressView()
                        .accessibilityLabel("正在处理重复候选")
                }
            }
            .padding()

            Divider()

            if review.possibleLookupWasTruncated {
                Label(
                    "可能候选索引命中超过 250 条；本轮按记录 ID 确定排序显示前 250 条。精确与强候选不受此上限影响。",
                    systemImage: "info.circle"
                )
                .font(.callout)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("duplicate-possible-truncated")
                Divider()
            }

            if review.candidates.isEmpty {
                ContentUnavailableView {
                    Label("没有重复候选", systemImage: "checkmark.circle")
                } description: {
                    Text("未发现符合当前规则的重复书籍。")
                }
                .accessibilityIdentifier("duplicate-empty-state")
            } else {
                HSplitView {
                    List(review.candidates, selection: $store.selectedDuplicateID) { candidate in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(candidate.existingBook.title)
                                .font(.headline)
                            Text(candidate.existingBook.author)
                                .foregroundStyle(.secondary)
                            Text(candidate.confidence.displayTitle)
                                .font(.caption.weight(.semibold))
                        }
                        .tag(candidate.id)
                        .accessibilityIdentifier("duplicate-candidate-\(candidate.id.uuidString)")
                    }
                    .frame(minWidth: 240)
                    .accessibilityIdentifier("duplicate-candidate-list")

                    if let candidate = selectedCandidate {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(candidate.existingBook.title)
                                    .font(.title3.weight(.semibold))
                                Text(candidate.existingBook.author)
                                    .foregroundStyle(.secondary)
                                LabeledContent("置信等级", value: candidate.confidence.displayTitle)
                                LabeledContent("规则分数", value: "\(candidate.score)")
                                GroupBox("判定依据") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(Array(candidate.evidence.enumerated()), id: \.offset) { _, evidence in
                                            Text("• \(evidence.message)（\(evidence.weight >= 0 ? "+" : "")\(evidence.weight)）")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                Text(candidate.uncertainty)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("duplicate-uncertainty")
                                Button("查看这条已有记录") {
                                    store.viewDuplicate(candidate)
                                }
                                    .accessibilityHint("以只读方式查看所选候选的阅读入口")
                                    .accessibilityIdentifier("duplicate-view-existing-inline")
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }

            Divider()
            HStack {
                Button("取消", action: store.cancelDuplicateReview)
                    .accessibilityIdentifier("duplicate-review-cancel")
                Spacer()
                if !review.candidates.isEmpty {
                    Button("查看已有记录", action: store.viewSelectedDuplicate)
                        .keyboardShortcut("o", modifiers: .command)
                        .accessibilityIdentifier("duplicate-view-existing")
                    Menu("保留为独立记录") {
                        Button("不是重复书籍") {
                            store.keepSelectedDuplicateIndependent(as: .notDuplicate)
                        }
                        .accessibilityIdentifier("duplicate-keep-not-duplicate")
                        Button("不同版本") {
                            store.keepSelectedDuplicateIndependent(as: .separateEdition)
                        }
                        .accessibilityIdentifier("duplicate-keep-edition")
                        Button("不同译本") {
                            store.keepSelectedDuplicateIndependent(as: .separateTranslation)
                        }
                        .accessibilityIdentifier("duplicate-keep-translation")
                    }
                    .accessibilityIdentifier("duplicate-keep-menu")
                    Button("审阅合并…", action: store.beginMergePreview)
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("duplicate-begin-merge")
                }
            }
            .padding()
        }
    }

    private func viewedExistingBook(_ book: Book) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("查看已有记录")
                        .font(.title2.weight(.semibold))
                    Text("新增草稿与重复审阅仍保留；返回后可继续处理。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()

            Divider()
            VStack(spacing: 0) {
                BookDetailView(
                    book: book,
                    readingEntries: store.duplicateReadingEntries,
                    readingEntryMode: .readOnly
                )
            }
                .accessibilityIdentifier("duplicate-existing-preview")
            Divider()

            HStack {
                Button("返回重复审阅", action: store.returnFromViewedDuplicate)
                    .accessibilityIdentifier("duplicate-existing-back")
                Spacer()
            }
            .padding()
        }
    }

    private func mergePreview(_ preview: BookMergePreview) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("合并预览")
                        .font(.title2.weight(.semibold))
                    Text("保留“\(preview.target.title)”的记录身份；“\(preview.source.title)”为来源记录。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.isDuplicateOperationInProgress {
                    ProgressView()
                }
            }
            .padding()

            Divider()
            Form {
                Section("字段冲突") {
                    if preview.conflictingFields.isEmpty {
                        Text("没有需要选择的字段冲突；空缺字段会从来源记录补齐。")
                    } else {
                        ForEach(BookMergeField.allCases.filter(preview.conflictingFields.contains), id: \.self) { field in
                            Picker(field.displayTitle, selection: choiceBinding(for: field)) {
                                Text("保留记录：\(displayValue(field, in: preview.target))")
                                    .tag(BookMergeValueChoice.target)
                                Text("来源记录：\(displayValue(field, in: preview.source))")
                                    .tag(BookMergeValueChoice.source)
                            }
                            .accessibilityIdentifier("merge-choice-\(field.rawValue)")
                        }
                    }
                }

                Section("将合并的关联") {
                    namedAssociationDetails(
                        title: "标签",
                        details: preview.associations.tagDetails,
                        identifierPrefix: "merge-tag-detail"
                    )
                    namedAssociationDetails(
                        title: "书单",
                        details: preview.associations.collectionDetails,
                        identifierPrefix: "merge-collection-detail"
                    )
                    namedAssociationDetails(
                        title: "来源",
                        details: preview.associations.sourceDetails,
                        identifierPrefix: "merge-source-detail"
                    )
                    linkAssociationDetails(preview.associations.linkDetails)
                    localFileAssociationDetails(preview.associations.localFileDetails)
                    relationAssociationDetails(preview.associations.relationDetails)
                    Text("每项均标明保留、新增、去重、补齐或阻止；阻止项必须先在原记录中解决。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if preview.associations.hasBlockingConflict {
                        Label(
                            "存在无法无损处理的关联冲突，当前合并已阻止。",
                            systemImage: "exclamationmark.octagon.fill"
                        )
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("merge-association-blocked")
                    }
                }

                Section("时间与身份") {
                    Text("保留记录 ID 不变；添加时间取两者较早值，修改时间记为合并时刻。")
                    Text("来源记录只会在字段与关联迁移全部成功后删除。")
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("返回候选", action: store.cancelMergePreview)
                    .accessibilityIdentifier("merge-preview-back")
                Spacer()
                Button("确认选择并合并…") {
                    confirmsMerge = true
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("merge-preview-confirm")
                .disabled(preview.associations.hasBlockingConflict)
            }
            .padding()
        }
        .accessibilityIdentifier("book-merge-preview")
    }

    @ViewBuilder
    private func localFileAssociationDetails(
        _ details: [BookMergeLocalFileDetail]
    ) -> some View {
        GroupBox("本地文件引用") {
            if details.isEmpty {
                Text("无")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(details) { detail in
                        Text(
                            "\(detail.origin.displayTitle) · \(detail.outcome.displayTitle)："
                                + detail.displayName
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier(
                            "merge-local-file-detail-\(detail.id.uuidString)"
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func namedAssociationDetails(
        title: String,
        details: [BookMergeNamedAssociationDetail],
        identifierPrefix: String
    ) -> some View {
        GroupBox(title) {
            if details.isEmpty {
                Text("无")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(details) { detail in
                        HStack {
                            Text(
                                "\(detail.origin.displayTitle) · \(detail.outcome.displayTitle)：\(detail.name)"
                            )
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("\(identifierPrefix)-\(detail.id.uuidString)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func linkAssociationDetails(_ details: [BookMergeLinkDetail]) -> some View {
        GroupBox("外部链接") {
            if details.isEmpty {
                Text("无")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(details) { detail in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(
                                "\(detail.origin.displayTitle) · \(detail.outcome.displayTitle)："
                                    + "\(detail.label ?? "无标签")（\(detail.kind.displayTitle)）"
                            )
                            Text(safeExternalLinkSummary(detail))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("merge-link-detail-\(detail.id.uuidString)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func safeExternalLinkSummary(_ detail: BookMergeLinkDetail) -> String {
        switch detail.kind {
        case .web:
            (try? StrictHTTPSLinkValidator().validate(detail.value).safeHost)
                ?? "无效 HTTPS 主机"
        case .localAuthorization:
            "旧版本地授权记录"
        }
    }

    @ViewBuilder
    private func relationAssociationDetails(_ details: [BookMergeRelationDetail]) -> some View {
        GroupBox("手动关系") {
            if details.isEmpty {
                Text("无")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(details) { detail in
                        HStack {
                            Text(
                                "\(detail.origin.displayTitle) · \(detail.outcome.displayTitle)："
                                    + "\(detail.direction.displayTitle) · \(detail.kind.displayTitle) · "
                                    + "\(detail.otherBookTitle) · \(detail.hasNote ? "有备注" : "无备注")"
                            )
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("merge-relation-detail-\(detail.id.uuidString)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var selectedCandidate: DuplicateCandidate? {
        review.candidates.first { $0.id == store.selectedDuplicateID }
    }

    private func choiceBinding(for field: BookMergeField) -> Binding<BookMergeValueChoice> {
        Binding(
            get: { store.mergeSelections[field] },
            set: { store.setMergeChoice($0, for: field) }
        )
    }

    private func displayValue(_ field: BookMergeField, in book: Book) -> String {
        switch field {
        case .title: book.title
        case .originalTitle: book.originalTitle ?? "未设置"
        case .author: book.author
        case .isbn: book.isbn ?? "未设置"
        case .publisher: book.publisher ?? "未设置"
        case .publicationDate: book.publicationDate?.storageValue ?? "未设置"
        case .kind: book.kind.rawValue
        case .readingStatus: book.readingStatus.displayTitle
        case .priority: book.priority.map { "\($0.rawValue)" } ?? "未设置"
        case .note: book.note ?? "未设置"
        case .startedAt: book.startedAt?.formatted(date: .abbreviated, time: .shortened) ?? "未设置"
        case .finishedAt: book.finishedAt?.formatted(date: .abbreviated, time: .shortened) ?? "未设置"
        }
    }
}

private extension DuplicateConfidence {
    var displayTitle: String {
        switch self {
        case .exact: "精确候选"
        case .strong: "强候选"
        case .possible: "可能候选"
        case .notDuplicate: "非重复"
        }
    }
}

private extension BookMergeField {
    var displayTitle: String {
        switch self {
        case .title: "书名"
        case .originalTitle: "原书名"
        case .author: "作者"
        case .isbn: "ISBN"
        case .publisher: "出版社"
        case .publicationDate: "出版日期"
        case .kind: "类型"
        case .readingStatus: "阅读状态"
        case .priority: "优先级"
        case .note: "备注"
        case .startedAt: "开始阅读时间"
        case .finishedAt: "完成阅读时间"
        }
    }
}

private extension BookMergeAssociationOrigin {
    var displayTitle: String {
        switch self {
        case .target: "保留记录"
        case .source: "来源记录"
        }
    }
}

private extension BookMergeAssociationOutcome {
    var displayTitle: String {
        switch self {
        case .keep: "保留"
        case .add: "新增"
        case .deduplicate: "去重"
        case .fillMissingLabel: "去重并补齐标签"
        case .block: "阻止合并"
        }
    }
}

private extension ExternalLinkKind {
    var displayTitle: String {
        switch self {
        case .web: "网页"
        case .localAuthorization: "本地授权"
        }
    }
}

private extension BookMergeRelationDirection {
    var displayTitle: String {
        switch self {
        case .incoming: "指向本书"
        case .outgoing: "本书指向"
        }
    }
}

private extension ManualRelationKind {
    var displayTitle: String {
        switch self {
        case .related: "相关"
        case .inspiredBy: "受其启发"
        case .respondsTo: "回应"
        case .companion: "伴读"
        }
    }
}
