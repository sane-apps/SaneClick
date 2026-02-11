import FinderSync
import SwiftUI

class SaneClickAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        #if !DEBUG
            SaneAppMover.moveToApplicationsFolderIfNeeded()
        #endif
    }

    func applicationDockMenu(_: NSApplication) -> NSMenu? {
        let dockMenu = NSMenu()

        // Open SaneClick
        let openItem = NSMenuItem(title: "Open SaneClick", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        dockMenu.addItem(openItem)

        dockMenu.addItem(.separator())

        // Check for Updates
        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        dockMenu.addItem(updateItem)

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        dockMenu.addItem(settingsItem)

        return dockMenu
    }

    @MainActor @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.isMainWindow || $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @MainActor @objc private func checkForUpdates() {
        UpdateService.shared.checkForUpdates()
    }

    @MainActor @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct SaneClickApp: App {
    @NSApplicationDelegateAdaptor(SaneClickAppDelegate.self) private var appDelegate
    @State private var scriptStore = ScriptStore.shared
    @State private var showWelcome = OnboardingHelper.needsOnboarding

    init() {
        AppPreferences.registerDefaults()

        // Menu bar icon + Dock visibility
        DispatchQueue.main.async {
            Task { @MainActor in
                MenuBarController.shared.setEnabled(AppPreferences.showMenuBarIcon)
                ActivationPolicyManager.applyPolicy(showDockIcon: AppPreferences.showDockIcon)
            }
        }

        // Initialize ScriptExecutor to register notification listener for extension requests
        _ = ScriptExecutor.shared

        // Prompt user to enable Finder extension if not already enabled
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !FIFinderSyncController.isExtensionEnabled {
                FIFinderSyncController.showExtensionManagementInterface()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(scriptStore)
                .sheet(isPresented: $showWelcome) {
                    WelcomeView()
                        .environment(scriptStore)
                }
        }
        // .windowStyle(.hiddenTitleBar) // Temporarily disabled to test file picker
        .defaultSize(width: 600, height: 500)
        .commands {
            AppCommands()
        }

        Settings {
            SettingsView()
                .environment(scriptStore)
        }
    }
}

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates...") {
                UpdateService.shared.checkForUpdates()
            }
        }

        CommandGroup(after: .newItem) {
            Button("Import Scripts...") {
                NotificationCenter.default.post(name: .importScriptsRequested, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Export All Scripts...") {
                NotificationCenter.default.post(name: .exportAllScriptsRequested, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }
    }
}

extension Notification.Name {
    static let importScriptsRequested = Notification.Name("importScriptsRequested")
    static let exportAllScriptsRequested = Notification.Name("exportAllScriptsRequested")
}
