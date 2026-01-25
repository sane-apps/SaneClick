import SwiftUI

@main
struct SaneScriptApp: App {
    @State private var scriptStore = ScriptStore.shared
    @State private var showWelcome = OnboardingHelper.needsOnboarding

    init() {
        // Initialize ScriptExecutor to register notification listener for extension requests
        _ = ScriptExecutor.shared
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
