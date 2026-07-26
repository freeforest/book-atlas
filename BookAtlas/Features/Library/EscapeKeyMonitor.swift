import AppKit
import SwiftUI

/// Intercepts Escape while the editor is presented, before macOS can dismiss the sheet.
struct EscapeKeyMonitor: NSViewRepresentable {
    let handleEscape: () -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(handleEscape: handleEscape)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.start()
        return NSView()
    }

    func updateNSView(_: NSView, context: Context) {
        context.coordinator.handleEscape = handleEscape
    }

    static func dismantleNSView(_: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var handleEscape: () -> Bool
        private var monitor: Any?

        init(handleEscape: @escaping () -> Bool) {
            self.handleEscape = handleEscape
        }

        func start() {
            guard monitor == nil else {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == 53, self?.handleEscape() == true else {
                    return event
                }
                return nil
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            stop()
        }
    }
}
