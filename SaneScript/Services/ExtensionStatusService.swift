import Foundation

/// Service to check the status of the Finder Sync extension
enum ExtensionStatusService {

    /// Bundle identifier of the Finder Sync extension
    static let extensionBundleId = "com.sanescript.SaneScript.FinderSync"

    /// Check if the extension is registered and enabled
    static func isExtensionEnabled() -> Bool {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = ["-m", "-v", "-i", extensionBundleId]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            // pluginkit outputs "+" prefix for enabled extensions
            // Example: "+    com.sanescript.SaneScript.FinderSync(1.0.1)"
            return output.contains("+") && output.contains(extensionBundleId)
        } catch {
            return false
        }
    }

    /// Check if the extension process is currently running
    static func isExtensionRunning() -> Bool {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "SaneScriptExtension"]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            // pgrep returns 0 if process found, 1 if not found
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Combined status check
    static func checkStatus() -> ExtensionStatus {
        let enabled = isExtensionEnabled()
        let running = isExtensionRunning()

        if enabled && running {
            return .active
        } else if enabled && !running {
            return .enabledNotRunning
        } else {
            return .disabled
        }
    }
}

/// Extension status states
enum ExtensionStatus: Equatable {
    case active              // Enabled and running
    case enabledNotRunning   // Enabled but Finder hasn't loaded it yet
    case disabled            // Not enabled in System Settings

    var isUsable: Bool {
        self == .active || self == .enabledNotRunning
    }

    var statusText: String {
        switch self {
        case .active:
            return "Extension Active"
        case .enabledNotRunning:
            return "Extension Enabled (Restart Finder)"
        case .disabled:
            return "Extension Disabled"
        }
    }

    var icon: String {
        switch self {
        case .active:
            return "checkmark.circle.fill"
        case .enabledNotRunning:
            return "clock.fill"
        case .disabled:
            return "exclamationmark.triangle.fill"
        }
    }

    var color: String {
        switch self {
        case .active:
            return "green"
        case .enabledNotRunning:
            return "orange"
        case .disabled:
            return "red"
        }
    }
}
