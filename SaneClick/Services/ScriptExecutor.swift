import Foundation
import os.log
@preconcurrency import UserNotifications

private let executorLogger = Logger(subsystem: "com.saneclick.SaneClick", category: "ScriptExecutor")

/// Result of script execution for UI feedback
struct ScriptExecutionResult: Sendable {
    let scriptName: String
    let success: Bool
    let output: String
    let error: String?
    let timestamp: Date

    static func success(scriptName: String, output: String) -> ScriptExecutionResult {
        ScriptExecutionResult(scriptName: scriptName, success: true, output: output, error: nil, timestamp: Date())
    }

    static func failure(scriptName: String, error: String) -> ScriptExecutionResult {
        ScriptExecutionResult(scriptName: scriptName, success: false, output: "", error: error, timestamp: Date())
    }
}

/// Execution request passed via file from extension to host app
/// (DistributedNotificationCenter strips userInfo between processes)
struct ExecutionRequest: Codable {
    let scriptId: UUID
    let paths: [String]
    let timestamp: Date
    let requestId: UUID  // Unique ID to prevent duplicate processing

    init(scriptId: UUID, paths: [String], timestamp: Date = Date(), requestId: UUID = UUID()) {
        self.scriptId = scriptId
        self.paths = paths
        self.timestamp = timestamp
        self.requestId = requestId
    }
}

/// Executes scripts with selected file paths
final class ScriptExecutor: @unchecked Sendable {
    static let shared = ScriptExecutor()

    /// Published execution results for UI to observe
    @MainActor static var lastResult: ScriptExecutionResult?

    /// Notification posted when execution completes
    static let executionCompletedNotification = Notification.Name("com.saneclick.executionCompleted")

