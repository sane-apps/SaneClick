import SaneUI
import SwiftUI

struct SettingsView: View {
    enum Tab: String, SaneSettingsTab {
        case general = "General"
        case license = "License"
        case about = "About"

        var title: String {
            switch self {
            case .general: SaneSettingsStrings.generalTabTitle
            case .license: SaneSettingsStrings.licenseTabTitle
            case .about: SaneSettingsStrings.aboutTabTitle
            }
        }

        var icon: String {
            switch self {
            case .general: "gearshape"
            case .license: "key.fill"
            case .about: "info.circle"
            }
        }

        var iconColor: Color {
            switch self {
            case .general: SaneSettingsIconSemantic.general.color
            case .license: SaneSettingsIconSemantic.license.color
            case .about: SaneSettingsIconSemantic.about.color
            }
        }
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
    @AppStorage(
        SaneClickSharedDefaults.showOpenMainWindowMenuItemKey,
        store: SaneClickSharedDefaults.userDefaults
    ) private var showOpenMainWindowMenuItem = true
    @State private var extensionStatus = ExtensionStatusService.checkStatus()
    @State private var isCheckingStatus = false
    @State private var selectedTab: Tab?

    init(licenseService: LicenseService, initialTab: Tab? = .general) {
        self.licenseService = licenseService
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        SaneSettingsContainer(defaultTab: .general, selection: $selectedTab) { tab in
            switch tab {
            case .general:
                generalTab
            case .license:
                licenseTab
            case .about:
                aboutTab
            }
        }
    }

    // MARK: - License Tab

    private var licenseTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                LicenseSettingsView(licenseService: licenseService, style: .panel)
                    .frame(maxWidth: 420, alignment: .leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                CompactSection(SaneClickSettingsCopy.rightClickMenuSectionTitle, icon: "cursorarrow.click.2", iconColor: SaneSettingsIconSemantic.content.color) {
                    CompactRow(SaneSettingsStrings.statusLabel, icon: extensionStatus.icon, iconColor: statusColor) {
                        StatusBadge(extensionStatus.statusText, color: statusColor)
                    }

                    CompactDivider()

                    CompactRow(SaneSettingsStrings.actionsLabel, icon: "slider.horizontal.3", iconColor: .white) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                openSystemSettingsButton
                                refreshStatusButton
                                if extensionStatus == .enabledNotRunning {
                                    restartFinderButton
                                }
                            }

                            VStack(alignment: .trailing, spacing: 8) {
                                openSystemSettingsButton
                                refreshStatusButton
                                if extensionStatus == .enabledNotRunning {
                                    restartFinderButton
                                }
                            }
                        }
                    }

                    CompactDivider()

