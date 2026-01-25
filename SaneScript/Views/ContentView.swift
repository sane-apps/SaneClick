import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.sanescript.SaneScript", category: "ContentView")

/// Main view - sidebar with categories, detail with scripts
/// Mirrors SaneHosts design: organized sections, clear primary action
struct ContentView: View {
    @Environment(ScriptStore.self) private var scriptStore
    @State private var selectedCategory: ScriptLibrary.ScriptCategory? = .universal
    @State private var showLibrary = false
    @State private var showCustomScriptEditor = false
    @State private var showMoreOptions = false
    @State private var editingScript: Script?
    @State private var showDeleteConfirmation = false
    @State private var scriptToDelete: Script?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
        } detail: {
            ZStack {
                Color.saneNavy.opacity(0.3)
                    .ignoresSafeArea()
                detailView
            }
        }
        .navigationTitle("SaneClick")
        .sheet(isPresented: $showLibrary) {
            ScriptLibraryView()
                .environment(scriptStore)
        }
        .sheet(isPresented: $showCustomScriptEditor) {
            ScriptEditorView(script: nil) { newScript in
                scriptStore.addScript(newScript)
            }
        }
        .sheet(item: $editingScript) { script in
            ScriptEditorView(script: script) { updatedScript in
                scriptStore.updateScript(updatedScript)
            }
        }
        .confirmationDialog(
            "Remove Action",
            isPresented: $showDeleteConfirmation,
            presenting: scriptToDelete
        ) { script in
            Button("Remove \"\(script.name)\"", role: .destructive) {
                scriptStore.deleteScript(script)
            }
            Button("Cancel", role: .cancel) {}
        } message: { script in
            Text("Remove \"\(script.name)\" from your right-click menu?")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedCategory) {
            // Quick Actions section
            Section {
                // Primary action: Browse Library
                QuickActionRow(
                    title: "Browse Library",
                    subtitle: "50+ ready-to-use actions",
                    icon: "books.vertical.fill",
                    color: .saneTeal
                ) {
                    showLibrary = true
                }

                // More options (collapsed by default)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showMoreOptions.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .rotationEffect(.degrees(showMoreOptions ? 90 : 0))
                        Text("More Options")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.saneTeal.opacity(0.8))
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                if showMoreOptions {
                    QuickActionRow(
                        title: "Write Custom Action",
                        subtitle: "For advanced users",
                        icon: "terminal",
                        color: .orange
                    ) {
                        showCustomScriptEditor = true
                    }
                }
            } header: {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("QUICK ACTIONS")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.primary)
            }

            // Categories section
            Section {
                ForEach(ScriptLibrary.ScriptCategory.allCases, id: \.self) { category in
                    let libraryCount = ScriptLibrary.scripts(for: category).count
                    let installedScripts = scriptsForCategory(category)
                    let activeCount = installedScripts.filter { $0.isEnabled }.count

                    CategoryRow(
                        category: category,
                        totalCount: libraryCount,
                        activeCount: activeCount
                    )
                    .tag(category)
                }
            } header: {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("YOUR ACTIONS")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.primary)
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        if let category = selectedCategory {
            // Always show ALL library scripts for this category
            categoryDetail(category: category)
        } else {
            emptyState
        }
    }

    /// Get semantic color for category
    private func colorForCategory(_ category: ScriptLibrary.ScriptCategory) -> Color {
        switch category.colorName {
        case "blue": return .blue
        case "green": return Color(red: 0.13, green: 0.77, blue: 0.37)
        case "pink": return .pink
        case "purple": return .purple
        case "orange": return .orange
        default: return .blue
        }
    }

    private func categoryDetail(category: ScriptLibrary.ScriptCategory) -> some View {
        let categoryColor = colorForCategory(category)
        let libraryScripts = ScriptLibrary.scripts(for: category)
        let installedScripts = scriptsForCategory(category)
        let activeCount = installedScripts.filter { $0.isEnabled }.count
        let allEnabled = activeCount == libraryScripts.count && activeCount > 0

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Category header with semantic color
                HStack {
                    Image(systemName: category.icon)
                        .font(.title)
                        .foregroundStyle(categoryColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)

                        // Active count in green (success), total available
                        HStack(spacing: 4) {
                            Text("\(activeCount)")
                                .foregroundStyle(activeCount > 0 ? Color(red: 0.13, green: 0.77, blue: 0.37) : Color.saneSilver)
                            Text("of \(libraryScripts.count) enabled")
                                .foregroundStyle(Color.saneSilver)
                        }
                        .font(.subheadline)
                    }

                    Spacer()

                    // Enable/Disable All toggle
                    VStack(alignment: .trailing, spacing: 2) {
                        Toggle("", isOn: Binding(
                            get: { allEnabled },
                            set: { enableAll in
                                toggleAllScripts(in: category, enable: enableAll)
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .tint(categoryColor)

                        Text(allEnabled ? "All On" : "Enable All")
                            .font(.caption)
                            .foregroundStyle(Color.saneSilver)
                    }
                }
                .padding(.bottom, 8)

                // Show ALL library scripts for this category
                ForEach(libraryScripts, id: \.name) { libraryScript in
                    let installedScript = installedScripts.first { $0.name == libraryScript.name }
                    let isInstalled = installedScript != nil
                    let isEnabled = installedScript?.isEnabled ?? false

                    LibraryScriptRow(
                        libraryScript: libraryScript,
                        isInstalled: isInstalled,
                        isEnabled: isEnabled,
                        categoryColor: categoryColor,
                        onToggle: { newValue in
                            handleScriptToggle(
                                libraryScript: libraryScript,
                                installedScript: installedScript,
                                enable: newValue
                            )
                        }
                    )
                }
            }
            .padding(24)
        }
    }

    /// Handle toggle: add script if enabling and not installed, or toggle existing
    private func handleScriptToggle(libraryScript: ScriptLibrary.LibraryScript, installedScript: Script?, enable: Bool) {
        if enable {
            if let script = installedScript {
                // Already installed, just enable
                if !script.isEnabled {
                    var updated = script
                    updated.isEnabled = true
                    scriptStore.updateScript(updated)
                }
            } else {
                // Not installed, add it enabled
                let newScript = Script(
                    name: libraryScript.name,
                    type: libraryScript.type,
                    content: libraryScript.content,
                    isEnabled: true,
                    icon: libraryScript.icon,
                    appliesTo: libraryScript.appliesTo,
                    fileExtensions: libraryScript.fileExtensions
                )
                scriptStore.addScript(newScript)
            }
        } else {
            // Disabling - just disable, don't remove
            if let script = installedScript, script.isEnabled {
                var updated = script
                updated.isEnabled = false
                scriptStore.updateScript(updated)
            }
        }
    }

    /// Enable or disable all scripts in a category
    private func toggleAllScripts(in category: ScriptLibrary.ScriptCategory, enable: Bool) {
        let libraryScripts = ScriptLibrary.scripts(for: category)
        let installedScripts = scriptsForCategory(category)

        for libraryScript in libraryScripts {
            let installedScript = installedScripts.first { $0.name == libraryScript.name }
            handleScriptToggle(libraryScript: libraryScript, installedScript: installedScript, enable: enable)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 56))
                .foregroundStyle(Color.saneTeal)

            Text("Welcome to SaneClick")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add actions to your Finder right-click menu from our curated library.")
                .font(.body)
                .foregroundStyle(Color.saneSilver)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button {
                showLibrary = true
            } label: {
                Label("Browse Library", systemImage: "books.vertical.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(.saneTeal)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func scriptsForCategory(_ category: ScriptLibrary.ScriptCategory) -> [Script] {
        // Map library category to installed scripts by matching names
        let libraryScriptNames = Set(ScriptLibrary.scripts(for: category).map { $0.name })
        return scriptStore.scripts.filter { libraryScriptNames.contains($0.name) }
    }

    private func toggleScript(_ script: Script) {
        var updated = script
        updated.isEnabled.toggle()
        scriptStore.updateScript(updated)
    }
}

