import AppKit
import Foundation

@MainActor
public final class ActiveAppDetector {
    public var onFamilyDetected: ((Family) -> Void)?
    public var onAiStateChanged: ((_ isAiActive: Bool, _ family: Family?) -> Void)?

    private var timer: Timer?
    private var lastPid: pid_t = 0
    private var lastFamily: Family?
    private var isHostActive: Bool = false
    private var isAiActive: Bool = false
    private var hasInitialized: Bool = false

    public init() {
        setupWorkspaceObserver()
        startPeriodicCheck()
    }

    deinit {
        timer?.invalidate()
    }

    private func setupWorkspaceObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor [weak self] in
                self?.checkForegroundApp(targetApp: app)
            }
        }
    }

    private func startPeriodicCheck() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.checkForegroundApp(forceTree: self.isHostActive)
            }
        }
    }

    public func pollNow() {
        checkForegroundApp(forceTree: true)
    }

    private func checkForegroundApp(targetApp: NSRunningApplication? = nil, forceTree: Bool = false) {
        guard let app = targetApp ?? NSWorkspace.shared.frontmostApplication else { return }
        let pid = app.processIdentifier

        // Don't treat Quotty itself as deactivating the AI state (e.g. clicking settings window or menu bar)
        if pid == ProcessInfo.processInfo.processIdentifier {
            return
        }

        let bundleId = (app.bundleIdentifier ?? "").lowercased()
        let appName = (app.localizedName ?? "").lowercased()

        if pid == lastPid && !forceTree && !isHostActive {
            return
        }

        // Direct tool matches
        if let direct = directMatch(bundleId: bundleId, appName: appName) {
            isHostActive = false
            updateAiState(isAi: true, family: direct, pid: pid)
            return
        }

        // Host matches (Terminals, IDEs)
        if isHost(bundleId: bundleId, appName: appName) {
            isHostActive = true
            if let cliFamily = findCliInProcessTree(rootPid: pid) {
                updateAiState(isAi: true, family: cliFamily, pid: pid)
            } else {
                updateAiState(isAi: false, family: nil, pid: pid)
            }
            return
        }

        isHostActive = false
        updateAiState(isAi: false, family: nil, pid: pid)
    }

    private func updateAiState(isAi: Bool, family: Family?, pid: pid_t) {
        lastPid = pid

        let aiChanged = (isAi != isAiActive)
        let familyChanged = (family != nil && lastFamily != family)
        let shouldNotify = !hasInitialized || aiChanged || (isAi && familyChanged)

        hasInitialized = true
        isAiActive = isAi

        if let family = family {
            lastFamily = family
        }

        if familyChanged, let family = family {
            onFamilyDetected?(family)
        }

        if shouldNotify {
            onAiStateChanged?(isAi, family ?? lastFamily)
        }
    }

    private func directMatch(bundleId: String, appName: String) -> Family? {
        if bundleId.contains("antigravity") || appName.contains("antigravity") {
            return .antigravity
        }
        if bundleId.contains("claude") || appName.contains("claude") {
            return .claude
        }
        if bundleId.contains("codex") || appName.contains("codex") || bundleId.contains("chatgpt") || appName.contains("chatgpt") {
            return .codex
        }
        return nil
    }

    private func isHost(bundleId: String, appName: String) -> Bool {
        let hosts = [
            "terminal", "iterm", "alacritty", "kitty", "warp", "ghostty",
            "hyper", "tabby", "wezterm", "code", "cursor", "windsurf", "sublime"
        ]
        return hosts.contains { bundleId.contains($0) || appName.contains($0) }
    }

    private func findCliInProcessTree(rootPid: pid_t) -> Family? {
        // Run ps -eo pid,ppid,command to check child processes of the terminal
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-eo", "pid,ppid,command"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            guard let output = String(data: data, encoding: .utf8) else { return nil }

            struct ProcEntry {
                let pid: pid_t
                let ppid: pid_t
                let command: String
            }

            var entries: [ProcEntry] = []
            for line in output.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                guard parts.count >= 3,
                      let pid = Int32(parts[0]),
                      let ppid = Int32(parts[1]) else { continue }
                entries.append(ProcEntry(pid: pid, ppid: ppid, command: String(parts[2]).lowercased()))
            }

            // Find all descendants of rootPid
            var descendants: Set<pid_t> = []
            var queue: [pid_t] = [rootPid]

            while !queue.isEmpty {
                let current = queue.removeFirst()
                for entry in entries where entry.ppid == current {
                    if !descendants.contains(entry.pid) {
                        descendants.insert(entry.pid)
                        queue.append(entry.pid)
                    }
                }
            }

            // Check if any descendant is agy, claude, or codex CLI
            var bestFamily: Family?
            var highestPid: pid_t = 0

            for entry in entries where descendants.contains(entry.pid) {
                let cmd = entry.command
                let exeName = (cmd.components(separatedBy: " ").first ?? cmd).components(separatedBy: "/").last ?? cmd

                var matched: Family?
                if exeName == "agy" || cmd.contains("/agy") {
                    matched = .antigravity
                } else if exeName == "claude" || cmd.contains("/claude") {
                    matched = .claude
                } else if exeName == "codex" || cmd.contains("/codex") {
                    matched = .codex
                }

                if let f = matched, entry.pid > highestPid {
                    highestPid = entry.pid
                    bestFamily = f
                }
            }

            return bestFamily
        } catch {
            return nil
        }
    }
}
