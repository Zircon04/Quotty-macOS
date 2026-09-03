import Foundation

public final class ClaudeProvider: QuotaProvider, @unchecked Sendable {
    public let family: Family = .claude

    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15.0
        self.session = URLSession(configuration: config)
    }

    public func fetch() async throws -> Snapshot {
        guard let token = loadToken() else {
            throw FetchError("Claude Desktop не установлен или не выполнен вход")
        }

        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
            throw FetchError("Invalid Claude URL")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token.access)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("Quotty/0.1", forHTTPHeaderField: "User-Agent")

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

        if http.statusCode == 429 {
            throw FetchError("лимит запросов Anthropic", isRateLimited: true)
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw FetchError("токен Claude недействителен (status \(http.statusCode))")
        }
        if http.statusCode != 200 {
            throw FetchError("status \(http.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError("parse Claude usage json error")
        }

        return parseUsageResponse(json, token: token)
    }

    private struct TokenInfo {
        let access: String
        let subscription: String?
        let tier: String?
    }

    private func loadToken() -> TokenInfo? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidatePaths = [
            home.appendingPathComponent("Library/Application Support/Claude/config.json"),
            home.appendingPathComponent(".claude/config.json"),
            home.appendingPathComponent(".claude.json")
        ]

        for path in candidatePaths {
            guard let data = try? Data(contentsOf: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            // Check for plain or decrypted token caches
            if let tokenStr = json["primaryApiKey"] as? String, !tokenStr.isEmpty {
                return TokenInfo(access: tokenStr, subscription: nil, tier: nil)
            }
            if let oauth = json["oauth"] as? [String: Any],
               let access = oauth["accessToken"] as? String, !access.isEmpty {
                return TokenInfo(access: access, subscription: oauth["subscriptionType"] as? String, tier: oauth["rateLimitTier"] as? String)
            }
        }

        // Also check Keychain if stored
        if let keychainToken = readFromKeychain(service: "Claude", account: "token") {
            return TokenInfo(access: keychainToken, subscription: nil, tier: nil)
        }

        return nil
    }

    private func readFromKeychain(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func parseUsageResponse(_ json: [String: Any], token: TokenInfo) -> Snapshot {
        let now = Date()
        var limits: [Limit] = []

        if let fiveHour = json["five_hour"] as? [String: Any] {
            let util = (fiveHour["utilization"] as? Double) ?? 0.0
            let resetDate: Date? = {
                guard let str = fiveHour["resets_at"] as? String else { return nil }
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return iso.date(from: str) ?? ISO8601DateFormatter().date(from: str)
            }()

            let window = resetDate.map { LimitWindow(resetsAt: $0, lengthSeconds: 5 * 3600, now: now) }
            limits.append(Limit(title: "5-hour limit", usedPercent: util, window: window))
        }

        if let sevenDay = json["seven_day"] as? [String: Any] {
            let util = (sevenDay["utilization"] as? Double) ?? 0.0
            let resetDate: Date? = {
                guard let str = sevenDay["resets_at"] as? String else { return nil }
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return iso.date(from: str) ?? ISO8601DateFormatter().date(from: str)
            }()

            let window = resetDate.map { LimitWindow(resetsAt: $0, lengthSeconds: 7 * 86400, now: now) }
            limits.append(Limit(title: "Weekly · all models", usedPercent: util, window: window))
        }

        let plan = prettyPlan(sub: token.subscription, tier: token.tier)
        return Snapshot(family: .claude, plan: plan, limits: limits)
    }

    private func prettyPlan(sub: String?, tier: String?) -> String {
        guard let s = sub else { return "Claude" }
        if s == "max" {
            if let t = tier {
                if t.contains("20x") { return "Claude Max 20×" }
                if t.contains("5x") { return "Claude Max 5×" }
            }
            return "Claude Max"
        }
        if s == "pro" { return "Claude Pro" }
        return "Claude \(s.capitalized)"
    }
}
