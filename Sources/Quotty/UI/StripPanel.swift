import AppKit
import SwiftUI

public final class StripPanel: NSPanel {
    private let manager: QuotaManager
    private var isResizingHeight = false

    public init(manager: QuotaManager, onOpenSettings: @escaping () -> Void) {
        self.manager = manager
        
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 430, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false // MUST BE FALSE: True creates an opaque grey backdrop mask!
        self.isMovableByWindowBackground = true  // Fallback for older macOS
        self.hidesOnDeactivate = false

        let stripView = StripView(
            manager: manager,
            onOpenSettings: onOpenSettings,
            onHeightChange: { [weak self] h in
                self?.updateHeight(h)
            }
        )
        let hostingView = NSHostingView(rootView: stripView)
        hostingView.autoresizingMask = [.width, .height]
        
        self.contentView = hostingView

        restorePosition()
        setupMoveObserver()
    }

    public func updateHeight(_ newHeight: CGFloat) {
        let currentFrame = self.frame
        // Add padding for the glass shadow (offset y=6, radius=14)
        let totalHeight = newHeight + 20
        if abs(currentFrame.height - totalHeight) > 1.0 {
            isResizingHeight = true
            let newY = currentFrame.maxY - totalHeight
            let newFrame = NSRect(x: currentFrame.minX, y: newY, width: currentFrame.width, height: totalHeight)
            self.setFrame(newFrame, display: true, animate: false)
            // Critical: invalidate cached shadow mask after resize on macOS 26+
            self.invalidateShadow()
            isResizingHeight = false
        }
    }

    private func restorePosition() {
        if let pos = manager.settings.pos {
            setFrameOrigin(NSPoint(x: pos.x, y: pos.y))
        } else if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            // Default place near bottom right (above dock) or top right
            let x = visibleFrame.maxX - 450
            let y = visibleFrame.minY + 80
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    private func setupMoveObserver() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, !self.isResizingHeight else { return }
            Task { @MainActor in
                let origin = self.frame.origin
                var s = self.manager.settings
                s.pos = Position(x: Double(origin.x), y: Double(origin.y))
                self.manager.updateSettings(s)
            }
        }
    }
}
