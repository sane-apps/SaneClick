import SwiftUI

struct SettingsView: View {
    @Environment(ScriptStore.self) private var scriptStore

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
            Section("Finder Extension") {
                HStack {
                    Text("Extension Status")
                    Spacer()
                    Text("Enabled")
                        .foregroundStyle(.green)
                }

                Button("Open Extension Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .help("Open System Settings to enable or disable the Finder extension")
            }

            Section("Scripts") {
                HStack {
                    Text("Total Scripts")
                    Spacer()
                    Text("\(scriptStore.scripts.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Enabled Scripts")
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
            Image(systemName: "terminal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.teal)

            Text("SaneScript")
                .font(.title)

            Text("Version 1.0.1")
                .foregroundStyle(.secondary)

            Text("Finder context menu customization for macOS")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            HStack(spacing: 16) {
                Link(destination: URL(string: "https://github.com/sane-apps/SaneScript")!) {
                    Label("GitHub", systemImage: "link")
                }

                Link(destination: URL(string: "https://script.saneapps.com")!) {
                    Label("Website", systemImage: "globe")
                }
            }

            Text("MIT License")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

#Preview {
    SettingsView()
        .environment(ScriptStore.shared)
}
