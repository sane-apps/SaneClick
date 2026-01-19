import Foundation

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

/// Executes scripts with selected file paths
actor ScriptExecutor {
    static let shared = ScriptExecutor()

    /// Published execution results for UI to observe
    @MainActor static var lastResult: ScriptExecutionResult?

    /// Notification posted when execution completes
    static let executionCompletedNotification = Notification.Name("com.sanescript.executionCompleted")

    private init() {
        // Listen for execution requests from the extension
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.sanescript.executeScript"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract values before entering async context
            guard let userInfo = notification.userInfo,
                  let scriptIdString = userInfo["scriptId"] as? String,
                  let scriptId = UUID(uuidString: scriptIdString),
                  let pathsData = userInfo["paths"] as? Data,
                  let paths = try? JSONDecoder().decode([String].self, from: pathsData) else {
                return
            }

            Task { @MainActor in
                // Find the script and execute
                if let script = ScriptStore.shared.scripts.first(where: { $0.id == scriptId }) {
                    await self?.execute(script: script, withPaths: paths)
                }
            }
        }
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
    }

    // MARK: - Execution Methods

    private func executeBash(content: String, paths: [String]) async -> Result<String, ScriptError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", content] + paths

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
