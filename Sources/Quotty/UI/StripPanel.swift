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
        self.hasShadow = true
        self.isMovableByWindowBackground = true
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
        if abs(currentFrame.height - newHeight) > 1.0 {
            isResizingHeight = true
            let newY = currentFrame.maxY - newHeight
            let newFrame = NSRect(x: currentFrame.minX, y: newY, width: currentFrame.width, height: newHeight)
            self.setFrame(newFrame, display: true, animate: false)
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
