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

public struct Limit: Sendable, Identifiable {
    public var id: String { title }
    public let title: String
    public let usedPercent: Double
    public let window: LimitWindow?

    public init(title: String, usedPercent: Double, window: LimitWindow?) {
        self.title = title
        self.usedPercent = usedPercent
        self.window = window
    }

    public var isExhausted: Bool {
        return usedPercent >= 99.5
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

public func windowTitle(seconds: Int64) -> String {
    switch seconds {
    case ..<0:
        return "limit"
    case 17000...19000:
        return "5-hour limit"
    case 600000...700000:
        return "Weekly · all models"
    case 2500000...2700000:
        return "Monthly limit"
    default:
        if seconds % 86400 == 0 {
            return "\(seconds / 86400)-day limit"
        }
        return "\((seconds + 1800) / 3600)-hour limit"
    }
}
