import AppKit
import SwiftUI

public final class StripPanel: NSPanel {
    private let manager: QuotaManager

    public init(manager: QuotaManager, onOpenSettings: @escaping () -> Void) {
        self.manager = manager
        
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 430, height: 100),
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

        let stripView = StripView(manager: manager, onOpenSettings: onOpenSettings)
        let hostingView = NSHostingView(rootView: stripView)
        hostingView.autoresizingMask = [.width, .height]
        self.contentView = hostingView

        restorePosition()
        setupMoveObserver()
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
            guard let self = self else { return }
            Task { @MainActor in
                let origin = self.frame.origin
                var s = self.manager.settings
                s.pos = Position(x: Double(origin.x), y: Double(origin.y))
                self.manager.updateSettings(s)
            }
        }
    }
}
