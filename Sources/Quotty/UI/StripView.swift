import SwiftUI

public struct ContentHeightPreferenceKey: PreferenceKey {
    public static var defaultValue: CGFloat = 0
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let n = nextValue()
        if n > 0 { value = n }
    }
}

public struct StripView: View {
    @ObservedObject public var manager: QuotaManager
    public var onOpenSettings: (() -> Void)?
    public var onHeightChange: ((CGFloat) -> Void)?

    private let bgCol = Color(red: 22/255, green: 24/255, blue: 30/255)
    private let trackCol = Color(red: 60/255, green: 64/255, blue: 76/255)
    private let greenCol = Color(red: 96/255, green: 196/255, blue: 132/255)
    private let yellowCol = Color(red: 208/255, green: 192/255, blue: 96/255)
    private let orangeCol = Color(red: 214/255, green: 150/255, blue: 74/255)
    private let redCol = Color(red: 255/255, green: 90/255, blue: 90/255)
    private let strongCol = Color(red: 232/255, green: 236/255, blue: 245/255)
    private let dimCol = Color(red: 176/255, green: 184/255, blue: 200/255)

    public init(manager: QuotaManager, onOpenSettings: (() -> Void)? = nil, onHeightChange: ((CGFloat) -> Void)? = nil) {
        self.manager = manager
        self.onOpenSettings = onOpenSettings
        self.onHeightChange = onHeightChange
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let animTime = timeline.date.timeIntervalSinceReferenceDate
            let now = timeline.date
            let lang = manager.settings.language

            let state = manager.currentState
            let allLimits = state.last?.limits ?? []
            let activeLimits = allLimits.filter { !$0.isExhausted }
            let exhaustedLimits = allLimits.filter { $0.isExhausted }

            let visibleLimits: [Limit] = {
                switch manager.settings.exhaustedMode {
                case .full, .compact:
                    return allLimits
                case .hidden:
                    return activeLimits
                }
            }()

            let hiddenExhausted: [Limit] = {
                if manager.settings.exhaustedMode == .hidden {
                    return exhaustedLimits
                }
                return []
            }()

            VStack(alignment: .leading, spacing: 6) {
                headerView(now: now, animTime: animTime, hiddenExhausted: hiddenExhausted, lang: lang)

                if state.last != nil, (state.online || state.rateLimited) {
                    if visibleLimits.isEmpty && !allLimits.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.system(size: 10.5))
                                .foregroundColor(orangeCol)
                            Text(lang.text("Все квоты исчерпаны", "All quotas exhausted"))
                                .font(.system(size: 11))
                                .foregroundColor(dimCol)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    } else {
                        ForEach(visibleLimits) { limit in
                            limitRow(limit: limit, now: now, animTime: animTime, lang: lang)
                        }
                    }
                } else if !state.online && state.ever {
                    Text(lang.text("нет данных", "no data"))
                        .font(.system(size: 11))
                        .foregroundColor(dimCol)
                } else if let err = state.error {
                    Text(lang.text("ошибка: \(err)", "error: \(err)"))
                        .font(.system(size: 10.5))
                        .foregroundColor(orangeCol)
                        .lineLimit(2)
                } else {
                    Text(lang.text("загрузка данных…", "loading data…"))
                        .font(.system(size: 11))
                        .foregroundColor(dimCol)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(width: 430)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(bgCol.opacity(manager.settings.opacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: ContentHeightPreferenceKey.self, value: geo.size.height)
                }
            )
            .onPreferenceChange(ContentHeightPreferenceKey.self) { h in
                if h > 10 {
                    onHeightChange?(h)
                }
            }
            .contextMenu {
                stripContextMenu(lang: lang)
            }
        }
    }

    // MARK: - Header
    @ViewBuilder
    private func headerView(now: Date, animTime: Double, hiddenExhausted: [Limit] = [], lang: AppLanguage) -> some View {
        let state = manager.currentState
        let showHeader = manager.settings.headerMode != .hidden

        let headerText: String = {
            switch manager.settings.headerMode {
            case .hidden: return ""
            case .familyOnly: return manager.activeFamily.name
            case .full:
                return state.last?.plan ?? manager.activeFamily.name
            }
        }()

        HStack(spacing: 6) {
            if showHeader {
                Text(headerText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(strongCol)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 4)

            if !hiddenExhausted.isEmpty {
                HStack(spacing: 4) {
                    ForEach(hiddenExhausted) { item in
                        let name = item.title.split(separator: " ").first.map(String.init) ?? item.title
                        let isWeeklyEx = item.isWeeklyExhausted
                        let tagCol = isWeeklyEx ? redCol : orangeCol
                        HStack(spacing: 3) {
                            Text(lang.text("\(name) сброс:", "\(name) reset:"))
                                .font(.system(size: 10))
                                .foregroundColor(dimCol)
                            if let win = item.window {
                                Text(L10n.formatResetShort(resetsAt: win.resetsAt, now: now, language: lang))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(tagCol)
                            } else {
                                Text(isWeeklyEx ? lang.text("сброс неизвестен", "unknown") : "100%")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(tagCol)
                            }
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(tagCol.opacity(0.15))
                        .cornerRadius(4)
                    }
                }
                .layoutPriority(1)
            }

            statusView(state: state, animTime: animTime, lang: lang)
                .layoutPriority(2)
        }
    }

    @ViewBuilder
    private func statusView(state: FetchState, animTime: Double, lang: AppLanguage) -> some View {
        HStack(spacing: 5) {
            if !state.ever && !state.online {
                Text(lang.text("загрузка…", "loading…"))
                    .font(.system(size: 10.5))
                    .foregroundColor(dimCol)
            } else if state.online {
                Circle()
                    .fill(Color(red: 120/255, green: 205/255, blue: 150/255))
                    .frame(width: 6, height: 6)
                Text(lang.text("онлайн", "online"))
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(red: 120/255, green: 205/255, blue: 150/255))
            } else if state.rateLimited {
                let pulse = 0.45 + 0.55 * (0.5 + 0.5 * sin(animTime * 2.2))
                Circle()
                    .fill(Color(red: 214/255, green: 200/255, blue: 110/255).opacity(pulse))
                    .frame(width: 6, height: 6)
                Text(lang.text("подключение", "connecting…"))
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(red: 214/255, green: 200/255, blue: 110/255))
            } else {
                Circle()
                    .fill(orangeCol)
                    .frame(width: 6, height: 6)
                Text(lang.text("оффлайн", "offline"))
                    .font(.system(size: 10.5))
                    .foregroundColor(orangeCol)
            }
        }
    }

    // MARK: - Limit Row
    @ViewBuilder
    private func limitRow(limit: Limit, now: Date, animTime: Double, lang: AppLanguage) -> some View {
        let useFrac = min(1.0, max(0.0, limit.usedPercent / 100.0))
        let timeFrac = limit.window?.markerFrac(now: now)
        let exhausted = limit.isExhausted
        let weeklyExhausted = limit.isWeeklyExhausted
        let isCompact = manager.settings.compactMode || (exhausted && manager.settings.exhaustedMode == .compact)
        let overspend = !exhausted && (timeFrac != nil) && (useFrac > (timeFrac! + 0.02))

        let pctCol: Color = {
            if weeklyExhausted { return redCol }
            if exhausted { return orangeCol }
            if overspend { return yellowCol }
            return greenCol
        }()

        let titleText = localizedLimitTitle(limit.title, lang: lang)

        VStack(spacing: isCompact ? 0 : 4) {
            // Text line
            HStack(spacing: 6) {
                Text(titleText)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(exhausted ? dimCol : strongCol)

                if weeklyExhausted {
                    Text("Out of Quota")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(redCol)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(redCol.opacity(0.15))
                        .cornerRadius(3)
                } else if manager.settings.showWeeklyLimits {
                    if let weekly = limit.weekly {
                        let wPct = Int(round(weekly.remainingPercent))
                        Text(L10n.weeklyBadge(percent: wPct, language: lang))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(orangeCol)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(orangeCol.opacity(0.15))
                            .cornerRadius(3)
                    } else if let badge = limit.badge {
                        let badgeStr = localizedBadge(badge, lang: lang)
                        Text(badgeStr)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(orangeCol)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(orangeCol.opacity(0.15))
                            .cornerRadius(3)
                    }
                }

                Spacer()

                if !weeklyExhausted {
                    Text(String(format: "%.0f%%", limit.usedPercent))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(pctCol)
                }

                if let win = limit.window {
                    Text(L10n.formatReset(resetsAt: win.resetsAt, now: now, language: lang))
                        .font(.system(size: 11))
                        .foregroundColor(dimCol)
                } else if weeklyExhausted {
                    Text(lang.text("время сброса неизвестно", "reset time unknown"))
                        .font(.system(size: 11))
                        .foregroundColor(dimCol)
                } else {
                    Text(lang.text("окно ещё не начато", "window not started"))
                        .font(.system(size: 11))
                        .foregroundColor(dimCol)
                }
            }

            if !isCompact {
                // Usage bar
                GeometryReader { geo in
                    let w = geo.size.width
                    let h: CGFloat = 11.0
                    let useEnd = w * CGFloat(useFrac)
                    let markerX = timeFrac.map { w * CGFloat($0) }

                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(trackCol.opacity(manager.settings.opacity))
                            .frame(height: h)

                        // Fill
                        if weeklyExhausted {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(redCol)
                                .frame(height: h)
                        } else if exhausted {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(orangeCol)
                                .frame(height: h)
                        } else if let mx = markerX, overspend {
                            // Green up to marker, yellow from marker to useEnd
                            HStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(greenCol)
                                    .frame(width: mx, height: h)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(yellowCol)
                                    .frame(width: max(0, useEnd - mx), height: h)
                            }
                        } else {
                            // Green fill
                            RoundedRectangle(cornerRadius: 4)
                                .fill(greenCol)
                                .frame(width: max(useFrac > 0 ? 3 : 0, useEnd), height: h)

                            // Bubbles rising from spend edge towards marker
                            if manager.settings.animate, let mx = markerX, mx > useEnd + 4 {
                                BubbleCanvas(
                                    startX: useEnd,
                                    endX: min(mx, useEnd + w * 0.35),
                                    height: h,
                                    animTime: animTime
                                )
                                .frame(height: h)
                            }
                        }

                        // White time marker tick
                        if let mx = markerX, !weeklyExhausted {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color(red: 235/255, green: 238/255, blue: 245/255))
                                .frame(width: 2, height: h + 4)
                                .offset(x: mx - 1)
                        }
                    }
                }
                .frame(height: 14)
            }
        }
    }

    private func localizedLimitTitle(_ title: String, lang: AppLanguage) -> String {
        switch title {
        case "limit": return lang.text("Лимит", "Limit")
        case "5-hour limit": return lang.text("Лимит на 5 часов", "5-hour limit")
        case "Weekly · all models": return lang.text("Неделя · все модели", "Weekly · all models")
        case "Monthly limit": return lang.text("Месячный лимит", "Monthly limit")
        default:
            if title.hasSuffix("-day limit") {
                let n = title.replacingOccurrences(of: "-day limit", with: "")
                return lang.text("Лимит на \(n) дн.", "\(n)-day limit")
            }
            if title.hasSuffix("-hour limit") {
                let n = title.replacingOccurrences(of: "-hour limit", with: "")
                return lang.text("Лимит на \(n) ч", "\(n)-hour limit")
            }
            return title
        }
    }

    private func localizedBadge(_ badge: String, lang: AppLanguage) -> String {
        if lang == .english {
            return badge.replacingOccurrences(of: "нед.", with: "wk.")
        }
        return badge
    }

    // MARK: - Context Menu
    @ViewBuilder
    private func stripContextMenu(lang: AppLanguage) -> some View {
        Menu(lang.text("Инструмент", "Tool")) {
            ForEach(Family.allCases, id: \.self) { f in
                Button(action: { manager.switchToFamily(f) }) {
                    if manager.activeFamily == f {
                        Label(f.name, systemImage: "checkmark")
                    } else {
                        Text(f.name)
                    }
                }
            }
        }

        Button(lang.text("Обновить сейчас", "Refresh now")) {
            manager.refreshNow()
        }

        Button(manager.settings.compactMode ?
               lang.text("Обычный режим (с полосами)", "Standard mode (with bars)") :
               lang.text("Компактный режим (без полос)", "Compact mode (no bars)")) {
            var s = manager.settings
            s.compactMode.toggle()
            manager.updateSettings(s)
        }

        Divider()

        Menu(lang.text("Непрозрачность", "Opacity")) {
            Button("50%") { setOpacity(0.5) }
            Button("80%") { setOpacity(0.8) }
            Button("100%") { setOpacity(1.0) }
        }

        Button(lang.text("Настройки…", "Settings…")) {
            onOpenSettings?()
        }

        Divider()

        Button(lang.text("Выход", "Quit")) {
            NSApplication.shared.terminate(nil)
        }
    }

    private func setOpacity(_ op: Double) {
        var s = manager.settings
        s.opacity = op
        manager.updateSettings(s)
    }
}
