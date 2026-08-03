import AppKit
import SwiftUI

@MainActor
protocol AccessibilityAnnouncementPosting {
    func postAnnouncement(_ message: String)
}

@MainActor
struct AppKitAccessibilityAnnouncementPoster: AccessibilityAnnouncementPosting {
    func postAnnouncement(_ message: String) {
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }
}

@MainActor
final class BookEditorValidationFeedback: ObservableObject {
    @Published private(set) var error: LibraryUserFacingError?

    private let announcementPoster: AccessibilityAnnouncementPosting

    init(
        announcementPoster: AccessibilityAnnouncementPosting =
            AppKitAccessibilityAnnouncementPoster()
    ) {
        self.announcementPoster = announcementPoster
    }

    var validationError: BookEditorValidationError? {
        guard case let .validation(error) = error else {
            return nil
        }
        return error
    }

    func present(_ error: LibraryUserFacingError) {
        self.error = error
        announcementPoster.postAnnouncement(
            "保存没有成功。\(error.title)。\(error.message)"
        )
    }

    func clear() {
        guard error != nil else {
            return
        }
        error = nil
    }

    func clearIfResolved(by draft: BookEditorDraft) {
        guard let validationError, validationError.isResolved(by: draft) else {
            return
        }
        clear()
    }
}

struct BookEditorSheet: View {
    let session: BookEditorSession
    @ObservedObject var store: LibraryStore

    @State private var draft: BookEditorDraft
    @StateObject private var validationFeedback: BookEditorValidationFeedback
    @State private var confirmsDiscard = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case author
    }

    init(
        session: BookEditorSession,
        store: LibraryStore,
        announcementPoster: AccessibilityAnnouncementPosting =
            AppKitAccessibilityAnnouncementPoster()
    ) {
        self.session = session
        self.store = store
        _draft = State(initialValue: session.initialDraft)
        _validationFeedback = StateObject(
            wrappedValue: BookEditorValidationFeedback(
                announcementPoster: announcementPoster
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if let validationError = validationFeedback.error {
                validationSummary(validationError)
            }

            Form {
                Section("必填") {
                    TextField("书名", text: $draft.title)
                        .focused($focusedField, equals: .title)
                        .accessibilityHint(titleAccessibilityHint)
                        .accessibilityIdentifier("editor-title")
                    if validationFeedback.validationError == .titleRequired {
                        fieldError(
                            BookEditorValidationError.titleRequired.message,
                            identifier: "editor-title-error"
                        )
                    }
                    TextField("作者", text: $draft.author)
                        .focused($focusedField, equals: .author)
                        .accessibilityHint(authorAccessibilityHint)
                        .accessibilityIdentifier("editor-author")
                    if validationFeedback.validationError == .authorRequired {
                        fieldError(
                            BookEditorValidationError.authorRequired.message,
                            identifier: "editor-author-error"
                        )
                    }
                }

                Section("可选信息") {
                    TextField("原书名", text: $draft.originalTitle)
                        .accessibilityIdentifier("editor-original-title")
                    TextField("ISBN", text: $draft.isbn)
                        .accessibilityIdentifier("editor-isbn")
                    TextField("出版社", text: $draft.publisher)
                        .accessibilityIdentifier("editor-publisher")
                    TextField("出版日期（YYYY、YYYY-MM 或 YYYY-MM-DD）", text: $draft.publicationDateText)
                        .accessibilityHint(publicationDateAccessibilityHint)
                        .accessibilityIdentifier("editor-publication-date")
                    if validationFeedback.validationError == .invalidPublicationDate {
                        fieldError(
                            BookEditorValidationError.invalidPublicationDate.message,
                            identifier: "editor-publication-date-error"
                        )
                    }
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
                    .accessibilityHint(priorityAccessibilityHint)
                    if validationFeedback.validationError == .invalidPriority {
                        fieldError(
                            BookEditorValidationError.invalidPriority.message,
                            identifier: "editor-priority-error"
                        )
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
                    .accessibilityLabel("保存书籍")
                    .accessibilityIdentifier("editor-save")
            }
            .padding()
        }
        .frame(minWidth: 540, minHeight: 560)
        .navigationTitle(session.title)
        .accessibilityElement(children: .contain)
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
        .onChange(of: draft) { _, newDraft in
            validationFeedback.clearIfResolved(by: newDraft)
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

    private var titleAccessibilityHint: String {
        validationFeedback.validationError == .titleRequired
            ? "错误：请填写书名。"
            : "必填"
    }

    private var authorAccessibilityHint: String {
        validationFeedback.validationError == .authorRequired
            ? "错误：请填写作者。"
            : "必填"
    }

    private var publicationDateAccessibilityHint: String {
        validationFeedback.validationError == .invalidPublicationDate
            ? "错误：\(BookEditorValidationError.invalidPublicationDate.message)"
            : "可填写年份、年月或完整日期"
    }

    private var priorityAccessibilityHint: String {
        validationFeedback.validationError == .invalidPriority
            ? "错误：\(BookEditorValidationError.invalidPriority.message)"
            : "可选，范围为 1 到 5"
    }

    private func validationSummary(
        _ validationError: LibraryUserFacingError
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("保存没有成功")
                    .font(.headline)
                Text(validationError.message)
                    .font(.callout)
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.red.opacity(0.08))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("保存没有成功")
        .accessibilityValue(validationError.message)
        .accessibilityIdentifier("editor-validation-error")
    }

    private func fieldError(
        _ message: String,
        identifier: String
    ) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(.red)
            .accessibilityLabel("错误：\(message)")
            .accessibilityIdentifier(identifier)
    }

    private func save() {
        Task { @MainActor in
            switch await store.save(draft, for: session) {
            case .success:
                validationFeedback.clear()
            case let .failure(error):
                validationFeedback.present(error)
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
