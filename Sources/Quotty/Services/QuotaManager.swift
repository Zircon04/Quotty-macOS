import Foundation
import Combine

@MainActor
public final class QuotaManager: ObservableObject {
    @Published public var settings: Settings
    @Published public var activeFamily: Family
    @Published public var states: [Family: FetchState] = [:]
    @Published public var isVisible: Bool = true
    @Published public var isAiActive: Bool = false
    @Published public var isPanelVisible: Bool = true

    private let providers: [Family: QuotaProvider]
    private var detector: ActiveAppDetector?
    private var pollTasks: [Family: Task<Void, Never>] = [:]
    private var dueTimes: [Family: Date] = [:]
    private var backoffs: [Family: Double] = [:]

    public init() {
        let s = Settings.load()
        self.settings = s
        self.activeFamily = s.family

        self.providers = [
            .antigravity: AntigravityProvider(),
            .codex: CodexProvider(),
            .claude: ClaudeProvider()
        ]

        for f in Family.allCases {
            self.states[f] = FetchState()
            self.backoffs[f] = 5.0
            self.dueTimes[f] = Date()
        }

        setupDetector()
        updatePanelVisibility()
        startPolling()
        fetchFamily(activeFamily, force: true)
    }

    private func setupDetector() {
        let det = ActiveAppDetector()
        det.onAiStateChanged = { [weak self] isAi, family in
            guard let self = self else { return }
            let isEnabled = (family == nil) ? true : self.settings.isEnabled(family!)
            let effectiveAiActive = isAi && isEnabled

            self.isAiActive = effectiveAiActive

            if isAi, let detected = family {
                if self.settings.activeMode == .auto && self.settings.isEnabled(detected) {
                    self.switchToFamily(detected)
                }
            }

            self.updatePanelVisibility()
        }
        self.detector = det
        det.pollNow()
    }

    public func updatePanelVisibility() {
        let shouldShow: Bool
        if !isVisible {
            shouldShow = false
        } else if settings.autoHideOnInactive {
            shouldShow = isAiActive
        } else {
            shouldShow = true
        }
        if isPanelVisible != shouldShow {
            isPanelVisible = shouldShow
        }
    }

    public func switchToFamily(_ family: Family) {
        guard settings.isEnabled(family) else { return }
        if activeFamily != family {
            activeFamily = family
            settings.family = family
            settings.save()
            // Immediately poll the newly selected family
            fetchFamily(family, force: true)
        }
    }

    public func refreshNow() {
        for f in Family.allCases where settings.isEnabled(f) {
            fetchFamily(f, force: true)
        }
    }

    public func updateSettings(_ newSettings: Settings) {
        self.settings = newSettings
        self.settings.save()
        if !settings.isEnabled(activeFamily) {
            activeFamily = settings.firstEnabled()
        }
        updatePanelVisibility()
    }

    public func toggleVisibility() {
        isVisible.toggle()
        updatePanelVisibility()
    }

    private func startPolling() {
        // Poller loop running every 1 second checking due times
        Task {
            while !Task.isCancelled {
                let now = Date()
                for family in Family.allCases {
                    guard settings.isEnabled(family) else { continue }
                    let due = dueTimes[family] ?? now
                    if now >= due {
                        fetchFamily(family, force: false)
                    }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    public func fetchFamily(_ family: Family, force: Bool) {
        guard let provider = providers[family] else { return }

        // Cancel running task if forcing
        if force {
            pollTasks[family]?.cancel()
        } else if pollTasks[family] != nil {
            return
        }

        pollTasks[family] = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let snapshot = try await provider.fetch()
                await MainActor.run {
                    var state = self.states[family] ?? FetchState()
                    state.last = snapshot
                    state.online = true
                    state.ever = true
                    state.error = nil
                    state.rateLimited = false
                    self.states[family] = state

                    self.backoffs[family] = 5.0
                    let interval = Double(self.settings.pollSecs)
                    self.dueTimes[family] = Date().addingTimeInterval(interval)
                    self.pollTasks[family] = nil
                }
            } catch {
                await MainActor.run {
                    var state = self.states[family] ?? FetchState()
                    state.online = false
                    let isRateLimited = (error as? FetchError)?.isRateLimited ?? false
                    state.rateLimited = isRateLimited
                    state.error = (error as? FetchError)?.message ?? error.localizedDescription
                    self.states[family] = state

                    let currentBackoff = self.backoffs[family] ?? 5.0
                    let nextBackoff = min(120.0, currentBackoff * 2.0)
                    self.backoffs[family] = nextBackoff
                    self.dueTimes[family] = Date().addingTimeInterval(currentBackoff)
                    self.pollTasks[family] = nil
                }
            }
        }
    }

    public var currentState: FetchState {
        return states[activeFamily] ?? FetchState()
    }

    public var lowestRemainingPercent: Int? {
        guard let snapshot = currentState.last, !snapshot.limits.isEmpty else { return nil }
        let maxUsed = snapshot.limits.map(\.usedPercent).max() ?? 0.0
        return max(0, min(100, Int(round(100.0 - maxUsed))))
    }
}
