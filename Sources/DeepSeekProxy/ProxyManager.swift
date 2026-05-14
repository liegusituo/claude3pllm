import Foundation
import Combine
import OSLog
import Darwin

/// Manages the Python deepseek_proxy.py process lifecycle.
@MainActor
final class ProxyManager: ObservableObject {
    @Published var status: ProxyStatus = .stopped
    @Published var logs: [LogEntry] = []
    @Published var settings = AppSettings()

    init() {
        loadSettings()
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        settings.apiKey = defaults.string(forKey: "api_key") ?? ""
        settings.codexApiKey = defaults.string(forKey: "codex_api_key") ?? ""
        settings.claudeApiKey = defaults.string(forKey: "claude_api_key") ?? ""
        settings.port = defaults.integer(forKey: "proxy_port")
        if settings.port == 0 { settings.port = 9797 }
        settings.autoStart = defaults.bool(forKey: "auto_start")
        settings.launchAtLogin = defaults.bool(forKey: "launch_at_login")
        if defaults.object(forKey: "logging_enabled") != nil {
            settings.loggingEnabled = defaults.bool(forKey: "logging_enabled")
        }
        settings.locale = defaults.string(forKey: "locale") ?? "zh"
    }

    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private let logger = Logger(subsystem: "com.deepseek.proxy", category: "ProxyManager")
    private let maxLogEntries = 500
    private var healthCheckTask: Task<Void, Never>?

    private var proxyScriptPath: String? {
        var searched: [String] = []

        // 0. Check Bundle.resourceURL first (for development and app bundles)
        if let resourceURL = Bundle.main.resourceURL {
            let path = resourceURL.appendingPathComponent("deepseek_proxy.py").path
            if FileManager.default.fileExists(atPath: path) {
                logger.debug("Found script at Bundle.resourceURL: \(path)")
                return path
            }
            searched.append(path)
        }

        // 1. Same directory as binary
        if let exeURL = Bundle.main.executableURL {
            let dir = exeURL.deletingLastPathComponent()
            let path = dir.appendingPathComponent("deepseek_proxy.py").path
            if FileManager.default.fileExists(atPath: path) {
                logger.debug("Found script at binary directory: \(path)")
                return path
            }
            searched.append(path)
        }

        // 2. Resources folder next to binary
        if let exeURL = Bundle.main.executableURL {
            let dir = exeURL.deletingLastPathComponent()
            let resourcesPath = dir.appendingPathComponent("Resources/deepseek_proxy.py").path
            if FileManager.default.fileExists(atPath: resourcesPath) {
                logger.debug("Found script at binary/Resources: \(resourcesPath)")
                return resourcesPath
            }
            searched.append(resourcesPath)
        }

        // 3. Project root (binary is .build/arm64-apple-macosx/release/DeepSeekProxy)
        if let exeURL = Bundle.main.executableURL {
            let projectRoot = exeURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let resourcesPath = projectRoot.appendingPathComponent("Resources/deepseek_proxy.py").path
            if FileManager.default.fileExists(atPath: resourcesPath) {
                logger.debug("Found script at project root: \(resourcesPath)")
                return resourcesPath
            }
            searched.append(resourcesPath)
        }

        // 3a. Also try current working directory's Resources folder (for development when running from Xcode/SwiftPM)
        let cwdResourcesPath = FileManager.default.currentDirectoryPath + "/Resources/deepseek_proxy.py"
        if FileManager.default.fileExists(atPath: cwdResourcesPath) {
            logger.debug("Found script at CWD/Resources: \(cwdResourcesPath)")
            return cwdResourcesPath
        }
        searched.append(cwdResourcesPath)

        // 4. Current working directory
        let cwd = FileManager.default.currentDirectoryPath + "/deepseek_proxy.py"
        if FileManager.default.fileExists(atPath: cwd) {
            logger.debug("Found script at CWD: \(cwd)")
            return cwd
        }
        searched.append(cwd)

        // 5. ~/DeepSeekProxy/Resources/
        let homeResources = NSHomeDirectory() + "/DeepSeekProxy/Resources/deepseek_proxy.py"
        if FileManager.default.fileExists(atPath: homeResources) {
            logger.debug("Found script at ~/DeepSeekProxy/Resources: \(homeResources)")
            return homeResources
        }
        searched.append(homeResources)

        // 6. ~/VscodeWorkSpaces/DeepSeekProxy/Resources/
        let vscodeResources = NSHomeDirectory() + "/VscodeWorkSpaces/DeepSeekProxy/Resources/deepseek_proxy.py"
        if FileManager.default.fileExists(atPath: vscodeResources) {
            logger.debug("Found script at ~/VscodeWorkSpaces: \(vscodeResources)")
            return vscodeResources
        }
        searched.append(vscodeResources)

        logger.error("proxyScriptPath not found. Searched: \(searched.joined(separator: ", "))")
        return nil
    }

