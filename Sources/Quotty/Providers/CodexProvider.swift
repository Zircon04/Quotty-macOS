import Foundation

public final class CodexProvider: QuotaProvider, @unchecked Sendable {
    public let family: Family = .codex

    private struct Auth {
        let accessToken: String
        let accountId: String?
    }

    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        self.session = URLSession(configuration: config)
    }

    public func fetch() async throws -> Snapshot {
        let auth = try loadAuth()

        guard let url = URL(string: "https://chatgpt.com/backend-api/codex/usage") else {
            throw FetchError("Invalid Codex URL")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("codex-cli/0.152.1", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accId = auth.accountId, !accId.isEmpty {
            req.setValue(accId, forHTTPHeaderField: "chatgpt-account-id")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw FetchError("network: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw FetchError("Неверный ответ сервера")
        }

        if http.statusCode == 401 {
            throw FetchError("токен Codex устарел — войдите в Codex")
        }
        if http.statusCode == 403 || http.statusCode == 404 {
            throw FetchError("ошибка \(http.statusCode): Cloudflare/прокси блокирует chatgpt.com")
        }
        if http.statusCode == 429 {
            throw FetchError("лимит запросов OpenAI", isRateLimited: true)
        }
        if http.statusCode != 200 {
            throw FetchError("status \(http.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError("parse usage json error")
        }

        return parseUsageResponse(json)
    }

    private func loadAuth() throws -> Auth {
        let codexHome: URL = {
            if let custom = ProcessInfo.processInfo.environment["CODEX_HOME"], !custom.isEmpty {
                return URL(fileURLWithPath: custom)
            }
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        }()

        let authPath = codexHome.appendingPathComponent("auth.json")
        guard FileManager.default.fileExists(atPath: authPath.path) else {
            throw FetchError("Codex не найден (~/.codex/auth.json отсутствует)")
        }

        guard let data = try? Data(contentsOf: authPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let access = tokens["access_token"] as? String, !access.isEmpty else {
            throw FetchError("в auth.json нет access_token (войдите в Codex)")
        }

        let accountId = tokens["account_id"] as? String
        return Auth(accessToken: access, accountId: accountId)
    }

    private func parseUsageResponse(_ json: [String: Any]) -> Snapshot {
        let now = Date()
        let planType = json["plan_type"] as? String
        let planTitle = prettyPlan(planType)

        var limits: [Limit] = []
        if let rateLimit = json["rate_limit"] as? [String: Any] {
            let primary = rateLimit["primary_window"] as? [String: Any]
            let secondary = rateLimit["secondary_window"] as? [String: Any]

            for windowDict in [primary, secondary].compactMap({ $0 }) {
                if let lim = toLimit(windowDict, now: now) {
                    limits.append(lim)
                }
            }
        }

        return Snapshot(family: .codex, plan: planTitle, limits: limits)
    }

    private func toLimit(_ w: [String: Any], now: Date) -> Limit? {
        guard let used = w["used_percent"] as? Double else { return nil }

        let resetsAt: Date? = {
            if let resetAtNum = w["reset_at"] as? Double {
                return Date(timeIntervalSince1970: resetAtNum)
            }
            if let afterSecs = w["reset_after_seconds"] as? Double {
                return now.addingTimeInterval(afterSecs)
            }
            return nil
        }()

        guard let reset = resetsAt else { return nil }

        let windowSecs: TimeInterval = {
            if let limWindow = w["limit_window_seconds"] as? Double {
                return limWindow
            }
            return max(1.0, reset.timeIntervalSince(now))
        }()

        let title = windowTitle(seconds: Int64(windowSecs))
        let limitWindow = LimitWindow(resetsAt: reset, lengthSeconds: windowSecs, now: now)

        return Limit(title: title, usedPercent: used, window: limitWindow)
    }

    private func prettyPlan(_ plan: String?) -> String {
        guard let p = plan, !p.isEmpty else { return "Codex" }
        return "Codex \(p.capitalized)"
    }
}
