import Foundation
import CoreGraphics

public enum HeaderMode: String, Codable, CaseIterable, Sendable {
    case full = "Full"
    case familyOnly = "FamilyOnly"
    case hidden = "Hidden"
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

    public init() {}

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
