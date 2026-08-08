import AppKit
import SwiftUI

/// This focused wrapper keeps search focus behavior explicit while limiting
/// AppKit to first-responder integration.
struct LibrarySearchField: NSViewRepresentable {
    @Binding var text: String
    let focusRequestID: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> FocusableSearchField {
        let searchField = FocusableSearchField()
        searchField.placeholderString = "搜索书名、原书名、作者或 ISBN"
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = context.coordinator
        return searchField
    }

    func updateNSView(_ searchField: FocusableSearchField, context: Context) {
        if searchField.stringValue != text {
            searchField.stringValue = text
        }
        if context.coordinator.lastFocusRequestID != focusRequestID {
            context.coordinator.lastFocusRequestID = focusRequestID
            searchField.requestFocus()
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding private var text: String
        var lastFocusRequestID = 0

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else {
                return
            }
            text = searchField.stringValue
        }
    }
}

final class FocusableSearchField: NSSearchField {
    private var needsFocus = false

    func requestFocus() {
        needsFocus = true
        focusIfPossible()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focusIfPossible()
    }

    private func focusIfPossible() {
        guard needsFocus, let window, window.makeFirstResponder(self) else {
            return
        }
        needsFocus = false
        selectText(nil)
    }
}
