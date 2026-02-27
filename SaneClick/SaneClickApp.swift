import FinderSync
import SaneUI
import SwiftUI

class SaneClickAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
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

        #if !APP_STORE
            // Check for Updates
            let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
            updateItem.target = self
            dockMenu.addItem(updateItem)
        #endif

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

    #if !APP_STORE
        @MainActor @objc private func checkForUpdates() {
            UpdateService.shared.checkForUpdates()
        }
    #endif

    @MainActor @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct SaneClickApp: App {
    @NSApplicationDelegateAdaptor(SaneClickAppDelegate.self) private var appDelegate
    @State private var scriptStore = ScriptStore.shared
    @State private var licenseService = LicenseService(
        appName: "SaneClick",
        checkoutURL: URL(string: "https://go.saneapps.com/buy/saneclick")!
    )
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    init() {
        AppPreferences.registerDefaults()

        // Menu bar icon + Dock visibility
        DispatchQueue.main.async {
            Task { @MainActor in
                MenuBarController.shared.setEnabled(AppPreferences.showMenuBarIcon)
                SaneActivationPolicy.applyInitialPolicy(showDockIcon: AppPreferences.showDockIcon)
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
            ContentView(licenseService: licenseService)
                .environment(scriptStore)
                .preferredColorScheme(.dark)
                .sheet(isPresented: Binding(
                    get: { !hasSeenWelcome },
                    set: { showing in if !showing { hasSeenWelcome = true } }
                )) {
                    WelcomeGateView(
                        appName: "SaneClick",
                        appIcon: "cursorarrow.click.2",
                        freeFeatures: [
                            ("star.fill", "10 Essential Finder actions"),
                            ("cursorarrow.click.2", "Right-click on any file or folder"),
                            ("checkmark.shield", "No account or signup needed")
                        ],
                        proFeatures: [
                            ("square.stack.3d.up.fill", "All 50+ scripts across 5 categories"),
                            ("chevron.left.forwardslash.chevron.right", "12 Coding scripts"),
                            ("photo.on.rectangle.angled", "10 Images & Media scripts"),
                            ("wrench.and.screwdriver.fill", "10 Advanced scripts"),
                            ("folder.fill", "8 Files & Folders scripts"),
                            ("square.and.pencil", "Custom Script Editor"),
                            ("square.and.arrow.up.on.square", "Import / Export scripts")
                        ],
                        licenseService: licenseService
                    )
                    .preferredColorScheme(.dark)
                }
                .onAppear {
                    licenseService.checkCachedLicense()
                    let isPro = licenseService.isPro
                    let isFirstLaunch = !hasSeenWelcome
                    Task.detached {
                        await EventTracker.log(
                            isPro ? "app_launch_pro" : "app_launch_free",
                            app: "saneclick"
                        )
                        if isFirstLaunch, !isPro {
                            await EventTracker.log("new_free_user", app: "saneclick")
                        }
                    }
                }
        }
        // .windowStyle(.hiddenTitleBar) // Temporarily disabled to test file picker
        .defaultSize(width: 600, height: 500)
        .commands {
            AppCommands()
        }

        Settings {
            SettingsView(licenseService: licenseService)
                .environment(scriptStore)
                .preferredColorScheme(.dark)
        }
    }
}

struct AppCommands: Commands {
    var body: some Commands {
        #if !APP_STORE
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    UpdateService.shared.checkForUpdates()
                }
            }
        #endif

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
