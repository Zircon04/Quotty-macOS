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
        let lang = manager.settings.language

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
                Text(lang.text("Quotty — настройки", "Quotty — Settings"))
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
                    languageCard(lang: lang)
                    toolsCard(lang: lang)
                    appearanceCard(lang: lang)
                    pollingCard(lang: lang)
                    diagnosticsCard(lang: lang)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 480, height: 600)
        .background(bgCol)
        .preferredColorScheme(.dark)
    }

    // MARK: - Cards
    private func languageCard(lang: AppLanguage) -> some View {
        cardView(title: lang.text("ЯЗЫК", "LANGUAGE")) {
            HStack {
                Text(lang.text("Язык интерфейса:", "Interface language:"))
                    .font(.system(size: 12))
                    .foregroundColor(dimCol)
                Spacer()
                Picker("", selection: Binding(
                    get: { manager.settings.language },
                    set: {
                        var s = manager.settings
                        s.language = $0
                        manager.updateSettings(s)
                    }
                )) {
                    ForEach(AppLanguage.allCases, id: \.self) { l in
                        Text(l.displayName).tag(l)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
    }

    private func toolsCard(lang: AppLanguage) -> some View {
        cardView(title: lang.text("ИНСТРУМЕНТЫ", "TOOLS")) {
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
                    Text(lang.text("Режим переключения:", "Switching mode:"))
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
                        Text(lang.text("Авто (по окну)", "Auto (active window)")).tag(ActiveMode.auto)
                        Text(lang.text("Закрепить", "Pinned")).tag(ActiveMode.pinned)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                }

                if manager.settings.activeMode == .pinned {
                    HStack {
                        Text(lang.text("Закреплённый инструмент:", "Pinned tool:"))
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

    private func appearanceCard(lang: AppLanguage) -> some View {
        cardView(title: lang.text("ОТОБРАЖЕНИЕ", "APPEARANCE")) {
            VStack(alignment: .leading, spacing: 12) {
                // Opacity slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(lang.text("Непрозрачность:", "Opacity:"))
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
                    Text(lang.text("Заголовок полоски:", "Strip header:"))
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
                        Text(lang.text("Полный", "Full")).tag(HeaderMode.full)
                        Text(lang.text("Только имя", "Family only")).tag(HeaderMode.familyOnly)
                        Text(lang.text("Скрыть", "Hidden")).tag(HeaderMode.hidden)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                }

                Divider().background(cardHiCol)

                // Exhausted Quotas Mode
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang.text("Исчерпанная квота (100%):", "Exhausted quota (100%):"))
                            .font(.system(size: 12))
                            .foregroundColor(dimCol)
                        Text(exhaustedModeSubtitle(lang: lang))
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
                        Text(lang.text("Без полосы", "Compact")).tag(ExhaustedMode.compact)
                        Text(lang.text("Скрыть", "Hidden")).tag(ExhaustedMode.hidden)
                        Text(lang.text("С полосой", "Full")).tag(ExhaustedMode.full)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                }

                Divider().background(cardHiCol)

                // Auto-hide when not in AI window
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(lang.text("Показывать только в окне ИИ", "Show only in AI window"), isOn: Binding(
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

                    Text(lang.text("Скрывать полоску при переходе на другие приложения", "Hide strip when switching to other apps"))
                        .font(.system(size: 11))
                        .foregroundColor(dimCol)
                        .padding(.leading, 18)
                }

                Divider().background(cardHiCol)

                // Compact mode
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(lang.text("Компактный режим (без полос)", "Compact mode (no bars)"), isOn: Binding(
                        get: { manager.settings.compactMode },
                        set: {
                            var s = manager.settings
                            s.compactMode = $0
                            manager.updateSettings(s)
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .foregroundColor(textCol)

                    Text(lang.text("Скрывать графические полосы для всех моделей, оставляя только текст", "Hide graphical bars for all models, showing text only"))
                        .font(.system(size: 11))
                        .foregroundColor(dimCol)
                        .padding(.leading, 18)
                }

                Divider().background(cardHiCol)

                // Show weekly limits
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(lang.text("Показывать остаток недельных лимитов", "Show weekly limits remaining"), isOn: Binding(
                        get: { manager.settings.showWeeklyLimits },
                        set: {
                            var s = manager.settings
                            s.showWeeklyLimits = $0
                            manager.updateSettings(s)
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .foregroundColor(textCol)

                    Text(lang.text("Отображать бейдж [нед. Х%] рядом с названием модели", "Display [wk. X%] badge next to model title"))
                        .font(.system(size: 11))
                        .foregroundColor(dimCol)
                        .padding(.leading, 18)
                }

                Divider().background(cardHiCol)

                // Animation
                Toggle(lang.text("Анимация пузырьков (при расходе с запасом)", "Bubble animation (when pacing with surplus)"), isOn: Binding(
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
                    Toggle(lang.text("Показывать иконку в Dock", "Show icon in Dock"), isOn: Binding(
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

                    Text(lang.text("Отображать Quotty на панели Dock и в переключателе Cmd+Tab", "Show Quotty in Dock and Cmd+Tab app switcher"))
                        .font(.system(size: 11))
                        .foregroundColor(dimCol)
                        .padding(.leading, 18)

                    if manager.settings.showInDock {
                        Toggle(lang.text("Бейдж с остатком квоты на значке", "Quota remaining badge on icon"), isOn: Binding(
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

    private func pollingCard(lang: AppLanguage) -> some View {
        cardView(title: lang.text("ОПРОС И ОБНОВЛЕНИЕ", "POLLING & UPDATES")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(lang.text("Интервал обновления:", "Polling interval:"))
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
                        Text(lang.text("15 сек", "15 s")).tag(15)
                        Text(lang.text("30 сек", "30 s")).tag(30)
                        Text(lang.text("60 сек (по умолчанию)", "60 s (default)")).tag(60)
                        Text(lang.text("2 мин", "2 min")).tag(120)
                        Text(lang.text("5 мин", "5 min")).tag(300)
                    }
                    .frame(width: 180)
                }

                HStack {
                    Spacer()
                    Button(lang.text("Обновить данные сейчас", "Refresh data now")) {
                        manager.refreshNow()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentCol)
                    .controlSize(.small)
                }
            }
        }
    }

    private func diagnosticsCard(lang: AppLanguage) -> some View {
        cardView(title: lang.text("ДИАГНОСТИКА", "DIAGNOSTICS")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(lang.text("Папка настроек Quotty", "Quotty settings folder"))
                        .font(.system(size: 12))
                        .foregroundColor(dimCol)
                    Spacer()
                    Button(lang.text("Открыть в Finder", "Reveal in Finder")) {
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

    private func exhaustedModeSubtitle(lang: AppLanguage) -> String {
        switch manager.settings.exhaustedMode {
        case .compact:
            return lang.text("Только текст и сброс, без шкалы", "Text and reset only, no bar")
        case .hidden:
            return lang.text("Скрыть из списка, таймер в шапке", "Hide from list, timer in header")
        case .full:
            return lang.text("Показывать шкалу целиком", "Show full bar")
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
