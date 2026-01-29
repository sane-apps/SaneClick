import SwiftUI

/// First-run welcome view with option to install starter scripts
struct WelcomeView: View {
    @Environment(ScriptStore.self) private var scriptStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPacks: Set<ScriptLibrary.ScriptCategory> = [.universal]

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.saneTeal)

                Text("Welcome to SaneClick")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Add powerful scripts to your Finder right-click menu")
                    .font(.body)
                    .foregroundStyle(Color.saneCloud)
            }

            // Section header
            VStack(alignment: .leading, spacing: 4) {
                Text("Get Started")
                    .font(.headline)

                Text("Pick the actions you want in your right-click menu:")
                    .font(.body)
                    .foregroundStyle(Color.saneSilver)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Category rows - entire row is clickable
            VStack(spacing: 6) {
                ForEach(ScriptLibrary.ScriptCategory.allCases, id: \.self) { category in
                    StarterPackRow(
                        category: category,
                        isSelected: selectedPacks.contains(category)
                    ) {
                        if selectedPacks.contains(category) {
                            selectedPacks.remove(category)
                        } else {
                            selectedPacks.insert(category)
                        }
                    }
                }
            }

            // Action buttons
            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    Button("Skip for Now") {
                        markOnboardingComplete()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button("Install \(selectedScriptCount) Scripts") {
                        installSelectedPacks()
                        markOnboardingComplete()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(selectedPacks.isEmpty)
                }

                Text("You can add more anytime from the app")
                    .font(.subheadline)
                    .foregroundStyle(Color.saneSilver)
            }
        }
        .padding(24)
        .frame(width: 440, height: 620)
    }

    private var selectedScriptCount: Int {
        selectedPacks.reduce(0) { $0 + ScriptLibrary.scripts(for: $1).count }
    }

    private func installSelectedPacks() {
        let existingNames = Set(scriptStore.scripts.map { $0.name })
        for category in selectedPacks {
            for script in ScriptLibrary.scripts(for: category) {
                if !existingNames.contains(script.name) {
                    scriptStore.addScript(script.toScript())
                }
            }
        }
    }

    private func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

/// Row for a starter pack - ENTIRE ROW is clickable
struct StarterPackRow: View {
    let category: ScriptLibrary.ScriptCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Checkbox indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.saneTeal : Color.saneSilver)

                // Category icon
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundStyle(Color.saneCloud)
                    .frame(width: 28)

                // Category info
                VStack(alignment: .leading, spacing: 3) {
                    Text(category.rawValue)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.saneCloud)

                    Text("\(ScriptLibrary.scripts(for: category).count) scripts · \(category.description)")
                        .font(.subheadline)
                        .foregroundStyle(Color.saneSilver)
                }

                Spacer()
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.saneTeal.opacity(0.15) : Color.saneCarbon)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.saneTeal : Color.saneSmoke, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

enum OnboardingHelper {
    static var needsOnboarding: Bool {
        !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
    }
}

#Preview {
    WelcomeView()
        .environment(ScriptStore.shared)
}
