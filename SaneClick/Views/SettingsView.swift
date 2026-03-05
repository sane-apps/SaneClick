import SaneUI
import SwiftUI

struct SettingsView: View {
    var licenseService: LicenseService
    @Environment(ScriptStore.self) private var scriptStore
    #if !APP_STORE
        @StateObject private var updateService = UpdateService.shared
        @State private var automaticallyChecksForUpdates = UpdateService.shared.automaticallyChecksForUpdates
        @State private var updateCheckFrequency = UpdateService.shared.updateCheckFrequency
    #endif
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

            licenseTab
                .tabItem {
                    Label("License", systemImage: "key")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 380)
    }

    // MARK: - License Tab

    private var licenseTab: some View {
        Form {
            LicenseSettingsView(licenseService: licenseService)
        }
        .formStyle(.grouped)
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

                    #if !APP_STORE
                        if extensionStatus == .enabledNotRunning {
                            Button("Restart Finder") {
                                FinderControl.restartFinder()
                                refreshExtensionStatus()
                            }
                        }
                    #endif
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
                SaneLoginItemToggle()

                SaneDockIconToggle(showDockIcon: $showDockIcon)

                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                    .help("Keep SaneClick available in your menu bar")

                Text("If you hide both the Dock icon and menu bar icon, open SaneClick from Applications.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle("Show action confirmations", isOn: $showActionNotifications)
                    .help("Show a notification when an action finishes")
            }

            #if !APP_STORE
                Section("Software Updates") {
                    SaneSparkleRow(
                        automaticallyChecks: $automaticallyChecksForUpdates,
                        checkFrequency: $updateCheckFrequency,
                        onCheckNow: { updateService.checkForUpdates() }
                    )
                    .onChange(of: automaticallyChecksForUpdates) { _, newValue in
                        updateService.automaticallyChecksForUpdates = newValue
                    }
                    .onChange(of: updateCheckFrequency) { _, newValue in
                        updateService.updateCheckFrequency = newValue
                    }
                }
            #endif
        }
        .formStyle(.grouped)
        .onAppear {
            refreshExtensionStatus()
            automaticallyChecksForUpdates = updateService.automaticallyChecksForUpdates
            updateCheckFrequency = updateService.updateCheckFrequency
        }
        .onChange(of: showMenuBarIcon) { _, newValue in
            Task { @MainActor in
                MenuBarController.shared.setEnabled(newValue)
            }
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        SaneAboutView(
            appName: "SaneClick",
            githubRepo: "SaneClick"
        )
    }

    private var statusColor: Color {
        switch extensionStatus {
        case .active:
            .green
        case .enabledNotRunning:
            .orange
        case .disabled:
            .red
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
    SettingsView(licenseService: LicenseService(
        appName: "SaneClick",
        checkoutURL: URL(string: "https://go.saneapps.com/buy/saneclick")!
    ))
    .environment(ScriptStore.shared)
}
