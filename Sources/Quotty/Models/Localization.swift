import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case russian = "russian"
    case english = "english"

    public var displayName: String {
        switch self {
        case .russian: return "Русский"
        case .english: return "English"
        }
    }

    public func text(_ ru: String, _ en: String) -> String {
        switch self {
        case .russian: return ru
        case .english: return en
        }
    }
}

public enum L10n {
    public static func limitTitle(seconds: Int64, language: AppLanguage) -> String {
        switch language {
        case .russian:
            switch seconds {
            case ..<0:
                return "Лимит"
            case 17000...19000:
                return "Лимит на 5 часов"
            case 600000...700000:
                return "Неделя · все модели"
            case 2500000...2700000:
                return "Месячный лимит"
            default:
                if seconds % 86400 == 0 {
                    return "Лимит на \(seconds / 86400) дн."
                }
                return "Лимит на \((seconds + 1800) / 3600) ч"
            }
        case .english:
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
    }

    public static func formatReset(resetsAt: Date, now: Date, language: AppLanguage) -> String {
        let diffSecs = Int(resetsAt.timeIntervalSince(now))
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let absStr = timeFormatter.string(from: resetsAt)

        let prefix = language.text("Сброс", "Resets")
        if diffSecs <= 0 {
            return "\(prefix) \(absStr) · \(language.text("сейчас", "now"))"
        }
        let mins = diffSecs / 60
        let hours = mins / 60
        let remMins = mins % 60
        let days = hours / 24
        let remHours = hours % 24

        let inWord = language.text("через", "in")
        let dWord = language.text("д", "d")
        let hWord = language.text("ч", "h")
        let mWord = language.text("м", "m")

        let relStr: String
        if days > 0 {
            relStr = "\(inWord) \(days)\(dWord) \(remHours)\(hWord)"
        } else if hours > 0 {
            relStr = "\(inWord) \(hours)\(hWord) \(remMins)\(mWord)"
        } else {
            relStr = "\(inWord) \(mins)\(mWord)"
        }

        return "\(prefix) \(absStr) · \(relStr)"
    }

    public static func formatResetShort(resetsAt: Date, now: Date, language: AppLanguage) -> String {
        let diffSecs = Int(resetsAt.timeIntervalSince(now))
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let absStr = timeFormatter.string(from: resetsAt)

        if diffSecs <= 0 {
            return "\(absStr) (\(language.text("сейчас", "now")))"
        }
        let mins = diffSecs / 60
        let hours = mins / 60
        let remMins = mins % 60
        let days = hours / 24
        let remHours = hours % 24

        let dWord = language.text("д", "d")
        let hWord = language.text("ч", "h")
        let mWord = language.text("м", "m")

        let relStr: String
        if days > 0 {
            relStr = "\(days)\(dWord) \(remHours)\(hWord)"
        } else if hours > 0 {
            relStr = "\(hours)\(hWord) \(remMins)\(mWord)"
        } else {
            relStr = "\(mins)\(mWord)"
        }

        return "\(absStr) (\(relStr))"
    }

    public static func weeklyBadge(percent: Int, language: AppLanguage) -> String {
        let prefix = language.text("нед.", "wk.")
        return "\(prefix) \(percent)%"
    }
}
