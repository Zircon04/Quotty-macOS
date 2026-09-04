import Foundation

final class LocalhostCertDelegate: NSObject, URLSessionDelegate, Sendable {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let host = challenge.protectionSpace.host as String?,
           (host == "127.0.0.1" || host == "localhost"),
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

public final class AntigravityProvider: QuotaProvider, @unchecked Sendable {
    public let family: Family = .antigravity

    private struct Endpoint {
        let port: UInt16
        let csrf: String
    }

    private actor EndpointCache {
        private var lastGood: Endpoint?

        func getReorderedEndpoints(from list: [Endpoint]) -> [Endpoint] {
            var copy = list
            if let last = lastGood {
                copy.removeAll { $0.port == last.port && $0.csrf == last.csrf }
                copy.insert(last, at: 0)
            }
            return copy
        }

        func recordSuccess(endpoint: Endpoint) {
            self.lastGood = endpoint
        }
    }

    private let session: URLSession
    private let cache = EndpointCache()

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 5.0
        let delegate = LocalhostCertDelegate()
        self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    public func fetch() async throws -> Snapshot {
        let discovered = discoverEndpoints()
        let endpoints = await cache.getReorderedEndpoints(from: discovered)

        if endpoints.isEmpty {
            throw FetchError("Antigravity не запущен")
        }

        var lastError: Error?
        for ep in endpoints {
            do {
                let snapshot = try await callGetUserStatus(endpoint: ep)
                await cache.recordSuccess(endpoint: ep)
                return snapshot
            } catch {
                lastError = error
            }
        }

        throw FetchError("Antigravity не отвечает (\(lastError?.localizedDescription ?? "ошибка подключения"))")
    }

    private func discoverEndpoints() -> [Endpoint] {
        var endpoints: [Endpoint] = []

        // 1. Check running language_server processes
        endpoints.append(contentsOf: findEndpointsFromProcesses())

        // 2. Check ~/.gemini/*/daemon/ls_*.json
        endpoints.append(contentsOf: findEndpointsFromDaemonFiles())

        // 3. Check logs
        endpoints.append(contentsOf: findEndpointsFromLogs())

        // Deduplicate
        var unique: [Endpoint] = []
        for ep in endpoints {
            if !unique.contains(where: { $0.port == ep.port && $0.csrf == ep.csrf }) {
                unique.append(ep)
            }
        }
        return unique
    }

