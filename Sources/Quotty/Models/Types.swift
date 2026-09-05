import Foundation

public enum Family: String, Codable, CaseIterable, Sendable {
    case claude = "Claude"
    case codex = "Codex"
    case antigravity = "Antigravity"

    public var idx: Int {
        switch self {
        case .claude: return 0
        case .codex: return 1
        case .antigravity: return 2
        }
    }

    public var name: String {
        return self.rawValue
    }
}

public struct LimitWindow: Sendable {
    public let start: Date?
    public let resetsAt: Date

    public init(resetsAt: Date, lengthSeconds: TimeInterval, now: Date = Date()) {
        let calculatedStart = resetsAt.addingTimeInterval(-lengthSeconds)
        self.start = (calculatedStart <= now) ? calculatedStart : nil
        self.resetsAt = resetsAt
    }

    public func markerFrac(now: Date = Date()) -> Double {
        return elapsedFrac(now: now) ?? 0.0
    }

    public func elapsedFrac(now: Date = Date()) -> Double? {
        guard let start = self.start else { return nil }
        let total = max(1.0, resetsAt.timeIntervalSince(start))
        let elapsed = max(0.0, min(total, now.timeIntervalSince(start)))
        return min(1.0, max(0.0, elapsed / total))
    }
}

public struct WeeklyQuota: Sendable {
    public let remainingPercent: Double
    public let resetsAt: Date?

    public init(remainingPercent: Double, resetsAt: Date?) {
        self.remainingPercent = remainingPercent
        self.resetsAt = resetsAt
    }
}

public struct Limit: Sendable, Identifiable {
    public var id: String { title }
    public let title: String
    public let usedPercent: Double
    public let window: LimitWindow?
    public let badge: String?
    public let weekly: WeeklyQuota?

    public init(title: String, usedPercent: Double, window: LimitWindow?, badge: String? = nil, weekly: WeeklyQuota? = nil) {
        self.title = title
        self.usedPercent = usedPercent
        self.window = window
        self.badge = badge
        self.weekly = weekly
    }

    public var isWeeklyExhausted: Bool {
        guard let w = weekly else { return false }
        return w.remainingPercent <= 0.0
    }

    public var isExhausted: Bool {
        return isWeeklyExhausted || usedPercent >= 99.5
    }
}

public struct Snapshot: Sendable {
    public let family: Family
    public let plan: String
    public let limits: [Limit]

    public init(family: Family, plan: String, limits: [Limit]) {
        self.family = family
        self.plan = plan
        self.limits = limits
    }
}

public struct FetchError: Error, Sendable {
    public let message: String
    public let isRateLimited: Bool

    public init(_ message: String, isRateLimited: Bool = false) {
        self.message = message
        self.isRateLimited = isRateLimited
    }
}

public struct FetchState: Sendable {
    public var last: Snapshot?
    public var online: Bool = false
    public var ever: Bool = false
    public var error: String? = nil
    public var rateLimited: Bool = false

    public init() {}
}

public func windowTitle(seconds: Int64, language: AppLanguage = .russian) -> String {
    return L10n.limitTitle(seconds: seconds, language: language)
}