    // MARK: - Start / Stop

    func startProxy() {
        switch status {
        case .stopped, .starting:
            break
        case .running:
            return
        case .error:
            break
        }

        // Check if port is available
        if !isPortAvailable(settings.port) {
            status = .error("Port \(settings.port) is already in use")
            addLog(.error, "Port \(settings.port) is already in use. Please choose a different port in Settings.")
            return
        }

        guard let scriptPath = proxyScriptPath else {
            status = .error("Cannot find deepseek_proxy.py")
            addLog(.error, "Cannot find deepseek_proxy.py. Place it next to the app or in Resources.")
            return
        }

        guard settings.hasAnyKey else {
            status = .error("No API key configured")
            addLog(.error, "Please set at least one API key in Settings.")
            return
        }

        status = .starting
        addLog(.info, "Starting DeepSeek Proxy...")
        addLog(.debug, "Using script: \(scriptPath)")

        // Verify python3 exists
        let pythonPath = "/usr/bin/python3"
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            status = .error("Python3 not found")
            addLog(.error, "Python3 not found at \(pythonPath). Please install Python 3.")
            return
        }
        addLog(.debug, "Python3 found at \(pythonPath)")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = [scriptPath]
        proc.currentDirectoryURL = URL(fileURLWithPath: scriptPath).deletingLastPathComponent()

        // Environment
        var env = ProcessInfo.processInfo.environment
        if !settings.apiKey.isEmpty {
            env["DEEPSEEK_API_KEY"] = settings.apiKey
        }
        if !settings.codexApiKey.isEmpty {
            env["CODEX_DEEPSEEK_API_KEY"] = settings.codexApiKey
        }
        if !settings.claudeApiKey.isEmpty {
            env["CLAUDE_DEEPSEEK_API_KEY"] = settings.claudeApiKey
        }
        proc.environment = env

        // Capture stdout
        let outPipe = Pipe()
        proc.standardOutput = outPipe
        outputPipe = outPipe

        // Capture stderr
        let errPipe = Pipe()
        proc.standardError = errPipe
        errorPipe = errPipe

        // Read output asynchronously - use nonisolated to avoid capture issues
        setupOutputHandling(outPipe: outPipe, errPipe: errPipe, proc: proc)

