import AppKit
import SwiftUI

struct AppKitStatusView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSTextField {
        let label = NSTextField(labelWithString: "AppKit bridge verified")
        label.alignment = .center
        label.setAccessibilityIdentifier("appkit-status")
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {}
}
