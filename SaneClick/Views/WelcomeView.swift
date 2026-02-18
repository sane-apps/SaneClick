import SwiftUI

/// First-run welcome view with option to install starter scripts
struct WelcomeView: View {
    @Environment(ScriptStore.self) private var scriptStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0
    @State private var selectedPacks: Set<ScriptLibrary.ScriptCategory> = [.universal]

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            Group {
                switch currentPage {
                case 0:
                    scriptsPage
                case 1:
                    SanePromisePage(compact: true)
                default:
                    scriptsPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0 ..< 2) { index in
                    Circle()
                        .fill(currentPage == index ? Color.saneTeal : Color.saneSilver.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 12)

            // Bottom Controls
            HStack {
                if currentPage == 0 {
                    Button("Skip for Now") {
                        markOnboardingComplete()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Spacer()

                    Button("Install \(selectedScriptCount) Scripts") {
                        installSelectedPacks()
                        withAnimation { currentPage = 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(selectedPacks.isEmpty)
                } else {
                    Spacer()
                    Button("Get Started") {
                        markOnboardingComplete()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 440, height: 660)
    }

    private var scriptsPage: some View {
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

            Text("You can add more anytime from the app")
                .font(.subheadline)
                .foregroundStyle(Color.saneSilver)
        }
        .padding(24)
    }

    private var selectedScriptCount: Int {
        selectedPacks.reduce(0) { $0 + ScriptLibrary.scripts(for: $1).count }
    }

    private func installSelectedPacks() {
        let existingNames = Set(scriptStore.scripts.map(\.name))
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

// MARK: - Sane Promise (Brand Philosophy)

struct SanePromisePage: View {
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 16 : 24) {
            Text("Our Sane Philosophy")
                .font(.system(size: compact ? 24 : 32, weight: .bold))

            VStack(spacing: 8) {
                Text("\"For God has not given us a spirit of fear,")
                    .font(.system(size: compact ? 14 : 17))
                    .italic()
                Text("but of power and of love and of a sound mind.\"")
                    .font(.system(size: compact ? 14 : 17))
                    .italic()
                Text("— 2 Timothy 1:7")
                    .font(.system(size: compact ? 13 : 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.top, 4)
            }

            if compact {
                VStack(spacing: 12) {
                    pillarCards
                }
            } else {
                HStack(spacing: 20) {
                    pillarCards
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .padding(compact ? 20 : 32)
    }

    @ViewBuilder
    private var pillarCards: some View {
        SanePillarCard(
            icon: "bolt.fill",
            color: .yellow,
            title: "Power",
            description: "Your data stays on your device. No cloud, no tracking."
        )

        SanePillarCard(
            icon: "heart.fill",
            color: .pink,
            title: "Love",
            description: "Built to serve you. No dark patterns or manipulation."
        )

        SanePillarCard(
            icon: "brain.head.profile",
            color: .purple,
            title: "Sound Mind",
            description: "Calm, focused design. No clutter or anxiety."
        )
    }
}

private struct SanePillarCard: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 18, weight: .semibold))

            Text(description)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(Color.primary.opacity(0.08))
        .cornerRadius(12)
    }
}

// MARK: - Onboarding Helper

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
