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
        .frame(minWidth: 720, minHeight: 560)
        .accessibilityIdentifier("duplicate-review-sheet")
        .interactiveDismissDisabled(store.isDuplicateOperationInProgress)
        .background(
            EscapeKeyMonitor {
                handleEscape()
                return true
            }
        )
        .onExitCommand(perform: handleEscape)
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
                    Text("候选由本机确定性规则生成，不会自动合并。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.isDuplicateOperationInProgress {
                    ProgressView()
                        .accessibilityLabel("正在处理重复候选")
                }
            }
            .padding()

            Divider()

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
                    .keyboardShortcut(.cancelAction)
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
                    LabeledContent(
                        "标签",
                        value: "\(preview.associations.targetTags.count) + \(preview.associations.sourceTags.count)"
                    )
                    LabeledContent(
                        "书单",
                        value: "\(preview.associations.targetCollections.count) + \(preview.associations.sourceCollections.count)"
                    )
                    LabeledContent(
                        "来源",
                        value: "\(preview.associations.targetSources.count) + \(preview.associations.sourceSources.count)"
                    )
                    LabeledContent(
                        "外部链接",
                        value: "\(preview.associations.targetLinks.count) + \(preview.associations.sourceLinks.count)"
                    )
                    LabeledContent("手动关系", value: "\(preview.associations.manualRelations.count)")
                    Text("相同关联会去重；会产生自指或无法无损解决的关系冲突将阻止合并。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("merge-preview-back")
                Spacer()
                Button("确认选择并合并…") {
                    confirmsMerge = true
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("merge-preview-confirm")
            }
            .padding()
        }
        .accessibilityIdentifier("book-merge-preview")
    }

    private var selectedCandidate: DuplicateCandidate? {
        review.candidates.first { $0.id == store.selectedDuplicateID }
    }

    private func handleEscape() {
        if store.mergePreview != nil {
            store.cancelMergePreview()
        } else {
            store.cancelDuplicateReview()
        }
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
