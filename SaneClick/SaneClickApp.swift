import FinderSync
import SaneUI
import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let openMainWindow = Notification.Name("openMainWindow")
}

private enum CrossProcessNotifications {
    static let openMainWindow = NSNotification.Name("com.saneclick.openMainWindow")
}

@MainActor
final class SettingsActionStorage {
    static let shared = SettingsActionStorage()
    var openSettings: (() -> Void)?

    func capture(_ action: OpenSettingsAction) {
        openSettings = {
            action()
        }
    }

    func showSettings() {
        if let openSettings {
            openSettings()
        } else {
            NotificationCenter.default.post(name: .openSettings, object: nil)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }

        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
final class WindowActionStorage {
    static let shared = WindowActionStorage()
    var openWindow: ((String) -> Void)?

    func capture(_ action: OpenWindowAction) {
        openWindow = { id in
            action(id: id)
        }
    }

    func showMainWindow() {
        let mainWindow = NSApp.windows.first(where: {
            $0.canBecomeMain &&
                $0.contentView != nil &&
                $0.identifier?.rawValue.contains("main") == true
        })

        if let window = mainWindow {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow?("main")
        }

        NSApp.activate(ignoringOtherApps: true)
    }
}

class SaneClickAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        #if !DEBUG && !APP_STORE
            if SaneAppMover.moveToApplicationsFolderIfNeeded() { return }
        #endif

        DistributedNotificationCenter.default().addObserver(
            forName: CrossProcessNotifications.openMainWindow,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                WindowActionStorage.shared.showMainWindow()
            }
        }
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
        WindowActionStorage.shared.showMainWindow()
    }

    #if !APP_STORE
        @MainActor @objc private func checkForUpdates() {
            UpdateService.shared.checkForUpdates()
        }
    #endif

    @MainActor @objc private func openSettings() {
        SettingsActionStorage.shared.showSettings()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if let openWindow = WindowActionStorage.shared.openWindow {
                openWindow("main")
            } else {
                WindowActionStorage.shared.showMainWindow()
            }
        }
        return true
    }
}

@main
struct SaneClickApp: App {
    @NSApplicationDelegateAdaptor(SaneClickAppDelegate.self) private var appDelegate
    @State private var scriptStore = ScriptStore.shared
    @State private var monitoredFolderService = MonitoredFolderService.shared
    #if APP_STORE
        @State private var licenseService = LicenseService(
            appName: "SaneClick",
            purchaseBackend: .appStore(productID: "com.saneclick.app.pro.unlock.v2")
        )
    #else
        @State private var licenseService = LicenseService(
            appName: "SaneClick",
            checkoutURL: LicenseService.directCheckoutURL(appSlug: "saneclick")
        )
    #endif
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
        WindowGroup(id: "main") {
            ContentView(licenseService: licenseService)
                .environment(scriptStore)
                .environment(monitoredFolderService)
                .modifier(SettingsLauncher())
                .modifier(SettingsActionCapture())
                .modifier(WindowActionCapture())
                .preferredColorScheme(.dark)
                .sheet(isPresented: Binding(
                    get: { !hasSeenWelcome },
                    set: { showing in if !showing { hasSeenWelcome = true } }
                )) {
                    WelcomeGateView(
                        appName: "SaneClick",
                        appIcon: "cursorarrow.click.2",
                        freeFeatures: welcomeFreeFeatures,
                        proFeatures: welcomeProFeatures,
                        licenseService: licenseService
                    )
                    .preferredColorScheme(.dark)
                }
                .onAppear {
                    licenseService.checkCachedLicense()
                    let isPro = licenseService.isPro
                    let isFirstLaunch = !hasSeenWelcome
                    if SaneBackgroundAppDefaults.launchAtLogin {
                        _ = SaneLoginItemPolicy.enableByDefaultIfNeeded(isFirstLaunch: isFirstLaunch)
                    }
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
                .environment(monitoredFolderService)
                .preferredColorScheme(.dark)
        }
    }
}

struct SettingsLauncher: ViewModifier {
    @Environment(\.openSettings) private var openSettings

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
    }
}

struct SettingsActionCapture: ViewModifier {
    @Environment(\.openSettings) private var openSettings

    func body(content: Content) -> some View {
        content
            .onAppear {
                SettingsActionStorage.shared.capture(openSettings)
            }
    }
}

struct WindowActionCapture: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content
            .onAppear {
                WindowActionStorage.shared.capture(openWindow)
            }
    }
}

private let welcomeFreeFeatures: [(String, String)] = {
    #if APP_STORE
        [
            ("star.fill", "9 built-in Finder actions"),
            ("folder.badge.gearshape", "Choose the folders SaneClick watches"),
            ("checkmark.shield", "No account or signup needed")
        ]
    #else
        [
            ("star.fill", "10 Essential Finder actions"),
            ("cursorarrow.click.2", "Right-click on any file or folder"),
            ("checkmark.shield", "No account or signup needed")
        ]
    #endif
}()

private let welcomeProFeatures: [(String, String)] = {
    #if APP_STORE
        [
            ("folder.fill", "7 Files & Folders actions"),
            ("wrench.and.screwdriver.fill", "2 Advanced hashing actions")
        ]
    #else
        [
            ("square.stack.3d.up.fill", "All 50+ scripts across 5 categories"),
            ("chevron.left.forwardslash.chevron.right", "12 Coding scripts"),
            ("photo.on.rectangle.angled", "10 Images & Media scripts"),
            ("wrench.and.screwdriver.fill", "10 Advanced scripts"),
            ("folder.fill", "8 Files & Folders scripts"),
            ("square.and.pencil", "Custom Script Editor"),
            ("square.and.arrow.up.on.square", "Import / Export scripts")
        ]
    #endif
}()

struct AppCommands: Commands {
    var body: some Commands {
        #if !APP_STORE
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
        #endif
    }
}

extension Notification.Name {
    static let importScriptsRequested = Notification.Name("importScriptsRequested")
    static let exportAllScriptsRequested = Notification.Name("exportAllScriptsRequested")
}
