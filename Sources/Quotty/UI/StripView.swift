import SwiftUI

public struct StripView: View {
    @ObservedObject public var manager: QuotaManager
    public var onOpenSettings: (() -> Void)?

    private let bgCol = Color(red: 22/255, green: 24/255, blue: 30/255)
    private let trackCol = Color(red: 60/255, green: 64/255, blue: 76/255)
    private let greenCol = Color(red: 96/255, green: 196/255, blue: 132/255)
    private let yellowCol = Color(red: 208/255, green: 192/255, blue: 96/255)
    private let orangeCol = Color(red: 214/255, green: 150/255, blue: 74/255)
    private let strongCol = Color(red: 232/255, green: 236/255, blue: 245/255)
    private let dimCol = Color(red: 176/255, green: 184/255, blue: 200/255)

    public init(manager: QuotaManager, onOpenSettings: (() -> Void)? = nil) {
        self.manager = manager
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let animTime = timeline.date.timeIntervalSinceReferenceDate
            let now = timeline.date
            
            VStack(alignment: .leading, spacing: 8) {
                headerView(now: now, animTime: animTime)
                
                let state = manager.currentState
                if let snap = state.last, (state.online || state.rateLimited) {
                    ForEach(snap.limits) { limit in
                        limitRow(limit: limit, now: now, animTime: animTime)
                    }
                } else if !state.online && state.ever {
                    Text("нет данных")
                        .font(.system(size: 11))
                        .foregroundColor(dimCol)
                } else if let err = state.error {
                    Text("ошибка: \(err)")
                        .font(.system(size: 10.5))
                        .foregroundColor(orangeCol)
                        .lineLimit(2)
                } else {
                    Text("загрузка данных…")
                        .font(.system(size: 11))
                        .foregroundColor(dimCol)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(width: 430)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(bgCol.opacity(manager.settings.opacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
            .contextMenu {
                stripContextMenu
            }
        }
    }

    // MARK: - Header
    @ViewBuilder
    private func headerView(now: Date, animTime: Double) -> some View {
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

        HStack {
            if showHeader {
                Text(headerText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(strongCol)
            }
            Spacer()
            statusView(state: state, animTime: animTime)
        }
    }

    @ViewBuilder
    private func statusView(state: FetchState, animTime: Double) -> some View {
        HStack(spacing: 5) {
            if !state.ever && !state.online {
                Text("загрузка…")
                    .font(.system(size: 10.5))
                    .foregroundColor(dimCol)
            } else if state.online {
                Circle()
                    .fill(Color(red: 120/255, green: 205/255, blue: 150/255))
                    .frame(width: 6, height: 6)
                Text("онлайн")
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(red: 120/255, green: 205/255, blue: 150/255))
            } else if state.rateLimited {
                let pulse = 0.45 + 0.55 * (0.5 + 0.5 * sin(animTime * 2.2))
                Circle()
                    .fill(Color(red: 214/255, green: 200/255, blue: 110/255).opacity(pulse))
                    .frame(width: 6, height: 6)
                Text("подключение")
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(red: 214/255, green: 200/255, blue: 110/255))
            } else {
                Circle()
                    .fill(orangeCol)
                    .frame(width: 6, height: 6)
                Text("оффлайн")
                    .font(.system(size: 10.5))
                    .foregroundColor(orangeCol)
            }
        }
    }

    // MARK: - Limit Row
    @ViewBuilder
    private func limitRow(limit: Limit, now: Date, animTime: Double) -> some View {
        let useFrac = min(1.0, max(0.0, limit.usedPercent / 100.0))
        let timeFrac = limit.window?.markerFrac(now: now)
        let exhausted = limit.usedPercent >= 100.0
        let overspend = !exhausted && (timeFrac != nil) && (useFrac > (timeFrac! + 0.02))

        let pctCol: Color = {
            if exhausted { return orangeCol }
            if overspend { return yellowCol }
            return greenCol
        }()

        VStack(spacing: 4) {
            // Text line
            HStack {
                Text(limit.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(strongCol)
                Spacer()
                Text(String(format: "%.0f%%", limit.usedPercent))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(pctCol)
                if let win = limit.window {
                    Text(formatReset(resetsAt: win.resetsAt, now: now))
                        .font(.system(size: 11))
                        .foregroundColor(dimCol)
                } else {
                    Text("окно ещё не начато")
                        .font(.system(size: 11))
                        .foregroundColor(dimCol)
                }
            }

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
                    if exhausted {
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
                    if let mx = markerX {
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

    private func formatReset(resetsAt: Date, now: Date) -> String {
        let diffSecs = Int(resetsAt.timeIntervalSince(now))
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let absStr = timeFormatter.string(from: resetsAt)

        if diffSecs <= 0 {
            return "Resets \(absStr) · сейчас"
        }
        let mins = diffSecs / 60
        let hours = mins / 60
        let remMins = mins % 60
        let days = hours / 24
        let remHours = hours % 24

        let relStr: String
        if days > 0 {
            relStr = "in \(days)d \(remHours)h"
        } else if hours > 0 {
            relStr = "in \(hours)h \(remMins)m"
        } else {
            relStr = "in \(mins)m"
        }

        return "Resets \(absStr) · \(relStr)"
    }

    // MARK: - Context Menu
    @ViewBuilder
    private var stripContextMenu: some View {
        Menu("Инструмент") {
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

        Button("Обновить сейчас") {
            manager.refreshNow()
        }

        Divider()

        Menu("Непрозрачность") {
            Button("50%") { setOpacity(0.5) }
            Button("80%") { setOpacity(0.8) }
            Button("100%") { setOpacity(1.0) }
        }

        Button("Настройки…") {
            onOpenSettings?()
        }

        Divider()

        Button("Выход") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func setOpacity(_ op: Double) {
        var s = manager.settings
        s.opacity = op
        manager.updateSettings(s)
    }
}