                    CompactToggle(
                        label: SaneClickSettingsCopy.showOpenMainWindowMenuItemLabel,
                        icon: "gearshape",
                        iconColor: .white,
                        isOn: $showOpenMainWindowMenuItem
                    )
                    .help(SaneClickSettingsCopy.showOpenMainWindowMenuItemHelp)
                }

                #if APP_STORE
                    CompactSection(SaneClickSettingsCopy.monitoredFoldersSectionTitle, icon: "folder.badge.gearshape", iconColor: SaneSettingsIconSemantic.content.color) {
                        if monitoredFolderService.folders.isEmpty {
                            readableHint(SaneClickSettingsCopy.monitoredFoldersEmptyStateHint)
                        } else {
                            let folders = monitoredFolderService.folders
                            ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 12) {
                                        Text(folder.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)

                                        Spacer(minLength: 12)

                                        Button(SaneClickSettingsCopy.removeButtonTitle) {
                                            monitoredFolderService.removeFolder(folder)
                                        }
                                        .buttonStyle(SaneActionButtonStyle(destructive: true, compact: true))
                                    }

                                    Text(folder.path)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)

                                if index < folders.count - 1 {
                                    CompactDivider()
                                }
                            }
                        }

                        if !monitoredFolderService.folders.isEmpty {
                            CompactDivider()
                        }

                        CompactRow(SaneSettingsStrings.actionsLabel, icon: "plus.circle.fill", iconColor: .saneAccent) {
                            Button(SaneClickSettingsCopy.addFolderButtonTitle) {
                                monitoredFolderService.addFolders()
                            }
                            .buttonStyle(SaneActionButtonStyle())
                        }

                        if let lastError = monitoredFolderService.lastError {
                            CompactDivider()
                            readableHint(lastError)
                        }
                    }
                #endif

                CompactSection(SaneClickSettingsCopy.yourActionsSectionTitle, icon: "square.stack.3d.up.fill", iconColor: SaneSettingsIconSemantic.content.color) {
                    CompactRow(SaneClickSettingsCopy.totalActionsLabel, icon: "square.stack.3d.up.fill", iconColor: .white) {
                        valueText("\(scriptStore.scripts.count)")
                    }

                    CompactDivider()

                    CompactRow(SaneClickSettingsCopy.activeActionsLabel, icon: "checkmark.circle.fill", iconColor: .green) {
                        valueText("\(scriptStore.enabledScripts.count)")
                    }
                }

                CompactSection(SaneClickSettingsCopy.appBehaviorSectionTitle, icon: "switch.2", iconColor: SaneSettingsIconSemantic.general.color) {
                    SaneLoginItemToggle()
                    CompactDivider()
                    SaneDockIconToggle(showDockIcon: $showDockIcon)
                    CompactDivider()
                    CompactToggle(
                        label: SaneClickSettingsCopy.showMenuBarIconLabel,
                        icon: "menubar.rectangle",
                        iconColor: .white,
                        isOn: showMenuBarIconBinding
                    )
                    .help(SaneClickSettingsCopy.showMenuBarIconHelp)
                    CompactDivider()
                    CompactToggle(
                        label: SaneClickSettingsCopy.showActionConfirmationsLabel,
                        icon: "bell.badge.fill",
                        iconColor: .white,
                        isOn: $showActionNotifications
                    )
                    .help(SaneClickSettingsCopy.showActionConfirmationsHelp)
                    CompactDivider()
                    readableHint(SaneClickSettingsCopy.hiddenIconsHint)
                }

                SaneLanguageSettingsRow()

                #if !APP_STORE
                    CompactSection(SaneSettingsStrings.softwareUpdatesSectionTitle, icon: "arrow.triangle.2.circlepath", iconColor: .saneAccent) {
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
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            refreshExtensionStatus()
            #if !APP_STORE
                automaticallyChecksForUpdates = updateService.automaticallyChecksForUpdates
                updateCheckFrequency = updateService.updateCheckFrequency
            #endif
        }
    }

    private var aboutTab: some View {
        SaneAboutView(
            appName: "SaneClick",
            githubRepo: "SaneClick",
            diagnosticsService: .shared,
            licenses: saneClickAboutLicenses(licenseService: licenseService)
        )
    }

    private var openSystemSettingsButton: some View {
        Button(SaneClickSettingsCopy.openSettingsButtonTitle) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
                NSWorkspace.shared.open(url)
            }
        }
        .buttonStyle(SaneActionButtonStyle())
        .help(SaneClickSettingsCopy.openSettingsHelp)
    }

    private var refreshStatusButton: some View {
        Button(isCheckingStatus ? SaneClickSettingsCopy.refreshingButtonTitle : SaneClickSettingsCopy.refreshButtonTitle) {
            refreshExtensionStatus()
        }
        .buttonStyle(SaneActionButtonStyle())
        .disabled(isCheckingStatus)
        .help(SaneClickSettingsCopy.refreshHelp)
    }

    private var restartFinderButton: some View {
        Button(SaneClickSettingsCopy.restartFinderButtonTitle) {
            FinderControl.restartFinder()
            refreshExtensionStatus()
        }
        .buttonStyle(SaneActionButtonStyle())
        .help(SaneClickSettingsCopy.restartFinderHelp)
    }

    private var showMenuBarIconBinding: Binding<Bool> {
        Binding(
            get: { showMenuBarIcon },
            set: { newValue in
                showMenuBarIcon = newValue
                Task { @MainActor in
                    MenuBarController.shared.setEnabled(newValue)
                }
            }
        )
    }

    private func readableHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
    }

    private func valueText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
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

struct CustomActionsManagerView: View {
    let scripts: [Script]
    let onToggle: (Script) -> Void
    let onEdit: (Script) -> Void
    let onDelete: (Script) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if scripts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 36))
                            .foregroundStyle(.orange)

                        Text("No Custom Actions")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("Your custom actions will appear here so you can edit, disable, or remove them.")
                            .font(.body)
                            .foregroundStyle(Color.saneSilver)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(scripts) { script in
                                ScriptRow(
                                    script: script,
                                    categoryColor: .orange,
                                    onToggle: { onToggle(script) },
                                    onEdit: { onEdit(script) },
                                    onDelete: { onDelete(script) }
                                )
                            }
                        }
                        .padding(20)
                    }
                    .background(Color.saneNavy.opacity(0.3))
                }
            }
            .navigationTitle("Custom Actions")
        }
        .frame(minWidth: 540, minHeight: 420)
    }
}

struct QuickActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var isLocked: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isLocked ? Color.saneSilver : color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                if isLocked {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                        Text("Pro")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.teal)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

struct CategoryRow: View {
    let category: ScriptLibrary.ScriptCategory
    let totalCount: Int
    let activeCount: Int
    var isLocked: Bool = false

