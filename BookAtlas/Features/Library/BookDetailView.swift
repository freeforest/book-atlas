import SwiftUI

struct BookDetailView: View {
    let book: Book
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
