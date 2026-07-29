import SwiftUI

struct BookEditorSheet: View {
    let session: BookEditorSession
    @ObservedObject var store: LibraryStore

    @State private var draft: BookEditorDraft
    @State private var validationError: LibraryUserFacingError?
    @State private var confirmsDiscard = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case author
    }

    init(session: BookEditorSession, store: LibraryStore) {
        self.session = session
        self.store = store
        _draft = State(initialValue: session.initialDraft)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("必填") {
                    TextField("书名", text: $draft.title)
                        .focused($focusedField, equals: .title)
                        .accessibilityIdentifier("editor-title")
                    TextField("作者", text: $draft.author)
                        .focused($focusedField, equals: .author)
                        .accessibilityIdentifier("editor-author")
                }

                Section("可选信息") {
                    TextField("原书名", text: $draft.originalTitle)
                        .accessibilityIdentifier("editor-original-title")
                    TextField("ISBN", text: $draft.isbn)
                        .accessibilityIdentifier("editor-isbn")
                    TextField("出版社", text: $draft.publisher)
                        .accessibilityIdentifier("editor-publisher")
                    TextField("出版日期（YYYY、YYYY-MM 或 YYYY-MM-DD）", text: $draft.publicationDateText)
                        .accessibilityIdentifier("editor-publication-date")
                    Picker("阅读状态", selection: $draft.readingStatus) {
                        ForEach(ReadingStatus.allCases, id: \.self) { status in
                            Text(status.displayTitle).tag(status)
                        }
                    }
                    Picker("优先级", selection: $draft.priorityValue) {
                        Text("未设置").tag(0)
                        ForEach(1 ... 5, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                }

                Section("阅读时间") {
                    Toggle("已开始阅读", isOn: $draft.hasStartedAt)
                    if draft.hasStartedAt {
                        DatePicker("开始时间", selection: $draft.startedAt, displayedComponents: [.date, .hourAndMinute])
                    }
                    Toggle("已完成阅读", isOn: $draft.hasFinishedAt)
                    if draft.hasFinishedAt {
                        DatePicker("完成时间", selection: $draft.finishedAt, displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("备注") {
                    TextEditor(text: $draft.note)
                        .frame(minHeight: 88)
                        .accessibilityIdentifier("editor-note")
                }

                if let validationError {
                    Text(validationError.message)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("editor-validation-error")
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("取消", action: requestCancel)
                    .keyboardShortcut(.cancelAction)
                    .disabled(store.duplicateReview != nil)
                    .accessibilityIdentifier("editor-cancel")
                Spacer()
                Button("保存", action: save)
                    .keyboardShortcut("s", modifiers: .command)
                    .accessibilityIdentifier("editor-save")
            }
            .padding()
        }
        .frame(minWidth: 540, minHeight: 560)
        .navigationTitle(session.title)
        .accessibilityIdentifier("book-editor-sheet")
        .interactiveDismissDisabled(isDirty)
        .background(
            EscapeKeyMonitor {
                guard !confirmsDiscard, store.duplicateReview == nil else {
                    return false
                }
                requestCancel()
                return true
            }
        )
        .onAppear {
            focusedField = .title
        }
        .onChange(of: store.saveRequestID) { _, _ in
            save()
        }
        .confirmationDialog(
            "放弃未保存的修改？",
            isPresented: $confirmsDiscard,
            titleVisibility: .visible
        ) {
            Button("放弃修改", role: .destructive) {
                store.cancelEditor()
            }
            .accessibilityIdentifier("editor-discard-changes")
            Button("继续编辑", role: .cancel) {}
                .accessibilityIdentifier("editor-continue-editing")
        } message: {
            Text("取消后，本次未保存的填写内容将被放弃。")
        }
        .sheet(item: $store.duplicateReview) { review in
            DuplicateReviewSheet(store: store, review: review)
        }
    }

    private var isDirty: Bool {
        draft != session.initialDraft
    }

    private func save() {
        Task { @MainActor in
            switch await store.save(draft, for: session) {
            case .success:
                validationError = nil
            case let .failure(error):
                validationError = error
                if case .validation(.titleRequired) = error {
                    focusedField = .title
                } else if case .validation(.authorRequired) = error {
                    focusedField = .author
                }
            }
        }
    }

    private func requestCancel() {
        if isDirty {
            confirmsDiscard = true
        } else {
            store.cancelEditor()
        }
    }
}