// MARK: - Quick Action Row

struct QuickActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: ScriptLibrary.ScriptCategory
    let totalCount: Int
    let activeCount: Int

    /// Semantic colors (from SaneApps Brand Guidelines):
    /// - Blue: Essential/primary features
    /// - Green: Safe/file management (also success state)
    /// - Pink: Creative/visual
    /// - Purple: Technical/developer
    /// - Orange: Warning/advanced (be careful)
    private var categoryColor: Color {
        switch category.colorName {
        case "blue": return .blue
        case "green": return Color(red: 0.13, green: 0.77, blue: 0.37) // Brand success green
        case "pink": return .pink
        case "purple": return .purple
        case "orange": return .orange
        default: return .blue
        }
    }

    /// Success green for active count
    private let successGreen = Color(red: 0.13, green: 0.77, blue: 0.37)

    var body: some View {
        HStack(spacing: 12) {
            // Icon always uses category's semantic color
            Image(systemName: category.icon)
                .font(.body)
                .foregroundStyle(categoryColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.body)
                    .foregroundStyle(.primary)

                // Active count in green (success state)
                Text("\(activeCount) active")
                    .font(.caption)
                    .foregroundStyle(activeCount > 0 ? successGreen : .secondary)
            }

            Spacer()

            // Count badge shows total available scripts in category
            Text("\(totalCount)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(categoryColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(categoryColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Script Row

struct ScriptRow: View {
    let script: Script
    let categoryColor: Color
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    /// Success green for enabled state (from brand guidelines)
    private let successGreen = Color(red: 0.13, green: 0.77, blue: 0.37)

    var body: some View {
        HStack(spacing: 14) {
            // Icon - green when enabled (success), gray when disabled
            Image(systemName: script.icon)
                .font(.title3)
                .foregroundStyle(script.isEnabled ? successGreen : Color.saneSilver)
                .frame(width: 36, height: 36)
                .background(script.isEnabled ? successGreen.opacity(0.15) : Color.saneSmoke)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Name and status
            VStack(alignment: .leading, spacing: 2) {
                Text(script.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(script.isEnabled ? Color.saneCloud : Color.saneSilver)

                // Show file type filter if set, otherwise show status
                if !script.fileExtensions.isEmpty {
                    Text(script.fileExtensions.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(Color.saneSilver)
                }
            }

            Spacer()

            // Toggle - green tint for success state
            Toggle("", isOn: Binding(
                get: { script.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .tint(successGreen)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.saneCarbon)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isHovered ? categoryColor.opacity(0.5) : Color.saneSmoke, lineWidth: 1)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

// MARK: - Library Script Row

/// Shows a library script with toggle - auto-adds when enabled, removes when disabled
struct LibraryScriptRow: View {
    let libraryScript: ScriptLibrary.LibraryScript
    let isInstalled: Bool
    let isEnabled: Bool
    let categoryColor: Color
    let onToggle: (Bool) -> Void  // Pass new state: true = enable (add if needed), false = disable

    @State private var isHovered = false

    /// Success green for enabled state
    private let successGreen = Color(red: 0.13, green: 0.77, blue: 0.37)

    var body: some View {
        HStack(spacing: 14) {
            // Icon - green when enabled, gray when disabled
            Image(systemName: libraryScript.icon)
                .font(.title3)
                .foregroundStyle(isEnabled ? successGreen : Color.saneSilver)
                .frame(width: 36, height: 36)
                .background(isEnabled ? successGreen.opacity(0.15) : Color.saneSmoke)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Name and description
            VStack(alignment: .leading, spacing: 2) {
                Text(libraryScript.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(isEnabled ? Color.saneCloud : Color.saneSilver)

                Text(libraryScript.description)
                    .font(.caption)
                    .foregroundStyle(Color.saneSilver)
                    .lineLimit(1)
            }

            Spacer()

            // Always show toggle - consistent UI for all scripts
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { newValue in onToggle(newValue) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .tint(successGreen)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.saneCarbon)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isHovered ? categoryColor.opacity(0.5) : Color.saneSmoke, lineWidth: 1)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(ScriptStore.shared)
}
