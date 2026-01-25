import SwiftUI

struct SettingsView: View {
    @Environment(ScriptStore.self) private var scriptStore
    @StateObject private var updateService = UpdateService.shared

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("Right-Click Menu") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text("Active")
                        .foregroundStyle(.green)
                }

                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .help("Enable or disable SaneClick in System Settings")
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
        }
        .formStyle(.grouped)
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 64))
                .foregroundStyle(.teal)

            Text("SaneClick")
                .font(.title)

            Text("Version 1.0.2")
                .foregroundStyle(.secondary)

            Text("Add custom actions to your right-click menu")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            HStack(spacing: 16) {
                Link(destination: URL(string: "https://github.com/sane-apps/SaneClick")!) {
                    Label("GitHub", systemImage: "link")
                }

                Link(destination: URL(string: "https://saneclick.com")!) {
                    Label("Website", systemImage: "globe")
                }
            }

            Text("MIT License")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button("Check for Updates") {
                updateService.checkForUpdates()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview {
    SettingsView()
        .environment(ScriptStore.shared)
}
