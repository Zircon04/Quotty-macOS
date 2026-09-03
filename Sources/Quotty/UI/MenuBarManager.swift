import AppKit
import Foundation

@MainActor
public final class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem!
    private let manager: QuotaManager
    private let onOpenSettings: () -> Void

    public init(manager: QuotaManager, onOpenSettings: @escaping () -> Void) {
        self.manager = manager
        self.onOpenSettings = onOpenSettings
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            if let image = NSImage(systemSymbolName: "gauge.with.dots.needle.50percent", accessibilityDescription: "Quotty")?.withSymbolConfiguration(config) {
                button.image = image
            } else if let fallback = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Quotty") {
                button.image = fallback
            }
            button.toolTip = "Quotty — квоты ИИ-инструментов"
        }

        rebuildMenu()
    }

    public func rebuildMenu() {
        let menu = NSMenu()

        // Status line
        let state = manager.currentState
        let statusTitle: String = {
            if state.online {
                return "\(manager.activeFamily.name) — Онлайн"
            } else if state.rateLimited {
                return "\(manager.activeFamily.name) — Подключение…"
            } else if state.ever {
                return "\(manager.activeFamily.name) — Оффлайн"
            } else {
                return "\(manager.activeFamily.name) — Загрузка…"
            }
        }()
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Family selection
        let switchMenu = NSMenu()
        for f in Family.allCases {
            let item = NSMenuItem(title: f.name, action: #selector(didSelectFamily(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = f
            item.state = (manager.activeFamily == f) ? .on : .off
            switchMenu.addItem(item)
        }
        let switchParent = NSMenuItem(title: "Выбрать инструмент", action: nil, keyEquivalent: "")
        switchParent.submenu = switchMenu
        menu.addItem(switchParent)

        menu.addItem(NSMenuItem.separator())

        // Actions
        let refreshItem = NSMenuItem(title: "Обновить сейчас", action: #selector(didTapRefresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let toggleItem = NSMenuItem(title: manager.isVisible ? "Скрыть полоску" : "Показать полоску", action: #selector(didTapToggleVisibility), keyEquivalent: "h")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Настройки…", action: #selector(didTapSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Выход", action: #selector(didTapQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    @objc private func didSelectFamily(_ sender: NSMenuItem) {
        guard let family = sender.representedObject as? Family else { return }
        manager.switchToFamily(family)
        rebuildMenu()
    }

    @objc private func didTapRefresh() {
        manager.refreshNow()
    }

    @objc private func didTapToggleVisibility() {
        manager.toggleVisibility()
        rebuildMenu()
    }

    @objc private func didTapSettings() {
        onOpenSettings()
    }

    @objc private func didTapQuit() {
        NSApplication.shared.terminate(nil)
    }
}