    /// File-based IPC: extension writes here, host app reads
    private static var pendingExecutionURL: URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "M78L6FXD48.group.com.saneclick.app"
        ) else {
            return nil
        }
        return containerURL.appendingPathComponent("pending_execution.json")
    }

    /// Lock file for cross-process synchronization
    private static var lockFileURL: URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "M78L6FXD48.group.com.saneclick.app"
        ) else {
            return nil
        }
        return containerURL.appendingPathComponent(".execution.lock")
    }

    private var fileWatchSource: DispatchSourceFileSystemObject?
    private var fileWatchFd: Int32 = -1  // Track fd for cleanup
    private let queue = DispatchQueue(label: "com.saneclick.executor", qos: .userInitiated)

    /// Track recently processed request IDs to prevent duplicates
    private var processedRequestIds = Set<UUID>()
    private let processedIdsLock = NSLock()

    /// Maximum age for processed request IDs (10 seconds)
    private let maxProcessedIdAge: TimeInterval = 10

    private init() {
        NSLog("[ScriptExecutor] Initializing with file-based IPC")
        executorLogger.info("Initializing ScriptExecutor")

        // Listen for execution signal from extension (notification is just a trigger)
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.saneclick.executeScript"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            NSLog("[ScriptExecutor] Received executeScript signal, checking for pending request file...")
            self?.processPendingExecution()
        }

        // Also check on startup for any pending requests, and set up file watcher
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.processPendingExecution()
            self?.setupFileWatcher()
        }
    }

    /// Set up a file system watcher for the pending execution file
    private func setupFileWatcher() {
        // Cancel any existing watcher first to prevent fd leak
        if let existingSource = fileWatchSource {
            existingSource.cancel()
            fileWatchSource = nil
        }

        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "M78L6FXD48.group.com.saneclick.app"
        ) else {
            NSLog("[ScriptExecutor] Cannot set up file watcher: no App Group container")
            return
        }

        let containerPath = containerURL.path
        let fd = open(containerPath, O_EVTONLY)
        guard fd >= 0 else {
            NSLog("[ScriptExecutor] Cannot open container directory for watching")
            return
        }

        // Track fd for cleanup
        fileWatchFd = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: queue  // Use serial queue to prevent concurrent processing
        )

        source.setEventHandler { [weak self] in
            NSLog("[ScriptExecutor] File system change detected in container")
            self?.processPendingExecutionLocked()  // Already on queue, call directly
        }

        source.setCancelHandler { [weak self] in
            if let watchFd = self?.fileWatchFd, watchFd >= 0 {
                close(watchFd)
                self?.fileWatchFd = -1
            }
        }

        source.resume()
        fileWatchSource = source
        NSLog("[ScriptExecutor] File watcher set up for: \(containerPath)")
    }

    deinit {
        // Clean up file watcher
        fileWatchSource?.cancel()
        fileWatchSource = nil
    }

    /// Process pending execution request from file with proper locking
    private func processPendingExecution() {
        // Process on serial queue to prevent concurrent access from multiple triggers
        queue.async { [weak self] in
            self?.processPendingExecutionLocked()
        }
    }

    /// Actual processing with file locking - must be called on queue
    private func processPendingExecutionLocked() {
        guard let pendingURL = Self.pendingExecutionURL,
              let lockURL = Self.lockFileURL else {
            NSLog("[ScriptExecutor] No pending execution URL (App Group not available)")
            return
        }

        // Create lock file if needed
        if !FileManager.default.fileExists(atPath: lockURL.path) {
            FileManager.default.createFile(atPath: lockURL.path, contents: nil)
        }

        // Open lock file for exclusive locking
        let lockFd = open(lockURL.path, O_RDWR | O_CREAT, 0o644)
        guard lockFd >= 0 else {
            NSLog("[ScriptExecutor] Failed to open lock file")
            return
        }
        defer { close(lockFd) }

        // Try to acquire exclusive lock (non-blocking)
        guard flock(lockFd, LOCK_EX | LOCK_NB) == 0 else {
            // Another process holds the lock, skip this attempt
            return
        }
        defer { flock(lockFd, LOCK_UN) }

        // Now we hold the exclusive lock - safe to read and delete
        guard FileManager.default.fileExists(atPath: pendingURL.path) else {
            return // No pending request
        }

        NSLog("[ScriptExecutor] Found pending execution file at: \(pendingURL.path)")

        do {
            let data = try Data(contentsOf: pendingURL)

            // Delete the file immediately while holding lock
            try? FileManager.default.removeItem(at: pendingURL)

            // Decode request - handle missing requestId for backward compatibility
            let request: ExecutionRequest
            if let decoded = try? JSONDecoder().decode(ExecutionRequest.self, from: data) {
                request = decoded
            } else {
                // Legacy format without requestId - decode manually
                struct LegacyRequest: Codable {
                    let scriptId: UUID
                    let paths: [String]
                    let timestamp: Date
                }
                let legacy = try JSONDecoder().decode(LegacyRequest.self, from: data)
                request = ExecutionRequest(scriptId: legacy.scriptId, paths: legacy.paths, timestamp: legacy.timestamp)
            }

            // Check for duplicate request
            processedIdsLock.lock()
            let alreadyProcessed = processedRequestIds.contains(request.requestId)
            if !alreadyProcessed {
                processedRequestIds.insert(request.requestId)
            }
            processedIdsLock.unlock()

            if alreadyProcessed {
                NSLog("[ScriptExecutor] Ignoring duplicate request: \(request.requestId)")
                return
            }

            // Ignore stale requests (older than 10 seconds)
            if Date().timeIntervalSince(request.timestamp) > maxProcessedIdAge {
                NSLog("[ScriptExecutor] Ignoring stale request from \(request.timestamp)")
                return
            }

            NSLog("[ScriptExecutor] Processing request: scriptId=\(request.scriptId), requestId=\(request.requestId), paths=\(request.paths)")

            // Find and execute the script on main thread
            DispatchQueue.main.async {
                if let script = ScriptStore.shared.scripts.first(where: { $0.id == request.scriptId }) {
                    NSLog("[ScriptExecutor] Found script: \(script.name), executing...")
                    Task {
                        await self.execute(script: script, withPaths: request.paths)
                    }
                } else {
                    NSLog("[ScriptExecutor] Script not found for id: \(request.scriptId)")
                }
            }

            // Clean up old processed IDs periodically
            self.cleanupOldProcessedIds()
        } catch {
            NSLog("[ScriptExecutor] Failed to process pending execution: \(error)")
        }
    }

    /// Remove processed request IDs older than maxProcessedIdAge
    private func cleanupOldProcessedIds() {
        // Simple cleanup: if we have too many IDs, clear them all
        // (A more sophisticated approach would track timestamps per ID)
        processedIdsLock.lock()
        if processedRequestIds.count > 100 {
            processedRequestIds.removeAll()
        }
        processedIdsLock.unlock()
    }

    /// Execute a script with the given file paths
    func execute(script: Script, withPaths paths: [String]) async {
        let result: Result<String, ScriptError>

        switch script.type {
        case .bash:
            result = await executeBash(content: script.content, paths: paths)
        case .applescript:
            result = await executeAppleScript(content: script.content, paths: paths)
        case .automator:
            result = await executeAutomator(workflowPath: script.content, paths: paths)
        }

        // Create execution result for UI
        let executionResult: ScriptExecutionResult
        switch result {
        case .success(let output):
            executionResult = .success(scriptName: script.name, output: output)
        case .failure(let error):
            executionResult = .failure(scriptName: script.name, error: error.localizedDescription)
        }

        // Update on main thread and post notification
        await MainActor.run {
            ScriptExecutor.lastResult = executionResult
            NotificationCenter.default.post(
                name: ScriptExecutor.executionCompletedNotification,
                object: nil,
                userInfo: ["result": executionResult]
            )
        }

        maybeNotifyUser(for: executionResult, script: script)
    }

    // MARK: - User Notifications

    private func maybeNotifyUser(for result: ScriptExecutionResult, script: Script) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "showActionNotifications") == nil {
            defaults.set(true, forKey: "showActionNotifications")
        }

        guard defaults.bool(forKey: "showActionNotifications") else { return }
        guard shouldNotify(for: script) else { return }

        let content = UNMutableNotificationContent()
        content.title = "SaneClick"
        if result.success {
            content.body = "\(script.name) completed"
        } else if let error = result.error {
            content.body = "\(script.name) failed: \(error)"
        } else {
            content.body = "\(script.name) failed"
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted {
                        center.add(request)
                    }
                }
            case .authorized, .provisional:
                center.add(request)
            default:
                break
            }
        }
    }

    private func shouldNotify(for script: Script) -> Bool {
        let lowerContent = script.content.lowercased()
        if lowerContent.contains("display notification") || lowerContent.contains("osascript -e") {
            return false
        }
        return true
    }

    // MARK: - Execution Methods

    private func executeBash(content: String, paths: [String]) async -> Result<String, ScriptError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        // Note: with bash -c, first arg after script becomes $0, so we add "bash" as placeholder
        process.arguments = ["-c", content, "bash"] + paths

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return .success(output)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return .failure(.executionFailed(errorOutput))
            }
        } catch {
            return .failure(.launchFailed(error.localizedDescription))
        }
    }

    private func executeAppleScript(content: String, paths: [String]) async -> Result<String, ScriptError> {
        // Build the AppleScript with paths as arguments
        let fullScript = """
        on run argv
            \(content)
        end run
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", fullScript] + paths

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return .success(output)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return .failure(.executionFailed(errorOutput))
            }
        } catch {
            return .failure(.launchFailed(error.localizedDescription))
        }
    }

    private func executeAutomator(workflowPath: String, paths: [String]) async -> Result<String, ScriptError> {
        guard FileManager.default.fileExists(atPath: workflowPath) else {
            return .failure(.workflowNotFound(workflowPath))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/automator")
        process.arguments = [workflowPath]

        // Pass paths via stdin
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        let pathsString = paths.joined(separator: "\n")
        inputPipe.fileHandleForWriting.write(pathsString.data(using: .utf8) ?? Data())
        inputPipe.fileHandleForWriting.closeFile()

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            return .success(output)
        } catch {
            return .failure(.launchFailed(error.localizedDescription))
        }
    }
}

// MARK: - Errors

enum ScriptError: Error, LocalizedError {
    case launchFailed(String)
    case executionFailed(String)
    case workflowNotFound(String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let reason):
            return "Failed to launch script: \(reason)"
        case .executionFailed(let reason):
            return "Script execution failed: \(reason)"
        case .workflowNotFound(let path):
            return "Automator workflow not found: \(path)"
        }
    }
}
