import SwiftUI

struct SettingsView: View {
    @Environment(ScriptStore.self) private var scriptStore
    @StateObject private var updateService = UpdateService.shared
    @AppStorage(AppPreferences.showActionNotificationsKey) private var showActionNotifications = true
    @AppStorage(AppPreferences.showMenuBarIconKey) private var showMenuBarIcon = true
    @AppStorage(AppPreferences.showDockIconKey) private var showDockIcon = true
    @State private var extensionStatus = ExtensionStatusService.checkStatus()
    @State private var isCheckingStatus = false

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("Right-Click Menu") {
                HStack {
                    Text("Status")
                    Spacer()
                    Label(extensionStatus.statusText, systemImage: extensionStatus.icon)
                        .foregroundStyle(statusColor)
                }

                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .help("Enable or disable SaneClick in System Settings")

                HStack(spacing: 12) {
                    Button("Refresh Status") {
                        refreshExtensionStatus()
                    }
                    .disabled(isCheckingStatus)

                    if extensionStatus == .enabledNotRunning {
                        Button("Restart Finder") {
                            FinderControl.restartFinder()
                            refreshExtensionStatus()
                        }
                    }
                }
            }

            Section("Your Actions") {
                HStack {
                    Text("Total actions")
                    Spacer()
                    Text("\(scriptStore.scripts.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Active actions")
                    Spacer()
                    Text("\(scriptStore.enabledScripts.count)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("App Visibility") {
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                    .help("Keep SaneClick available in your menu bar")

                Toggle("Show app in Dock", isOn: $showDockIcon)
                    .help("Show SaneClick in the Dock and Cmd+Tab")

                Text("If you hide both, open SaneClick from Applications.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle("Show action confirmations", isOn: $showActionNotifications)
                    .help("Show a notification when an action finishes")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            refreshExtensionStatus()
        }
        .onChange(of: showMenuBarIcon) { _, newValue in
            Task { @MainActor in
                MenuBarController.shared.setEnabled(newValue)
            }
        }
        .onChange(of: showDockIcon) { _, newValue in
            Task { @MainActor in
                ActivationPolicyManager.applyPolicy(showDockIcon: newValue)
            }
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 64))
                .foregroundStyle(.teal)

            Text("SaneClick")
                .font(.title)

            Text("Version \(appVersion)")
                .foregroundStyle(.secondary)

            Text("Add custom actions to your right-click menu")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            HStack(spacing: 16) {
                Link(destination: URL(string: "https://github.com/sane-apps/SaneClick")!) {
                    Label("GitHub", systemImage: "link")
                }

                Link(destination: URL(string: "https://saneclick.com")!) {
                    Label("Website", systemImage: "globe")
                }
            }

            Text("MIT License")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button("Check for Updates") {
                updateService.checkForUpdates()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return version ?? "Unknown"
    }

    private var statusColor: Color {
        switch extensionStatus {
        case .active:
            return .green
        case .enabledNotRunning:
            return .orange
        case .disabled:
            return .red
        }
    }

    private func refreshExtensionStatus() {
        isCheckingStatus = true
        DispatchQueue.global(qos: .userInitiated).async {
            let status = ExtensionStatusService.checkStatus()
            DispatchQueue.main.async {
                extensionStatus = status
                isCheckingStatus = false
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(ScriptStore.shared)
}
