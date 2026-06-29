import AppKit
import Foundation
import os.log
import SaneUI
@preconcurrency import UserNotifications

private let executorLogger = Logger(subsystem: "com.saneclick.SaneClick", category: "ScriptExecutor")

/// Result of script execution for UI feedback
struct ScriptExecutionResult {
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
    let requestId: UUID // Unique ID to prevent duplicate processing

    init(scriptId: UUID, paths: [String], timestamp: Date = Date(), requestId: UUID = UUID()) {
        self.scriptId = scriptId
        self.paths = paths
        self.timestamp = timestamp
        self.requestId = requestId
    }
}

/// Where an action's output should be surfaced once it finishes.
/// This is the single, pure decision computed from a script's `outputMode`
/// (and, for `.standard`, the existing self-notification suppression), so the
/// surfacing logic stays unit-testable away from the side effects.
enum OutputSink: Equatable {
    case none // Surface nothing.
    case standardNotification // Today's "<name> completed/failed" notification path.
    case clipboard(String) // Copy this text to the clipboard.
    case notification(String) // Post a notification whose body is this text.
    case window(String) // Show this text in a result window.
}

/// Executes scripts with selected file paths
final class ScriptExecutor: @unchecked Sendable {
    static let shared = ScriptExecutor()

    /// Published execution results for UI to observe
    @MainActor static var lastResult: ScriptExecutionResult?

    /// Notification posted when execution completes
    static let executionCompletedNotification = Notification.Name("com.saneclick.executionCompleted")

    /// Notification posted when an action with `.showResult` finishes, so the host
    /// app can present a result window. `userInfo["result"]` carries the
    /// `ScriptExecutionResult`.
    static let showResultNotification = Notification.Name("com.saneclick.showResult")