    private var categoryColor: Color {
        switch category.colorName {
        case "blue": .blue
        case "green": Color(red: 0.13, green: 0.77, blue: 0.37)
        case "pink": .pink
        case "purple": .teal
        case "orange": .orange
        default: .blue
        }
    }

    private let successGreen = Color(red: 0.13, green: 0.77, blue: 0.37)

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.body)
                .foregroundStyle(isLocked ? Color.saneSilver : categoryColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.body)
                    .foregroundStyle(.primary)

                if isLocked {
                    Text("Pro")
                        .font(.caption)
                        .foregroundStyle(.teal)
                } else {
                    Text("\(activeCount) active")
                        .font(.caption)
                        .foregroundStyle(activeCount > 0 ? successGreen : .white.opacity(0.9))
                }
            }

            Spacer()

            if isLocked {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Text("Pro")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.teal)
            } else {
                Text("\(totalCount)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(categoryColor.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

struct ScriptRow: View {
    let script: Script
    let categoryColor: Color
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private let successGreen = Color(red: 0.13, green: 0.77, blue: 0.37)

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: script.icon)
                .font(.title3)
                .foregroundStyle(script.isEnabled ? successGreen : Color.saneSilver)
                .frame(width: 36, height: 36)
                .background(script.isEnabled ? successGreen.opacity(0.15) : Color.saneSmoke)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(script.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(script.isEnabled ? Color.saneCloud : Color.saneSilver)

                if !script.fileExtensions.isEmpty {
                    Text(script.fileExtensions.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(Color.saneSilver)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { script.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .tint(successGreen)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.saneCarbon)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isHovered ? categoryColor.opacity(0.5) : Color.saneSmoke, lineWidth: 1)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove", systemImage: "trash")
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
    let showOpenMainWindowMenuItem = SaneClickSharedDefaults.showOpenMainWindowMenuItem()
    let scriptStore = ScriptStore.shared
    let monitoredFolderCount = MonitoredFolderService.shared.folders.count
    let extensionStatus = ExtensionStatusService.checkStatus().statusText

    #if APP_STORE
        let updateChecks = "app_store_build"
    #else
        let updateChecks = UpdateService.shared.automaticallyChecksForUpdates ? "enabled" : "disabled"
    #endif

    return "extensionStatus: \(extensionStatus)\n" +
        "totalScripts: \(scriptStore.scripts.count)\n" +
        "enabledScripts: \(scriptStore.enabledScripts.count)\n" +
        "monitoredFolderCount: \(monitoredFolderCount)\n\n" +
        "settings:\n" +
        "  launchAtLogin: \(SaneLoginItemPolicy.toggleValue())\n" +
        "  showMenuBarIcon: \(showMenuBarIcon)\n" +
        "  showDockIcon: \(showDockIcon)\n" +
        "  showActionNotifications: \(showActionNotifications)\n" +
        "  showOpenMainWindowMenuItem: \(showOpenMainWindowMenuItem)\n" +
        "  softwareUpdates: \(updateChecks)"
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
            purchaseBackend: .appStore(productID: "com.saneclick.app.pro.actions.v4")
        )
    #else
        LicenseService(
            appName: "SaneClick",
            checkoutURL: LicenseService.directCheckoutURL(appSlug: "saneclick"),
            directCopy: LicenseService.DirectCopy.saneClick
        )
    #endif
}

@MainActor
private func saneClickAboutLicenses(licenseService: LicenseService) -> [SaneAboutView.LicenseEntry] {
    guard licenseService.distributionChannel.supportsInAppUpdates else { return [] }

    let sparkleLicense = SaneAboutView.LicenseEntry(
        name: "Sparkle",
        url: "https://sparkle-project.org",
        text: "Copyright (c) 2006-2013 Andy Matuschak.\n" +
            "Copyright (c) 2009-2013 Elgato Systems GmbH.\n" +
            "Copyright (c) 2011-2014 Kornel Lesiński.\n" +
            "Copyright (c) 2015-2017 Mayur Pawashe.\n" +
            "Copyright (c) 2014 C.W. Betts.\n" +
            "Copyright (c) 2014 Petroules Corporation.\n" +
            "Copyright (c) 2014 Big Nerd Ranch.\n" +
            "All rights reserved.\n\n" +
            "Permission is hereby granted, free of charge, to any person obtaining a copy of\n" +
            "this software and associated documentation files (the \"Software\"), to deal in\n" +
            "the Software without restriction, including without limitation the rights to\n" +
            "use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies\n" +
            "of the Software, and to permit persons to whom the Software is furnished to do\n" +
            "so, subject to the following conditions:\n\n" +
            "The above copyright notice and this permission notice shall be included in all\n" +
            "copies or substantial portions of the Software.\n\n" +
            "THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\n" +
            "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS\n" +
            "FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR\n" +
            "COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER\n" +
            "IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN\n" +
            "CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE."
    )

    return [sparkleLicense]
}
