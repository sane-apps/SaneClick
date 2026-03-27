import SaneUI
import SwiftUI

struct SettingsView: View {
    enum Tab: Hashable {
        case general
        case license
        case about
    }

    var licenseService: LicenseService
    @Environment(ScriptStore.self) private var scriptStore
    @Environment(MonitoredFolderService.self) private var monitoredFolderService
    #if !APP_STORE
        @StateObject private var updateService = UpdateService.shared
        @State private var automaticallyChecksForUpdates = UpdateService.shared.automaticallyChecksForUpdates
        @State private var updateCheckFrequency = UpdateService.shared.updateCheckFrequency
    #endif
    @AppStorage(AppPreferences.showActionNotificationsKey) private var showActionNotifications = true
    @AppStorage(AppPreferences.showMenuBarIconKey) private var showMenuBarIcon = true
    @AppStorage(AppPreferences.showDockIconKey) private var showDockIcon = SaneBackgroundAppDefaults.showDockIcon
    @State private var extensionStatus = ExtensionStatusService.checkStatus()
    @State private var isCheckingStatus = false
    @State private var selectedTab: Tab

    init(licenseService: LicenseService, initialTab: Tab = .general) {
        self.licenseService = licenseService
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(Tab.general)

            licenseTab
                .tabItem {
                    Label("License", systemImage: "key")
                }
                .tag(Tab.license)

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(Tab.about)
        }
        .frame(width: 500, height: 470)
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

            #if APP_STORE
                Section("Monitored Folders") {
                    if monitoredFolderService.folders.isEmpty {
                        Text("Choose the folders where SaneClick should appear in Finder.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(monitoredFolderService.folders) { folder in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.name)
                                        .foregroundStyle(.primary)
                                    Text(folder.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Button("Remove") {
                                    monitoredFolderService.removeFolder(folder)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Button("Add Folder") {
                        monitoredFolderService.addFolders()
                    }

                    if let lastError = monitoredFolderService.lastError {
                        Text(lastError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            #endif

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
                        labels: .init(
                            automaticCheckLabel: "Check for updates automatically",
                            automaticCheckHelp: "Periodically check for new versions",
                            checkFrequencyLabel: "Check frequency",
                            checkFrequencyHelp: "Choose how often automatic update checks run",
                            actionsLabel: "Actions",
                            checkingLabel: "Checking…",
                            checkNowLabel: "Check Now",
                            checkNowHelp: "Check for updates right now"
                        ),
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
            #if !APP_STORE
                automaticallyChecksForUpdates = updateService.automaticallyChecksForUpdates
                updateCheckFrequency = updateService.updateCheckFrequency
            #endif
        }
        .onChange(of: showMenuBarIcon) { _, newValue in
            Task { @MainActor in
                MenuBarController.shared.setEnabled(newValue)
            }
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        #if APP_STORE
            SaneAboutView(
                appName: "SaneClick",
                githubRepo: "SaneClick",
                diagnosticsService: .shared
            )
        #else
            SaneAboutView(
                appName: "SaneClick",
                githubRepo: "SaneClick",
                diagnosticsService: .shared
            )
        #endif
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

extension SaneDiagnosticsService {
    static let shared = SaneDiagnosticsService(
        appName: "SaneClick",
        subsystem: "com.saneclick.SaneClick",
        githubRepo: "SaneClick",
        settingsCollector: { await collectSaneClickSettings() }
    )
}

@MainActor
private func collectSaneClickSettings() -> String {
    let defaults = UserDefaults.standard
    let showActionNotifications = defaults.object(forKey: AppPreferences.showActionNotificationsKey) as? Bool ?? true
    let showMenuBarIcon = defaults.object(forKey: AppPreferences.showMenuBarIconKey) as? Bool ?? true
    let showDockIcon = defaults.object(forKey: AppPreferences.showDockIconKey) as? Bool ?? SaneBackgroundAppDefaults.showDockIcon
    let scriptStore = ScriptStore.shared
    let monitoredFolderCount = MonitoredFolderService.shared.folders.count
    let extensionStatus = ExtensionStatusService.checkStatus().statusText

    #if APP_STORE
        let updateChecks = "app_store_build"
    #else
        let updateChecks = UpdateService.shared.automaticallyChecksForUpdates ? "enabled" : "disabled"
    #endif

    return """
    extensionStatus: \(extensionStatus)
    totalScripts: \(scriptStore.scripts.count)
    enabledScripts: \(scriptStore.enabledScripts.count)
    monitoredFolderCount: \(monitoredFolderCount)

    settings:
      launchAtLogin: \(SaneLoginItemPolicy.toggleValue())
      showMenuBarIcon: \(showMenuBarIcon)
      showDockIcon: \(showDockIcon)
      showActionNotifications: \(showActionNotifications)
      softwareUpdates: \(updateChecks)
    """
}

#Preview {
    SettingsView(licenseService: settingsPreviewLicenseService())
    .environment(ScriptStore.shared)
    .environment(MonitoredFolderService.shared)
}

@MainActor
private func settingsPreviewLicenseService() -> LicenseService {
    #if APP_STORE
        LicenseService(
            appName: "SaneClick",
            purchaseBackend: .appStore(productID: "com.saneclick.app.pro.unlock.v3")
        )
    #else
        LicenseService(
            appName: "SaneClick",
            checkoutURL: LicenseService.directCheckoutURL(appSlug: "saneclick"),
            directCopy: LicenseService.DirectCopy.saneClick
        )
    #endif
}