    /// Output longer than this is trimmed before it goes into a notification body.
    static let notificationOutputLimit = 240

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
    }

    func processPendingExecutionAfterLaunchRequest() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.processPendingExecution()
        }
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
              let lockURL = Self.lockFileURL
        else {
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
                    guard self.canExecute(script: script) else {
                        NSLog("[ScriptExecutor] Blocked Pro-only script without Pro access: \(script.name)")
                        Task { @MainActor in
                            Self.lastResult = .failure(scriptName: script.name, error: "This action requires SaneClick Pro.")
                            NotificationCenter.default.post(name: Self.executionCompletedNotification, object: nil)
                        }
                        return
                    }

                    // Ask before running, if this action opts in. The decision
                    // (`shouldConfirm`) is pure and unit-tested; only the alert
                    // presentation here is non-headless. Cancel aborts the run.
                    if Self.shouldConfirm(script), !self.confirmRun(of: script, itemCount: request.paths.count) {
                        NSLog("[ScriptExecutor] User cancelled confirmed action: \(script.name)")
                        return
                    }

                    NSLog("[ScriptExecutor] Found script: \(script.name), executing...")
                    Task {
                        await self.execute(script: script, withPaths: request.paths)
                    }
                } else {
                    NSLog("[ScriptExecutor] Script not found for id: \(request.scriptId)")
                }
            }

            // Clean up old processed IDs periodically
            cleanupOldProcessedIds()
        } catch {
            NSLog("[ScriptExecutor] Failed to process pending execution: \(error)")
        }
    }

    @MainActor
    private func canExecute(script: Script) -> Bool {
        guard !currentLicenseService().isPro else { return true }
        return ActionCatalog.isAvailableInBasic(script)
    }

    @MainActor
    private func currentLicenseService() -> LicenseService {
        let service: LicenseService
        #if APP_STORE
            service = LicenseService(
                appName: "SaneClick",
                purchaseBackend: .appStore(productID: "com.saneclick.app.pro.actions.v4"),
                keychain: KeychainService(service: "com.saneclick.SaneClick")
            )
        #else
            service = LicenseService(
                appName: "SaneClick",
                checkoutURL: LicenseService.directCheckoutURL(appSlug: "saneclick"),
                keychain: KeychainService(service: "com.saneclick.SaneClick"),
                directCopy: LicenseService.DirectCopy.saneClick,
                proTrial: .init(storageKeyPrefix: "saneclick.pro_trial")
            )
        #endif
        service.checkCachedLicense()
        return service
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
        #if APP_STORE
            result = executeAppStoreAction(script: script, paths: paths)
        #else
            if let nativeAction = AppStoreNativeAction(script: script), nativeAction.requiresNativeRuntime {
                result = executeNativeAction(nativeAction, paths: paths)
            } else {
                result = switch script.type {
                case .bash:
                    await executeBash(content: script.content, paths: paths)
                case .applescript:
                    await executeAppleScript(content: script.content, paths: paths)
                case .automator:
                    await executeAutomator(workflowPath: script.content, paths: paths)
                }
            }
        #endif

        // Create execution result for UI
        let executionResult: ScriptExecutionResult = switch result {
        case let .success(output):
            .success(scriptName: script.name, output: output)
        case let .failure(error):
            .failure(scriptName: script.name, error: error.localizedDescription)
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

        // Surface the output according to the action's chosen output mode. The
        // decision (which sink) is pure and unit-tested; only acting on it here
        // touches AppKit/notifications. Acting on a non-standard sink replaces
        // the standard completion notification so we never double-notify.
        await surface(sink: Self.outputSink(for: script, result: executionResult), result: executionResult, script: script)

        if executionResult.success {
            logFirstValueActionIfNeeded()
        }
    }

    // MARK: - Output Surfacing

    /// Pure decision: where this action's output should go once it finishes.
    /// `.standard` keeps the existing behavior, including the self-notification
    /// suppression (scripts that already raise their own notification stay silent).
    /// Any explicitly chosen mode overrides that suppression and surfaces the
    /// result the way the user asked.
    static func outputSink(for script: Script, result: ScriptExecutionResult) -> OutputSink {
        switch script.outputMode {
        case .standard:
            // Keep today's behavior: scripts that raise their own notification
            // (display notification / osascript -e) stay silent so we don't
            // double up. Any explicit mode below overrides this suppression.
            scriptSelfNotifies(script) ? .none : .standardNotification
        case .copyResult:
            // On failure, don't wipe the clipboard with "" and claim success;
            // surface the real error via the standard notification path.
            result.success ? .clipboard(result.output) : .standardNotification
        case .notifyResult:
            // On failure, surface the real error instead of "Finished (no output)".
            result.success ? .notification(result.output) : .standardNotification
        case .showResult:
            .window(result.output)
        }
    }

    // MARK: - Run Confirmation

    /// Pure decision: should the user be asked to confirm before this action runs?
    /// Kept as a function (not just a property read) so it stays a unit-testable
    /// seam and a future policy can extend it without touching call sites.
    static func shouldConfirm(_ script: Script) -> Bool {
        script.confirmBeforeRun
    }

    /// Presents the confirmation alert and returns whether the user chose to run.
    /// This is intentionally the only non-headless part of the confirmation flow;
    /// the decision of *whether* to confirm lives in `shouldConfirm`.
    @MainActor
    private func confirmRun(of script: Script, itemCount: Int) -> Bool {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        let itemWord = itemCount == 1 ? "item" : "items"
        alert.messageText = "Run \"\(script.name)\" on \(itemCount) \(itemWord)?"
        alert.informativeText = "This action is set to ask before running."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Run")
        alert.addButton(withTitle: "Cancel")

        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Acts on a previously decided `OutputSink`. Kept off the pure decision path
    /// so the decision stays testable.
    private func surface(sink: OutputSink, result: ScriptExecutionResult, script: Script) async {
        switch sink {
        case .none:
            break
        case .standardNotification:
            maybeNotifyUser(for: result, script: script)
        case let .clipboard(text):
            await MainActor.run {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            }
            // Confirm the copy itself, since clipboard writes are otherwise silent.
            postResultNotification(title: script.name, body: "Result copied to clipboard")
        case let .notification(text):
            let body = Self.truncatedForNotification(text)
            postResultNotification(title: script.name, body: body.isEmpty ? "Finished (no output)" : body)
        case .window:
            await MainActor.run {
                NotificationCenter.default.post(
                    name: Self.showResultNotification,
                    object: nil,
                    userInfo: ["result": result]
                )
            }
        }
    }

    /// Trim output to a notification-friendly length.
    static func truncatedForNotification(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > notificationOutputLimit else { return trimmed }
        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: notificationOutputLimit)
        return String(trimmed[trimmed.startIndex ..< endIndex]) + "…"
    }

    private func logFirstValueActionIfNeeded() {
        let key = "SaneApps.EventTracker.logged.saneclick.first_value_action"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        Task.detached {
            await EventTracker.log("first_value_action", app: "saneclick")
        }
    }

    // MARK: - User Notifications

    private func maybeNotifyUser(for result: ScriptExecutionResult, script: Script) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "showActionNotifications") == nil {
            defaults.set(true, forKey: "showActionNotifications")
        }

        guard defaults.bool(forKey: "showActionNotifications") else { return }
        guard shouldNotify(for: script) else { return }

        let body = if result.success {
            "\(script.name) completed"
        } else if let error = result.error {
            "\(script.name) failed: \(error)"
        } else {
            "\(script.name) failed"
        }

        postNotification(title: "SaneClick", body: body)
    }

    /// Posts a result-bearing notification for an explicitly chosen output mode
    /// (copy/notify). Unlike `maybeNotifyUser`, this intentionally does NOT gate
    /// on `showActionNotifications` or the self-notification suppression: the user
    /// opted this action into surfacing its result, so we always honor that.
    private func postResultNotification(title: String, body: String) {
        postNotification(title: title, body: body)
    }

    /// Builds and delivers a `UNUserNotification`, requesting authorization the
    /// first time. Shared by the standard completion path and the result modes.
    private func postNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

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
        !Self.scriptSelfNotifies(script)
    }

    /// Pure helper: does this script raise its own notification (so SaneClick's
    /// standard completion notification would be redundant)? On the App Store
    /// build, native actions run through the executor and never call
    /// `osascript`, so they are never treated as self-notifying even though their
    /// library content references it. Used by both `outputSink(.standard)` and
    /// `shouldNotify`.
    static func scriptSelfNotifies(_ script: Script) -> Bool {
        #if APP_STORE
            if AppStoreNativeAction(script: script) != nil {
                return false
            }
        #endif

        let lowerContent = script.content.lowercased()
        return lowerContent.contains("display notification") || lowerContent.contains("osascript -e")
    }

    // MARK: - Execution Methods

    #if !APP_STORE
        private func executeBash(content: String, paths: [String]) async -> Result<String, ScriptError> {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
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

        /// Runs a native-runtime action (OCR/PDF/copy-path variants plus the
        /// native-preferred image transforms) on the direct build. The direct
        /// build is non-sandboxed, so no `MonitoredFolders.beginAccess` scope is
        /// needed — these actions only read, copy to the clipboard, or write new
        /// files next to the source (image transforms write a new file via
        /// `uniqueDestinationURL` and never edit the original).
        private func executeNativeAction(_ action: AppStoreNativeAction, paths: [String]) -> Result<String, ScriptError> {
            do {
                return try .success(AppStoreNativeActionExecutor.execute(action, paths: paths))
            } catch let error as ScriptError {
                return .failure(error)
            } catch {
                return .failure(.executionFailed(error.localizedDescription))
            }
        }
    #else

        private func executeAppStoreAction(script: Script, paths: [String]) -> Result<String, ScriptError> {
            guard let action = AppStoreNativeAction(script: script) else {
                return .failure(.executionFailed("This action is not available in the App Store build."))
            }

            guard let accessScope = MonitoredFolders.beginAccess(for: paths) else {
                return .failure(.executionFailed("Add the selected folder to Monitored Folders in Settings first."))
            }
            defer { accessScope.stop() }

            do {
                return try .success(AppStoreNativeActionExecutor.execute(action, paths: paths))
            } catch let error as ScriptError {
                return .failure(error)
            } catch {
                return .failure(.executionFailed(error.localizedDescription))
            }
        }
    #endif
}

// MARK: - Errors

enum ScriptError: Error, LocalizedError {
    case launchFailed(String)
    case executionFailed(String)
    case workflowNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .launchFailed(reason):
            "Failed to launch script: \(reason)"
        case let .executionFailed(reason):
            "Script execution failed: \(reason)"
        case let .workflowNotFound(path):
            "Automator workflow not found: \(path)"
        }
    }
}
