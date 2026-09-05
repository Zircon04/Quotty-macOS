import Foundation
import CoreGraphics

public enum HeaderMode: String, Codable, CaseIterable, Sendable {
    case full = "Full"
    case familyOnly = "FamilyOnly"
    case hidden = "Hidden"
}

public enum ExhaustedMode: String, Codable, CaseIterable, Sendable {
    case compact = "Compact"       // Без полосы (только тонкая строка со сбросом)
    case hidden = "Hidden"         // Полностью скрыть
    case full = "Full"             // С полной полосой
}

public enum ActiveMode: String, Codable, CaseIterable, Sendable {
    case auto = "Auto"
    case pinned = "Pinned"
}

public struct Position: Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct Settings: Codable, Sendable {
    public var opacity: Double = 0.85
    public var pos: Position? = nil
    public var pollSecs: Int = 60
    public var animate: Bool = true
    public var headerMode: HeaderMode = .full
    public var claudeEnabled: Bool = true
    public var codexEnabled: Bool = true
    public var antigravityEnabled: Bool = true
    public var activeMode: ActiveMode = .auto
    public var family: Family = .antigravity
    public var diagnostics: Bool = false
    public var autoHideOnInactive: Bool = true
    public var exhaustedMode: ExhaustedMode = .compact
    public var showInDock: Bool = false
    public var showDockBadge: Bool = true
    public var showWeeklyLimits: Bool = true
    public var compactMode: Bool = false
    public var language: AppLanguage = .russian

    public init() {}

    enum CodingKeys: String, CodingKey {
        case opacity, pos, pollSecs, animate, headerMode
        case claudeEnabled, codexEnabled, antigravityEnabled
        case activeMode, family, diagnostics, autoHideOnInactive, exhaustedMode
        case showInDock, showDockBadge, showWeeklyLimits, compactMode, language
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 0.85
        self.pos = try container.decodeIfPresent(Position.self, forKey: .pos)
        self.pollSecs = try container.decodeIfPresent(Int.self, forKey: .pollSecs) ?? 60
        self.animate = try container.decodeIfPresent(Bool.self, forKey: .animate) ?? true
        self.headerMode = try container.decodeIfPresent(HeaderMode.self, forKey: .headerMode) ?? .full
        self.claudeEnabled = try container.decodeIfPresent(Bool.self, forKey: .claudeEnabled) ?? true
        self.codexEnabled = try container.decodeIfPresent(Bool.self, forKey: .codexEnabled) ?? true
        self.antigravityEnabled = try container.decodeIfPresent(Bool.self, forKey: .antigravityEnabled) ?? true
        self.activeMode = try container.decodeIfPresent(ActiveMode.self, forKey: .activeMode) ?? .auto
        self.family = try container.decodeIfPresent(Family.self, forKey: .family) ?? .antigravity
        self.diagnostics = try container.decodeIfPresent(Bool.self, forKey: .diagnostics) ?? false
        self.autoHideOnInactive = try container.decodeIfPresent(Bool.self, forKey: .autoHideOnInactive) ?? true
        self.exhaustedMode = try container.decodeIfPresent(ExhaustedMode.self, forKey: .exhaustedMode) ?? .compact
        self.showInDock = try container.decodeIfPresent(Bool.self, forKey: .showInDock) ?? false
        self.showDockBadge = try container.decodeIfPresent(Bool.self, forKey: .showDockBadge) ?? true
        self.showWeeklyLimits = try container.decodeIfPresent(Bool.self, forKey: .showWeeklyLimits) ?? true
        self.compactMode = try container.decodeIfPresent(Bool.self, forKey: .compactMode) ?? false
        self.language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .russian
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(opacity, forKey: .opacity)
        try container.encodeIfPresent(pos, forKey: .pos)
        try container.encode(pollSecs, forKey: .pollSecs)
        try container.encode(animate, forKey: .animate)
        try container.encode(headerMode, forKey: .headerMode)
        try container.encode(claudeEnabled, forKey: .claudeEnabled)
        try container.encode(codexEnabled, forKey: .codexEnabled)
        try container.encode(antigravityEnabled, forKey: .antigravityEnabled)
        try container.encode(activeMode, forKey: .activeMode)
        try container.encode(family, forKey: .family)
        try container.encode(diagnostics, forKey: .diagnostics)
        try container.encode(autoHideOnInactive, forKey: .autoHideOnInactive)
        try container.encode(exhaustedMode, forKey: .exhaustedMode)
        try container.encode(showInDock, forKey: .showInDock)
        try container.encode(showDockBadge, forKey: .showDockBadge)
        try container.encode(showWeeklyLimits, forKey: .showWeeklyLimits)
        try container.encode(compactMode, forKey: .compactMode)
        try container.encode(language, forKey: .language)
    }

    public static func settingsDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let quottyDir = appSupport.appendingPathComponent("Quotty", isDirectory: true)
        if !FileManager.default.fileExists(atPath: quottyDir.path) {
            try? FileManager.default.createDirectory(at: quottyDir, withIntermediateDirectories: true)
        }
        return quottyDir
    }

    public static func settingsFilePath() -> URL {
        return settingsDirectory().appendingPathComponent("settings.json")
    }

    public static func load() -> Settings {
        let path = settingsFilePath()
        guard let data = try? Data(contentsOf: path) else {
            return Settings()
        }
        do {
            var s = try JSONDecoder().decode(Settings.self, from: data)
            s.opacity = min(1.0, max(0.15, s.opacity))
            s.pollSecs = max(10, s.pollSecs)
            if !s.claudeEnabled && !s.codexEnabled && !s.antigravityEnabled {
                s.antigravityEnabled = true
            }
            if !s.isEnabled(s.family) {
                s.family = s.firstEnabled()
            }
            return s
        } catch {
            return Settings()
        }
    }

    public func save() {
        let path = Self.settingsFilePath()
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: path, options: .atomic)
        }
    }

    public func isEnabled(_ family: Family) -> Bool {
        switch family {
        case .claude: return claudeEnabled
        case .codex: return codexEnabled
        case .antigravity: return antigravityEnabled
        }
    }

    public mutating func setEnabled(_ family: Family, _ on: Bool) {
        switch family {
        case .claude: claudeEnabled = on
        case .codex: codexEnabled = on
        case .antigravity: antigravityEnabled = on
        }
        if !claudeEnabled && !codexEnabled && !antigravityEnabled {
            setEnabled(family, true)
        }
        if !isEnabled(self.family) {
            self.family = firstEnabled()
        }
    }

    public func firstEnabled() -> Family {
        for f in Family.allCases {
            if isEnabled(f) { return f }
        }
        return .antigravity
    }
}
