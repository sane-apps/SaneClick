#if os(macOS) && !APP_STORE && !SETAPP
import AppKit
import SaneUI
import SwiftUI

extension LicenseService.DirectCopy {
    static let saneClick = Self(
        alternateUnlockLabel: "Use Activation Code",
        alternateEntryLabel: "Enter Code",
        accessManagementLabel: "Remove Unlock",
        alternateEntryInstruction: "Paste your activation code from the confirmation email."
    )
}

enum SaneAppMover {
    struct Prompt: Sendable {
        let messageText: String
        let informativeText: String
        let moveButtonTitle: String
        let cancelButtonTitle: String
    }

    private static var osascriptExecutableURL: URL {
        URL(fileURLWithPath: "/usr/bin/osascript")
    }

    @MainActor
    @discardableResult
    static func moveToApplicationsFolderIfNeeded(prompt: Prompt) -> Bool {
        if ProcessInfo.processInfo.environment["SANEAPPS_SKIP_MOVE_TO_APPLICATIONS"] == "1" ||
            ProcessInfo.processInfo.arguments.contains("--sane-skip-app-move") {
            return false
        }

        let appPath = Bundle.main.bundlePath
        let appBundleName = URL(fileURLWithPath: appPath).lastPathComponent
        guard !SaneInstallLocation.isInApplicationsDirectory(appPath) else { return false }

        NSApp.activate()

        let alert = NSAlert()
        alert.messageText = prompt.messageText
        alert.informativeText = prompt.informativeText.replacingOccurrences(of: "{appName}", with: appBundleName)
        alert.alertStyle = .informational
        alert.addButton(withTitle: prompt.moveButtonTitle)
        alert.addButton(withTitle: prompt.cancelButtonTitle)
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        let destinationPath = "/Applications/\(appBundleName)"
        let fileManager = FileManager.default
        var moved = false

        do {
            if fileManager.fileExists(atPath: destinationPath) {
                try fileManager.removeItem(atPath: destinationPath)
            }
            try fileManager.moveItem(atPath: appPath, toPath: destinationPath)
            moved = true
        } catch {
            moved = false
        }

        if !moved {
            let escapedSourcePath = appPath.replacingOccurrences(of: "'", with: "'\\''")
            let escapedDestinationPath = destinationPath.replacingOccurrences(of: "'", with: "'\\''")
            let script = "do shell script \"rm -rf '\(escapedDestinationPath)' && mv '\(escapedSourcePath)' '\(escapedDestinationPath)'\" with administrator privileges"

            let osa = Process()
            osa.executableURL = osascriptExecutableURL
            osa.arguments = ["-e", script]
            do {
                try osa.run()
                osa.waitUntilExit()
                guard osa.terminationStatus == 0 else { return false }
            } catch {
                return false
            }
        }

        do {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-n", destinationPath]
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return false }
        } catch {
            return false
        }

        NSApp.terminate(nil)
        return true
    }
}

struct SaneSparkleRow: View {
    struct Labels: Sendable {
        let automaticCheckLabel: String
        let automaticCheckHelp: String
        let checkFrequencyLabel: String
        let checkFrequencyHelp: String
        let actionsLabel: String
        let checkingLabel: String
        let checkNowLabel: String
        let checkNowHelp: String

        static let `default` = Labels(
            automaticCheckLabel: "Check for updates automatically",
            automaticCheckHelp: "Periodically check for new versions",
            checkFrequencyLabel: "Check frequency",
            checkFrequencyHelp: "Choose how often automatic update checks run",
            actionsLabel: "Actions",
            checkingLabel: "Checking...",
            checkNowLabel: "Check Now",
            checkNowHelp: "Check for updates right now"
        )
    }

    @Binding private var automaticallyChecks: Bool
    @Binding private var checkFrequency: SaneSparkleCheckFrequency
    private let labels: Labels
    private let onCheckNow: () -> Void
    @State private var isChecking = false

    init(
        automaticallyChecks: Binding<Bool>,
        checkFrequency: Binding<SaneSparkleCheckFrequency>,
        onCheckNow: @escaping () -> Void
    ) {
        self.init(
            automaticallyChecks: automaticallyChecks,
            checkFrequency: checkFrequency,
            labels: .default,
            onCheckNow: onCheckNow
        )
    }

    init(
        automaticallyChecks: Binding<Bool>,
        checkFrequency: Binding<SaneSparkleCheckFrequency>,
        labels: Labels,
        onCheckNow: @escaping () -> Void
    ) {
        _automaticallyChecks = automaticallyChecks
        _checkFrequency = checkFrequency
        self.labels = labels
        self.onCheckNow = onCheckNow
    }

    var body: some View {
        CompactToggle(label: labels.automaticCheckLabel, isOn: $automaticallyChecks)
            .help(labels.automaticCheckHelp)

        CompactDivider()

        CompactRow(labels.checkFrequencyLabel) {
            Picker("", selection: $checkFrequency) {
                ForEach(SaneSparkleCheckFrequency.allCases) { frequency in
                    Text(frequency.title).tag(frequency)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
            .disabled(!automaticallyChecks)
        }
        .help(labels.checkFrequencyHelp)

        CompactDivider()

        CompactRow(labels.actionsLabel) {
            Button(isChecking ? labels.checkingLabel : labels.checkNowLabel) {
                guard !isChecking else { return }
                isChecking = true
                onCheckNow()

                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(5))
                    isChecking = false
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isChecking)
            .help(labels.checkNowHelp)
        }
    }
}
#endif
