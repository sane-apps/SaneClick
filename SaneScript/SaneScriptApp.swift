import SwiftUI

@main
struct SaneScriptApp: App {
    @State private var scriptStore = ScriptStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(scriptStore)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 500)

        Settings {
            SettingsView()
                .environment(scriptStore)
        }
    }
}
