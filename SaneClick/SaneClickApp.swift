import SaneUI
import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let openMainWindow = Notification.Name("openMainWindow")
}

private enum CrossProcessNotifications {
    static let openMainWindow = NSNotification.Name("com.saneclick.openMainWindow")
}

enum WelcomeGateState {
    static let hasSeenWelcomeKey = "hasSeenWelcome"
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    static func hasSeenWelcome(defaults: UserDefaults = .standard) -> Bool {
        if let explicitValue = defaults.object(forKey: hasSeenWelcomeKey) as? Bool {
            return explicitValue
        }
        return defaults.bool(forKey: hasCompletedOnboardingKey)
    }

    static func initialPresentation(defaults: UserDefaults = .standard) -> Bool {
        !hasSeenWelcome(defaults: defaults)
    }

    static func markSeen(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: hasSeenWelcomeKey)
        defaults.set(true, forKey: hasCompletedOnboardingKey)
    }

    static func reconcile(isPresented: Bool, defaults: UserDefaults = .standard) -> Bool {
        hasSeenWelcome(defaults: defaults) ? false : isPresented
    }

    @discardableResult
    static func purgeRestoredSheetState(defaults: UserDefaults = .standard) -> Int {
        let staleKeys = defaults.dictionaryRepresentation().keys.filter { key in
            key.contains("SheetPresentationModifier") &&
                (key.contains("WelcomeView") || key.contains("WelcomeGateView"))
        }
        staleKeys.forEach { defaults.removeObject(forKey: $0) }
        return staleKeys.count
    }
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
    weak var mainWindow: NSWindow?

    func capture(_ action: OpenWindowAction) {
        openWindow = { id in
            action(id: id)
        }
    }

    func captureMainWindow(_ window: NSWindow?) {
        guard let window, window.canBecomeMain, !window.isSheet else { return }
        mainWindow = window
    }

    func showMainWindow() {
        let window = mainWindow ?? NSApp.windows.first(where: {
            $0.canBecomeMain &&
                $0.contentView != nil &&
                ($0.identifier?.rawValue.contains("main") == true || !$0.title.isEmpty)
        })

        if let window {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            mainWindow = window
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
            if SaneAppMover.moveToApplicationsFolderIfNeeded(prompt: .init(
                messageText: "Move to Applications?",
                informativeText: "{appName} works best from your Applications folder. Move it there now? You may be asked for your password.",
                moveButtonTitle: "Move to Applications",
                cancelButtonTitle: "Not Now"
            )) { return }
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
            purchaseBackend: .appStore(productID: "com.saneclick.app.pro.actions.v4"),
            keychain: KeychainService(service: "com.saneclick.SaneClick")
        )
    #else
        @State private var licenseService = LicenseService(
            appName: "SaneClick",
            checkoutURL: LicenseService.directCheckoutURL(appSlug: "saneclick"),
            keychain: KeychainService(service: "com.saneclick.SaneClick"),
            directCopy: LicenseService.DirectCopy.saneClick
        )
    #endif
    @State private var showWelcomeGate: Bool

    init() {
        if WelcomeGateState.hasSeenWelcome() {
            WelcomeGateState.purgeRestoredSheetState()
        }
        _showWelcomeGate = State(initialValue: WelcomeGateState.initialPresentation())
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

    }

    var body: some Scene {
        WindowGroup(id: "main") {
            if shouldAttachWelcomeGate {
                mainWindowContent
                    .sheet(isPresented: welcomeGateBinding) {
                        WelcomeGateView(
                            appName: "SaneClick",
                            appIcon: "cursorarrow.click.2",
                            freeFeatures: SaneClickWelcomeCopy.freeFeatures,
                            proFeatures: SaneClickWelcomeCopy.proFeatures,
                            freeTierPrice: SaneClickWelcomeCopy.basicPrice,
                            proTierPriceOverride: SaneClickWelcomeCopy.proPrice,
                            licenseService: licenseService
                        )
                        .preferredColorScheme(.dark)
                    }
            } else {
                mainWindowContent
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

    private var shouldAttachWelcomeGate: Bool {
        showWelcomeGate || !WelcomeGateState.hasSeenWelcome()
    }

    private var welcomeGateBinding: Binding<Bool> {
        Binding(
            get: { showWelcomeGate },
            set: { showing in
                showWelcomeGate = showing
                if !showing {
                    WelcomeGateState.markSeen()
                }
            }
        )
    }

    private var mainWindowContent: some View {
        ContentView(licenseService: licenseService)
            .environment(scriptStore)
            .environment(monitoredFolderService)
            .modifier(SettingsLauncher())
            .modifier(SettingsActionCapture())
            .modifier(WindowActionCapture())
            .background(MainWindowCaptureView())
            .preferredColorScheme(.dark)
            .onAppear {
                if WelcomeGateState.hasSeenWelcome() {
                    WelcomeGateState.purgeRestoredSheetState()
                }
                showWelcomeGate = WelcomeGateState.reconcile(isPresented: showWelcomeGate)
                licenseService.checkCachedLicense()
                let hasSeenWelcome = WelcomeGateState.hasSeenWelcome()
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

struct MainWindowCaptureView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            WindowActionStorage.shared.captureMainWindow(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            WindowActionStorage.shared.captureMainWindow(nsView.window)
        }
    }
}

enum SaneClickWelcomeCopy {
    static let basicPrice = "Included"
    static let proPrice = "One-time unlock"

    static let freeFeatures: [(String, String)] = {
        #if APP_STORE
            [
                ("star.fill", "\(AppStoreActionCatalog.basicActions.count) core Finder actions"),
                ("doc.on.doc.fill", "Copy paths, names, and file info"),
                ("terminal.fill", "Open in Terminal and create text files"),
                ("wand.and.stars", "Reveal, duplicate, clean, and make files executable")
            ]
        #else
            let basicCount = ScriptLibrary.availableScripts(for: .universal).count
            return [
                ("star.fill", "\(basicCount) core Finder actions"),
                ("cursorarrow.click.2", "Run the essentials from any Finder right-click"),
                ("terminal.fill", "Copy, reveal, duplicate, and open folders in Terminal"),
                ("checkmark.shield", "No account or signup needed")
            ]
        #endif
    }()

    static let proFeatures: [(String, String)] = {
        #if APP_STORE
            [
                ("checkmark", "Everything in Basic, plus:"),
                ("folder.badge.plus", "\(AppStoreActionCatalog.proActions.count) more built-in Finder actions"),
                ("folder.badge.gearshape", "Batch rename and organization tools"),
                ("number.square.fill", "MD5 + SHA256 hashing"),
                ("arrow.clockwise", "Restore purchases on your Macs")
            ]
        #else
            let proCount = ScriptLibrary
                .availableCategories
                .filter { $0 != .universal }
                .map { ScriptLibrary.availableScripts(for: $0).count }
                .reduce(0, +)
            return [
                ("checkmark", "Everything in Basic, plus:"),
                ("folder.badge.plus", "\(proCount) more built-in Finder actions"),
                ("square.stack.3d.up.fill", "Developer, media, advanced, and organization tools"),
                ("square.and.pencil", "Build your own custom Finder scripts"),
                ("square.and.arrow.up.on.square", "Import and export your library")
            ]
        #endif
    }()
}

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
