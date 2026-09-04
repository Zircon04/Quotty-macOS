import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject public var manager: QuotaManager
    public var onClose: (() -> Void)?

    private let bgCol = Color(red: 18/255, green: 20/255, blue: 26/255)
    private let cardCol = Color(red: 30/255, green: 33/255, blue: 42/255)
    private let cardHiCol = Color(red: 48/255, green: 53/255, blue: 65/255)
    private let accentCol = Color(red: 110/255, green: 210/255, blue: 146/255)
    private let textCol = Color(red: 234/255, green: 238/255, blue: 246/255)
    private let dimCol = Color(red: 176/255, green: 184/255, blue: 200/255)

    public init(manager: QuotaManager, onClose: (() -> Void)? = nil) {
        self.manager = manager
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack(spacing: 8) {
                if let icon = AppAssets.appIcon() {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .cornerRadius(5)
                }
                Text("Quotty — настройки")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(textCol)
                Spacer()
                Button(action: { onClose?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(dimCol)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 14) {
                    toolsCard
                    appearanceCard
                    pollingCard
                    diagnosticsCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 480, height: 560)
        .background(bgCol)
        .preferredColorScheme(.dark)
    }

    // MARK: - Cards
    private var toolsCard: some View {
        cardView(title: "ИНСТРУМЕНТЫ") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 16) {
                    Toggle("Antigravity", isOn: Binding(
                        get: { manager.settings.antigravityEnabled },
                        set: { setFamilyEnabled(.antigravity, $0) }
                    ))
                    Toggle("Codex", isOn: Binding(
                        get: { manager.settings.codexEnabled },
                        set: { setFamilyEnabled(.codex, $0) }
                    ))
                    Toggle("Claude", isOn: Binding(
                        get: { manager.settings.claudeEnabled },
                        set: { setFamilyEnabled(.claude, $0) }
                    ))
                }
                .toggleStyle(.checkbox)
                .foregroundColor(textCol)

                Divider().background(cardHiCol)

                HStack {
                    Text("Режим переключения:")
                        .font(.system(size: 12))
                        .foregroundColor(dimCol)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { manager.settings.activeMode },
                        set: {
                            var s = manager.settings
                            s.activeMode = $0
                            manager.updateSettings(s)
                        }
                    )) {
                        Text("Авто (по окну)").tag(ActiveMode.auto)
                        Text("Закрепить").tag(ActiveMode.pinned)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                }

                if manager.settings.activeMode == .pinned {
                    HStack {
                        Text("Закреплённый инструмент:")
                            .font(.system(size: 12))
                            .foregroundColor(dimCol)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { manager.activeFamily },
                            set: { manager.switchToFamily($0) }
                        )) {
                            ForEach(Family.allCases, id: \.self) { f in
                                if manager.settings.isEnabled(f) {
                                    Text(f.name).tag(f)
                                }
                            }
                        }
                        .frame(width: 140)
                    }
                }
            }
        }
    }

    private var appearanceCard: some View {
        cardView(title: "ОТОБРАЖЕНИЕ") {
            VStack(alignment: .leading, spacing: 12) {
                // Opacity slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Непрозрачность:")
                            .font(.system(size: 12))
                            .foregroundColor(dimCol)
                        Spacer()
                        Text("\(Int(manager.settings.opacity * 100))%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(accentCol)
                    }
                    HStack(spacing: 12) {
                        Slider(value: Binding(
                            get: { manager.settings.opacity },
                            set: {
                                var s = manager.settings
                                s.opacity = $0
                                manager.updateSettings(s)
                            }
                        ), in: 0.15...1.0)
                        .tint(accentCol)

                        Button("50%") { setOpacity(0.5) }.buttonStyle(.bordered).controlSize(.small)
                        Button("80%") { setOpacity(0.8) }.buttonStyle(.bordered).controlSize(.small)
                        Button("100%") { setOpacity(1.0) }.buttonStyle(.bordered).controlSize(.small)
                    }
                }

                Divider().background(cardHiCol)

                // Header Mode
                HStack {
                    Text("Заголовок полоски:")
                        .font(.system(size: 12))
                        .foregroundColor(dimCol)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { manager.settings.headerMode },
                        set: {
                            var s = manager.settings
                            s.headerMode = $0
                            manager.updateSettings(s)
                        }
                    )) {
                        Text("Полный").tag(HeaderMode.full)
                        Text("Только имя").tag(HeaderMode.familyOnly)
                        Text("Скрыть").tag(HeaderMode.hidden)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                }

                Divider().background(cardHiCol)

                // Exhausted Quotas Mode
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Исчерпанная квота (100%):")
                            .font(.system(size: 12))
                            .foregroundColor(dimCol)
                        Text(exhaustedModeSubtitle)
                            .font(.system(size: 10))
                            .foregroundColor(dimCol.opacity(0.8))
                    }
                    Spacer()
                    Picker("", selection: Binding(
                        get: { manager.settings.exhaustedMode },
                        set: {
                            var s = manager.settings
                            s.exhaustedMode = $0
                            manager.updateSettings(s)
                        }
                    )) {
                        Text("Без полосы").tag(ExhaustedMode.compact)
                        Text("Скрыть").tag(ExhaustedMode.hidden)
                        Text("С полосой").tag(ExhaustedMode.full)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                }

                Divider().background(cardHiCol)

                // Auto-hide when not in AI window
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Показывать только в окне ИИ", isOn: Binding(
                        get: { manager.settings.autoHideOnInactive },
                        set: {
                            var s = manager.settings
                            s.autoHideOnInactive = $0
                            manager.updateSettings(s)
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .foregroundColor(textCol)

                    Text("Скрывать полоску при переходе на другие приложения")
                        .font(.system(size: 11))
                        .foregroundColor(dimCol)
                        .padding(.leading, 18)
                }

                Divider().background(cardHiCol)

                // Animation
                Toggle("Анимация пузырьков (при расходе с запасом)", isOn: Binding(
                    get: { manager.settings.animate },
                    set: {
                        var s = manager.settings
                        s.animate = $0
                        manager.updateSettings(s)
                    }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
                .foregroundColor(textCol)

                Divider().background(cardHiCol)

                // Dock settings
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Показывать иконку в Dock", isOn: Binding(
                        get: { manager.settings.showInDock },
                        set: {
                            var s = manager.settings
                            s.showInDock = $0
                            manager.updateSettings(s)
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .foregroundColor(textCol)

                    Text("Отображать Quotty на панели Dock и в переключателе Cmd+Tab")
                        .font(.system(size: 11))
                        .foregroundColor(dimCol)
                        .padding(.leading, 18)

                    if manager.settings.showInDock {
                        Toggle("Бейдж с остатком квоты на значке", isOn: Binding(
                            get: { manager.settings.showDockBadge },
                            set: {
                                var s = manager.settings
                                s.showDockBadge = $0
                                manager.updateSettings(s)
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12))
                        .foregroundColor(textCol)
                        .padding(.leading, 18)
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    private var pollingCard: some View {
        cardView(title: "ОПРОС И ОБНОВЛЕНИЕ") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Интервал обновления:")
                        .font(.system(size: 12))
                        .foregroundColor(dimCol)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { manager.settings.pollSecs },
                        set: {
                            var s = manager.settings
                            s.pollSecs = $0
                            manager.updateSettings(s)
                        }
                    )) {
                        Text("15 сек").tag(15)
                        Text("30 сек").tag(30)
                        Text("60 сек (по умолчанию)").tag(60)
                        Text("2 мин").tag(120)
                        Text("5 мин").tag(300)
                    }
                    .frame(width: 180)
                }

                HStack {
                    Spacer()
                    Button("Обновить данные сейчас") {
                        manager.refreshNow()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentCol)
                    .controlSize(.small)
                }
            }
        }
    }

    private var diagnosticsCard: some View {
        cardView(title: "ДИАГНОСТИКА") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Папка настроек Quotty")
                        .font(.system(size: 12))
                        .foregroundColor(dimCol)
                    Spacer()
                    Button("Открыть в Finder") {
                        let dir = Settings.settingsDirectory()
                        NSWorkspace.shared.open(dir)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private func cardView<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundColor(dimCol)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(12)
            .background(cardCol)
            .cornerRadius(8)
        }
    }

    private var exhaustedModeSubtitle: String {
        switch manager.settings.exhaustedMode {
        case .compact:
            return "Только текст и сброс, без шкалы"
        case .hidden:
            return "Скрыть из списка, таймер в шапке"
        case .full:
            return "Показывать шкалу целиком"
        }
    }

    private func setFamilyEnabled(_ family: Family, _ on: Bool) {
        var s = manager.settings
        s.setEnabled(family, on)
        manager.updateSettings(s)
    }

    private func setOpacity(_ op: Double) {
        var s = manager.settings
        s.opacity = op
        manager.updateSettings(s)
    }
}