    private func runProcess(executable: String, arguments: [String]) -> String? {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = arguments
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func findEndpointsFromProcesses() -> [Endpoint] {
        var results: [Endpoint] = []
        guard let output = runProcess(executable: "/bin/ps", arguments: ["-eo", "pid,command"]) else {
            return []
        }

        for line in output.components(separatedBy: .newlines) {
            guard line.contains("language_server") && line.contains("--csrf_token") else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let pid = Int32(parts[0]) else { continue }
            let cmd = String(parts[1])

            guard let csrf = extractFlagValue(cmd: cmd, flag: "--csrf_token") else { continue }
            let ports = findListeningPorts(pid: pid)

            // Pick candidate ports
            for port in ports {
                results.append(Endpoint(port: port, csrf: csrf))
            }
        }

        return results
    }

    private func extractFlagValue(cmd: String, flag: String) -> String? {
        guard let range = cmd.range(of: flag) else { return nil }
        let after = cmd[range.upperBound...]
        let tokenPart = after.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "=\"")))
        let token = tokenPart.prefix { char in
            char.isLetter || char.isNumber || char == "-"
        }
        return token.isEmpty ? nil : String(token)
    }

    private func findListeningPorts(pid: Int32) -> [UInt16] {
        guard let output = runProcess(executable: "/usr/sbin/lsof", arguments: ["-nP", "-p", "\(pid)", "-a", "-iTCP", "-sTCP:LISTEN"]) else {
            return []
        }

        var ports: [UInt16] = []
        for line in output.components(separatedBy: .newlines) {
            if let colonRange = line.range(of: ":", options: .backwards),
               let spaceRange = line.range(of: " (LISTEN)") {
                let portStr = line[colonRange.upperBound..<spaceRange.lowerBound]
                if let port = UInt16(portStr) {
                    ports.append(port)
                }
            }
        }

        ports.sort()
        // If adjacent ports (e.g. 50605 and 50606), the lower one is usually HTTPS
        if let lower = ports.first(where: { ports.contains($0 + 1) }) {
            return [lower] + ports.filter { $0 != lower }
        }
        return ports
    }

    private func findEndpointsFromDaemonFiles() -> [Endpoint] {
        var results: [Endpoint] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        let geminiDir = home.appendingPathComponent(".gemini")
        guard let subdirs = try? FileManager.default.contentsOfDirectory(at: geminiDir, includingPropertiesForKeys: nil) else {
            return []
        }

        for sub in subdirs {
            let daemonDir = sub.appendingPathComponent("daemon")
            guard let files = try? FileManager.default.contentsOfDirectory(at: daemonDir, includingPropertiesForKeys: nil) else {
                continue
            }
            for file in files where file.pathExtension == "json" {
                guard let data = try? Data(contentsOf: file),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                if let portNum = json["httpsPort"] as? Int,
                   let csrf = json["csrfToken"] as? String {
                    results.append(Endpoint(port: UInt16(portNum), csrf: csrf))
                }
            }
        }
        return results
    }

    private func findEndpointsFromLogs() -> [Endpoint] {
        var results: [Endpoint] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        let appSupport = home.appendingPathComponent("Library/Application Support")
        let logPaths = [
            appSupport.appendingPathComponent("Antigravity/logs/main.log"),
            appSupport.appendingPathComponent("Antigravity IDE/logs/main.log")
        ]

        for path in logPaths {
            guard let data = try? Data(contentsOf: path) else { continue }
            // Read tail (last 128 KB)
            let length = data.count
            let slice = length > 131072 ? data.subdata(in: (length - 131072)..<length) : data
            guard let text = String(data: slice, encoding: .utf8) else { continue }

            if let csrf = extractLastAfter(text: text, marker: "--csrf_token "),
               let portStr = extractLastAfter(text: text, marker: "127.0.0.1:"),
               let port = UInt16(portStr.prefix(while: { $0.isNumber })) {
                results.append(Endpoint(port: port, csrf: csrf))
            }
        }
        return results
    }

    private func extractLastAfter(text: String, marker: String) -> String? {
        guard let range = text.range(of: marker, options: .backwards) else { return nil }
        let after = text[range.upperBound...]
        let token = after.prefix { char in
            char.isLetter || char.isNumber || char == "-"
        }
        return token.isEmpty ? nil : String(token)
    }

    private func callGetUserStatus(endpoint: Endpoint) async throws -> Snapshot {
        guard let url = URL(string: "https://127.0.0.1:\(endpoint.port)/exa.language_server_pb.LanguageServerService/GetUserStatus") else {
            throw FetchError("Invalid URL")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(endpoint.csrf, forHTTPHeaderField: "X-Codeium-Csrf-Token")
        req.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        req.httpBody = Data(#"{"metadata":{"ideName":"antigravity"}}"#.utf8)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw FetchError("Неверный ответ сервера")
        }
        if http.statusCode != 200 {
            throw FetchError("Статус \(http.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userStatus = json["userStatus"] as? [String: Any] else {
            throw FetchError("Неверный формат ответа")
        }

        return parseUserStatus(userStatus)
    }

    private func parseUserStatus(_ status: [String: Any]) -> Snapshot {
        let now = Date()
        let windowSecs: TimeInterval = 5 * 3600 // 5 hours

        // Plan name
        var planName = "Antigravity"
        if let userTier = status["userTier"] as? [String: Any],
           let tierName = userTier["name"] as? String, !tierName.isEmpty {
            planName = "Antigravity · \(tierName)"
        } else if let planStatus = status["planStatus"] as? [String: Any],
                  let planInfo = planStatus["planInfo"] as? [String: Any],
                  let name = planInfo["planName"] as? String, !name.isEmpty {
            planName = "Antigravity · \(name)"
        }

        // Parse Cascade model quotas
        // Group 0: Gemini
        // Group 1: Claude / GPT
        var groupRemaining: [Double?] = [nil, nil]
        var groupReset: [Date?] = [nil, nil]

        if let cascadeData = status["cascadeModelConfigData"] as? [String: Any],
           let configs = cascadeData["clientModelConfigs"] as? [[String: Any]] {
            for cfg in configs {
                guard let label = cfg["label"] as? String,
                      let quotaInfo = cfg["quotaInfo"] as? [String: Any] else { continue }
                
                let remaining: Double = {
                    if let d = quotaInfo["remainingFraction"] as? Double { return d }
                    if let s = quotaInfo["remainingFraction"] as? String, let d = Double(s) { return d }
                    // In proto3 JSON, default float/double 0.0 is omitted.
                    // When quotaInfo is present, missing remainingFraction indicates 0.0 (exhausted / 100% used).
                    return 0.0
                }()

                let resetDate: Date? = {
                    if let s = quotaInfo["resetTime"] as? String {
                        let iso = ISO8601DateFormatter()
                        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        if let d = iso.date(from: s) { return d }
                        let iso2 = ISO8601DateFormatter()
                        return iso2.date(from: s)
                    }
                    if let num = quotaInfo["resetTime"] as? Double {
                        let secs = num > 100_000_000_000 ? num / 1000 : num
                        return Date(timeIntervalSince1970: secs)
                    }
                    return nil
                }()

                let groupIndex = label.lowercased().contains("gemini") ? 0 : 1
                let currentRem = groupRemaining[groupIndex] ?? 1.0
                groupRemaining[groupIndex] = min(currentRem, max(0.0, min(1.0, remaining)))

                if let r = resetDate {
                    if let curR = groupReset[groupIndex] {
                        if r < curR { groupReset[groupIndex] = r }
                    } else {
                        groupReset[groupIndex] = r
                    }
                }
            }
        }

        let groupTitles = ["Gemini", "Claude / GPT"]
        var limits: [Limit] = []

        for i in 0..<2 {
            guard let remaining = groupRemaining[i] else { continue }
            let usedPercent = (1.0 - remaining) * 100.0
            let resetsAt = groupReset[i] ?? now.addingTimeInterval(windowSecs)
            let window = LimitWindow(resetsAt: resetsAt, lengthSeconds: windowSecs, now: now)

            limits.append(Limit(
                title: groupTitles[i],
                usedPercent: usedPercent,
                window: window
            ))
        }

        return Snapshot(family: .antigravity, plan: planName, limits: limits)
    }
}
