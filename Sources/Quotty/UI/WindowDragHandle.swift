import SwiftUI
import AppKit

// MARK: - WindowDragHandle
/// An invisible AppKit drag handle that reliably initiates native window dragging.
/// Solves the macOS 26+ issue where SwiftUI's responder chain swallows mouseDown
/// events, preventing `isMovableByWindowBackground` from working.
public struct WindowDragHandle: NSViewRepresentable {
    public func makeNSView(context: Context) -> DragNSView {
        return DragNSView()
    }

    public func updateNSView(_ nsView: DragNSView, context: Context) {}

    public final class DragNSView: NSView {
        public override var acceptsFirstResponder: Bool { false }

        public override func mouseDown(with event: NSEvent) {
            // Initiates native system window dragging loop,
            // bypassing SwiftUI's responder chain entirely.
            self.window?.performDrag(with: event)
        }

        public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            return true
        }

        // Allow right-click to pass through for context menu
        public override func rightMouseDown(with event: NSEvent) {
            super.rightMouseDown(with: event)
        }

        // Pass through scroll and other events
        public override func scrollWheel(with event: NSEvent) {
            super.scrollWheel(with: event)
        }
    }
}

public extension View {
    /// Overlays a transparent drag handle across the view.
    /// The handle intercepts left-click drag to move the window,
    /// while passing through right-click for context menus.
    func windowDragHandle() -> some View {
        self.overlay(WindowDragHandle())
    }
}
