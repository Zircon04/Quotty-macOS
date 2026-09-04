import AppKit
import SwiftUI
import Combine

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var quotaManager: QuotaManager!
    private var stripPanel: StripPanel!
    private var menuBarManager: MenuBarManager!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    static func main() {
        let app = NSApplication.shared
        if let icon = AppAssets.appIcon() {
            app.applicationIconImage = icon
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // No dock icon, menu bar + floating strip
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let manager = QuotaManager()
        self.quotaManager = manager

        self.stripPanel = StripPanel(manager: manager) { [weak self] in
            self?.openSettings()
        }

        self.menuBarManager = MenuBarManager(manager: manager) { [weak self] in
            self?.openSettings()
        }

        if manager.isPanelVisible {
            stripPanel.orderFrontRegardless()
        } else {
            stripPanel.orderOut(nil)
        }

        // Observe visibility
        manager.$isPanelVisible
            .removeDuplicates()
            .sink { [weak self] visible in
                guard let self = self else { return }
                if visible {
                    self.stripPanel.orderFrontRegardless()
                } else {
                    self.stripPanel.orderOut(nil)
                }
            }
            .store(in: &cancellables)
    }

    func openSettings() {
        if let win = settingsWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 530),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Quotty — настройки"
        win.isReleasedWhenClosed = false
        win.center()

        let settingsView = SettingsView(manager: quotaManager) { [weak self] in
            self?.settingsWindow?.close()
        }
        win.contentView = NSHostingView(rootView: settingsView)

        self.settingsWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