        do {
            try proc.run()
            process = proc
            // Give the proxy a moment to start, then verify with health check
            startHealthCheck(delay: 2.0)
        } catch {
            status = .error(error.localizedDescription)
            addLog(.error, "Failed to launch proxy: \(error.localizedDescription)")
        }
    }

    private nonisolated func setupOutputHandling(outPipe: Pipe, errPipe: Pipe, proc: Process) {
        weak var weakSelf = self

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let str = String(data: data, encoding: .utf8) {
                let lines = str.components(separatedBy: "\n").filter { !$0.isEmpty }
                Task { @MainActor [weakSelf] in
                    guard let self = weakSelf else { return }
                    for line in lines {
                        self.addLog(self.logLevelFor(line), line)
                    }
                }
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let str = String(data: data, encoding: .utf8) {
                let lines = str.components(separatedBy: "\n").filter { !$0.isEmpty }
                Task { @MainActor [weakSelf] in
                    guard let self = weakSelf else { return }
                    for line in lines {
                        self.addLog(.error, line)
                    }
                }
            }
        }

        proc.terminationHandler = { [weakSelf] proc in
            Task { @MainActor [weakSelf] in
                guard let self = weakSelf else { return }
                let code = proc.terminationStatus
                if code == 0 {
                    self.addLog(.info, "Proxy process exited normally.")
                } else {
                    self.addLog(.error, "Proxy process exited with code \(code).")
                }
                if case .running = self.status {
                    self.status = .stopped
                }
                self.process = nil
            }
        }
    }

    func stopProxy() {
        guard let proc = process else {
            status = .stopped
            process = nil
            return
        }

        addLog(.info, "Stopping DeepSeek Proxy...")
        healthCheckTask?.cancel()

        // Clear the pipe handlers to prevent retaining references
        if let outPipe = outputPipe {
            outPipe.fileHandleForReading.readabilityHandler = nil
            outputPipe = nil
        }
        if let errPipe = errorPipe {
            errPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe = nil
        }

        // First try to terminate gracefully
        if proc.isRunning {
            proc.terminate()
        }

        // Wait a moment and check
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            if proc.isRunning {
                // If still running, force interrupt
                proc.interrupt()
            }
        }

        // Wait a bit more and force kill if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if proc.isRunning {
                // Last resort: force kill the process and its children
                self?.addLog(.warn, "Force killing proxy process...")
                kill(proc.processIdentifier, SIGKILL)
            }

            // Always clean up state
            self?.status = .stopped
            self?.process = nil
            self?.addLog(.info, "DeepSeek Proxy stopped.")
        }
    }

    // MARK: - Health Check

    private func startHealthCheck(delay: TimeInterval, retryCount: Int = 5) {
        healthCheckTask?.cancel()
        healthCheckTask = Task {
            var currentRetry = 0

            while currentRetry < retryCount && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }

                let url = URL(string: "http://127.0.0.1:\(settings.port)/health")!
                var request = URLRequest(url: url)
                request.timeoutInterval = 2

                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            let statusText = json["status"] as? String ?? "running"
                            if statusText == "running" {
                                self.status = .running(port: settings.port)
                                self.addLog(.info, "DeepSeek Proxy is running on port \(settings.port)")
                                // Continue periodic health checks
                                self.scheduleNextHealthCheck()
                                return
                            }
                        }
                    } else {
                        addLog(.warn, "Health check attempt \(currentRetry + 1)/\(retryCount): non-200 status")
                    }
                } catch {
                    if !Task.isCancelled {
                        addLog(.warn, "Health check attempt \(currentRetry + 1)/\(retryCount): \(error.localizedDescription)")
                    }
                }

                currentRetry += 1
                // If not the last retry, wait a bit before trying again
                if currentRetry < retryCount {
                    try? await Task.sleep(nanoseconds: UInt64(1.5 * 1_000_000_000))
                }
            }

            // All retries failed
            if !Task.isCancelled {
                self.status = .error("Cannot reach proxy on port \(settings.port)")
                self.addLog(.error, "Health check failed after \(retryCount) attempts. Check logs for details.")
            }
        }
    }

    private func scheduleNextHealthCheck() {
        healthCheckTask = Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
            guard !Task.isCancelled, case .running = status else { return }
            startHealthCheck(delay: 0)
        }
    }

    // MARK: - Port Check

    private func isPortAvailable(_ port: Int) -> Bool {
        let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFileDescriptor != -1 else {
            return true
        }
        defer { close(socketFileDescriptor) }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafeMutablePointer(to: &addr) { ptr in
            bind(socketFileDescriptor, UnsafeRawPointer(ptr).assumingMemoryBound(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_in>.size))
        }

        return bindResult == 0
    }

    // MARK: - Logging

    private func addLog(_ level: LogEntry.LogLevel, _ message: String) {
        guard settings.loggingEnabled else { return }

        logs.append(LogEntry(timestamp: Date(), message: message, level: level))
        if logs.count > maxLogEntries {
            logs.removeFirst(logs.count - maxLogEntries)
        }
        logger.log("\(message, privacy: .public)")
    }

    private func logLevelFor(_ line: String) -> LogEntry.LogLevel {
        if line.contains("错误") || line.contains("ERROR") || line.contains("error") {
            return .error
        }
        if line.contains("警告") || line.contains("WARN") || line.contains("⚠️") {
            return .warn
        }
        if line.contains("DEBUG") || line.contains("debug") {
            return .debug
        }
        return .info
    }

    // MARK: - Lifecycle

    func setup(settings: AppSettings) {
        self.settings = settings
    }

    func onAppTerminate() {
        stopProxy()
    }
}
