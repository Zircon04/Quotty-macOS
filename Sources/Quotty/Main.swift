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
        let s = Settings.load()
        app.setActivationPolicy(s.showInDock ? .regular : .accessory)
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

        // Observe showInDock
        manager.$settings
            .map(\.showInDock)
            .removeDuplicates()
            .sink { showInDock in
                let currentPolicy = NSApp.activationPolicy()
                let targetPolicy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
                if currentPolicy != targetPolicy {
                    NSApp.setActivationPolicy(targetPolicy)
                }
            }
            .store(in: &cancellables)

        // Observe dock badge and menu bar updates
        Publishers.CombineLatest3(manager.$states, manager.$settings, manager.$activeFamily)
            .sink { [weak self] _ in
                self?.updateDockBadge()
                self?.menuBarManager?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    private func updateDockBadge() {
        guard let manager = quotaManager,
              manager.settings.showInDock && manager.settings.showDockBadge else {
            NSApp.dockTile.badgeLabel = nil
            return
        }

        if let rem = manager.lowestRemainingPercent {
            NSApp.dockTile.badgeLabel = "\(rem)%"
        } else {
            NSApp.dockTile.badgeLabel = nil
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        quotaManager?.isVisible = true
        stripPanel?.orderFrontRegardless()
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        guard let manager = quotaManager else { return nil }
        let lang = manager.settings.language
        let menu = NSMenu()

        // Status header
        let state = manager.currentState
        let statusTitle: String = {
            if let rem = manager.lowestRemainingPercent {
                return lang.text("\(manager.activeFamily.name): \(rem)% квоты", "\(manager.activeFamily.name): \(rem)% quota")
            } else if state.online {
                return lang.text("\(manager.activeFamily.name) — Онлайн", "\(manager.activeFamily.name) — Online")
            } else if state.rateLimited {
                return lang.text("\(manager.activeFamily.name) — Подключение…", "\(manager.activeFamily.name) — Connecting…")
            } else if state.ever {
                return lang.text("\(manager.activeFamily.name) — Оффлайн", "\(manager.activeFamily.name) — Offline")
            } else {
                return lang.text("\(manager.activeFamily.name) — Загрузка…", "\(manager.activeFamily.name) — Loading…")
            }
        }()
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Family selection
        let switchMenu = NSMenu()
        for f in Family.allCases {
            let item = NSMenuItem(title: f.name, action: #selector(didSelectFamilyFromDock(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = f
            item.state = (manager.activeFamily == f) ? .on : .off
            switchMenu.addItem(item)
        }
        let switchParent = NSMenuItem(title: lang.text("Выбрать инструмент", "Select tool"), action: nil, keyEquivalent: "")
        switchParent.submenu = switchMenu
        menu.addItem(switchParent)

        menu.addItem(NSMenuItem.separator())

        // Toggle panel
        let toggleTitle = manager.isVisible ?
            lang.text("Скрыть полоску", "Hide strip") :
            lang.text("Показать полоску", "Show strip")
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(didTapTogglePanelFromDock), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        // Refresh
        let refreshItem = NSMenuItem(title: lang.text("Обновить сейчас", "Refresh now"), action: #selector(didTapRefreshFromDock), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: lang.text("Настройки…", "Settings…"), action: #selector(didTapSettingsFromDock), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        return menu
    }

    @objc private func didSelectFamilyFromDock(_ sender: NSMenuItem) {
        guard let family = sender.representedObject as? Family else { return }
        quotaManager?.switchToFamily(family)
    }

    @objc private func didTapTogglePanelFromDock() {
        guard let manager = quotaManager else { return }
        manager.isVisible.toggle()
        if manager.isVisible {
            stripPanel?.orderFrontRegardless()
        } else {
            stripPanel?.orderOut(nil)
        }
    }

    @objc private func didTapRefreshFromDock() {
        guard let manager = quotaManager else { return }
        manager.fetchFamily(manager.activeFamily, force: true)
    }

    @objc private func didTapSettingsFromDock() {
        openSettings()
    }

    func openSettings() {
        if let win = settingsWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
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
