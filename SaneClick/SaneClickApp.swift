import SaneUI
import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let openSettingsTab = Notification.Name("openSettingsTab")
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
    private var pendingTab: SettingsView.Tab?

    func capture(_ action: OpenSettingsAction) {
        openSettings = {
            action()
        }
    }

    func showSettings(tab: SettingsView.Tab? = nil) {
        if let tab {
            pendingTab = tab
        }

        if let openSettings {
            openSettings()
        } else {
            NotificationCenter.default.post(name: .openSettings, object: nil)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }

        if let tab {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openSettingsTab, object: tab)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func consumePendingTab() -> SettingsView.Tab? {
        let tab = pendingTab
        pendingTab = nil
        return tab
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

@MainActor
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

        // Present a result window when an action with the "Show result" output
        // mode finishes. ScriptExecutor is a singleton (not a view), so it posts
        // this notification and the host presents the window, reusing the same
        // TestOutputView the editor's test run uses.
        NotificationCenter.default.addObserver(
            forName: ScriptExecutor.showResultNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let result = notification.userInfo?["result"] as? ScriptExecutionResult else { return }
            Task { @MainActor in
                ResultWindowPresenter.shared.present(result)
            }
        }
    }

    func applicationDockMenu(_: NSApplication) -> NSMenu? {
        SaneClickContextMenu.make(
            target: self,
            openAction: #selector(openMainWindow),
            settingsAction: #selector(openSettings),
            licenseAction: #selector(openLicense),
            checkForUpdatesAction: directUpdateAction,
            configureCheckForUpdates: directUpdateConfigurator,
            aboutAction: #selector(openAbout),
            restartFinderAction: directRestartFinderAction,
            toggleDockIconAction: #selector(toggleDockIcon),
            quitAction: #selector(quitApp)
        )
    }

    @MainActor @objc private func openMainWindow() {
        WindowActionStorage.shared.showMainWindow()
    }

    #if !APP_STORE
        private var directUpdateAction: Selector? {
            #selector(checkForUpdates)
        }

        private var directUpdateConfigurator: ((NSMenuItem) -> Void)? {
            { item in
                let updateService = UpdateService.shared
                item.isEnabled = updateService.isUpdateChannelEnabled
                item.toolTip = updateService.isUpdateChannelEnabled ? nil : updateService.updateUnavailableStatus
            }
        }

        private var directRestartFinderAction: Selector? {
            #selector(restartFinder)
        }

        @MainActor @objc private func checkForUpdates() {
            UpdateService.shared.checkForUpdates()
        }

        @MainActor @objc private func restartFinder() {
            FinderControl.restartFinder()
        }
    #else
        private var directUpdateAction: Selector? {
            nil
        }

        private var directUpdateConfigurator: ((NSMenuItem) -> Void)? {
            nil
        }

        private var directRestartFinderAction: Selector? {
            nil
        }
    #endif

    @MainActor @objc private func openSettings() {
        SettingsActionStorage.shared.showSettings()
    }

    @MainActor @objc private func openLicense() {
        SettingsActionStorage.shared.showSettings(tab: .license)
    }

    @MainActor @objc private func openAbout() {
        SettingsActionStorage.shared.showSettings(tab: .about)
    }

    @MainActor @objc private func toggleDockIcon() {
        let newValue = !AppPreferences.showDockIcon
        let state = AppVisibilityCoordinator.setDockIconVisible(newValue)
        if state.showDockIcon {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @MainActor @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
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
            // Store the license in the modern data-protection keychain so a Developer ID
            // signature change across direct updates no longer re-prompts ("wants to use
            // your confidential information") on every keychain item (TN3137). The access
            // group reuses the app's existing application-group entitlement, which macOS
            // also exposes as a keychain access group — so no new entitlement or
            // provisioning profile is required. The service matches the legacy
            // login-keychain item so the one-time migration finds it. (App Store builds
            // are sandboxed and unaffected, so the #if APP_STORE branch keeps the old
            // service-only keychain.)
            keychain: KeychainService(
                service: "com.saneclick.SaneClick",
                accessGroup: "M78L6FXD48.group.com.saneclick.app"
            ),
            directCopy: LicenseService.DirectCopy.saneClick,
            proTrial: .init(storageKeyPrefix: "saneclick.pro_trial")
        )
    #endif
    @State private var showWelcomeGate: Bool

    init() {
        if WelcomeGateState.hasSeenWelcome() {
            WelcomeGateState.purgeRestoredSheetState()
        }
        _showWelcomeGate = State(initialValue: WelcomeGateState.initialPresentation())
        AppPreferences.registerDefaults()
        MonitoredFolders.seedInitialDefaultFoldersIfNeeded()

        // Menu bar icon + Dock visibility
        DispatchQueue.main.async {
            Task { @MainActor in
                AppVisibilityCoordinator.applyInitialVisibility()
            }
        }

        // Initialize ScriptExecutor to register notification listener for extension requests
        _ = ScriptExecutor.shared
        if ProcessInfo.processInfo.arguments.contains("--saneclick-execution-requested") {
            ScriptExecutor.shared.processPendingExecutionAfterLaunchRequest()
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            if licenseService.hasExpiredProTrial {
                LicenseGateView(licenseService: licenseService, appIcon: "cursorarrow.click.2")
                    .preferredColorScheme(.dark)
                    .onAppear {
                        licenseService.checkCachedLicense()
                    }
            } else if shouldAttachWelcomeGate {
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
        .defaultSize(width: 1040, height: 720)
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
                if isFirstLaunch, SaneBackgroundAppDefaults.launchAtLogin {
                    SaneLoginItemPolicy.scheduleDefaultLaunchAtLoginPrompt(appName: "SaneClick")
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
    func makeNSView(context _: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            WindowActionStorage.shared.captureMainWindow(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        DispatchQueue.main.async {
            WindowActionStorage.shared.captureMainWindow(nsView.window)
        }
    }
}

enum SaneClickWelcomeCopy {
    static let basicPrice = "Free"
    static let proPrice: String = {
        #if APP_STORE
            "$14.99 once"
        #else
            "14 days free. No credit card required."
        #endif
    }()

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
                ("checkmark", "Enjoy 14 days of Pro"),
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
        CommandGroup(replacing: .appTermination) {
            Button("Quit SaneClick") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }

        #if !APP_STORE
            CommandGroup(after: .appInfo) {
                Button(SaneStandardMenu.checkForUpdatesTitle) {
                    UpdateService.shared.checkForUpdates()
                }
                .disabled(!UpdateService.shared.isUpdateChannelEnabled)
                .help(UpdateService.shared.isUpdateChannelEnabled ? "" : UpdateService.shared.updateUnavailableStatus)
            }
            CommandGroup(after: .newItem) {
                Button("Import Actions...") {
                    NotificationCenter.default.post(name: .importScriptsRequested, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Export All Actions...") {
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

/// Presents the result of a "Show result" action in a small, dismissible window,
/// reusing the editor's `TestOutputView`. A single reusable window is kept so
/// repeated actions don't stack windows.
@MainActor
final class ResultWindowPresenter {
    static let shared = ResultWindowPresenter()

    private var window: NSWindow?

    func present(_ result: ScriptExecutionResult) {
        // Reuse an existing window if the user already has one open (so we don't
        // yank a window they moved); only size and center on first creation.
        let isNewWindow = window == nil
        let window = window ?? makeWindow()

        let view = TestOutputView(
            scriptName: result.scriptName,
            output: result.output.isEmpty ? "(No output)" : result.output,
            error: result.success ? nil : (result.error ?? "Action failed"),
            onClose: { [weak window] in window?.performClose(nil) },
            completedTitle: "Action Completed",
            failedTitle: "Action Failed"
        )

        let hosting = NSHostingController(rootView: view.preferredColorScheme(.dark))

        window.title = result.scriptName
        window.contentViewController = hosting
        if isNewWindow {
            window.setContentSize(NSSize(width: 500, height: 350))
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        return window
    }
}
