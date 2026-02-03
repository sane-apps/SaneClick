import SwiftUI

/// Browse and install scripts from the curated library
/// Mirrors ContentView design: categories as sections, toggle-based UI
struct ScriptLibraryView: View {
    @Environment(ScriptStore.self) private var scriptStore
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var expandedCategories: Set<ScriptLibrary.ScriptCategory> = []
    @State private var showAllSection = false  // "All" section expanded

    /// Success green for enabled state
    private let successGreen = Color(red: 0.13, green: 0.77, blue: 0.37)

    var body: some View {
        VStack(spacing: 0) {
            // Header with Enable All button
            header

            Divider()

            // Search bar
            searchBar

            Divider()

            // All categories as sections
            ScrollView {
                VStack(spacing: 16) {
                    // "All" section - shows everything flat
                    allSection

                    // Individual category sections
                    ForEach(ScriptLibrary.ScriptCategory.allCases, id: \.self) { category in
                        categorySection(category)
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color.saneNavy.opacity(0.3))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Script Library")
                    .font(.title2)
                    .fontWeight(.bold)

                let totalEnabled = enabledCount(for: nil)
                let totalAvailable = ScriptLibrary.allScripts.count
                HStack(spacing: 4) {
                    Text("\(totalEnabled)")
                        .foregroundStyle(totalEnabled > 0 ? successGreen : Color.saneSilver)
                    Text("of \(totalAvailable) enabled")
                        .foregroundStyle(Color.saneSilver)
                }
                .font(.subheadline)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.saneTeal)
        }
        .padding()
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search scripts...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.saneCarbon)
    }

    // MARK: - All Section

    private var allSection: some View {
        let allScripts = filteredAllScripts
        let totalEnabled = enabledCount(for: nil)
        let totalAvailable = ScriptLibrary.allScripts.count
        let allEnabled = totalEnabled == totalAvailable && totalAvailable > 0

        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Collapse/expand button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllSection.toggle()
                        // Collapse all categories when showing "All"
                        if showAllSection {
                            expandedCategories.removeAll()
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .rotationEffect(.degrees(showAllSection ? 90 : 0))
                            .foregroundStyle(Color.saneSilver)

                        Image(systemName: "square.grid.2x2.fill")
                            .font(.title2)
                            .foregroundStyle(Color.saneTeal)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("All Scripts")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            HStack(spacing: 4) {
                                Text("\(totalEnabled)")
                                    .foregroundStyle(totalEnabled > 0 ? successGreen : Color.saneSilver)
                                Text("of \(totalAvailable) enabled")
                                    .foregroundStyle(Color.saneSilver)
                            }
                            .font(.caption)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Enable All toggle
                VStack(alignment: .trailing, spacing: 2) {
                    Toggle("", isOn: Binding(
                        get: { allEnabled },
                        set: { enableAll in
                            toggleAllLibrary(enable: enableAll)
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .tint(Color.saneTeal)

                    Text(allEnabled ? "All On" : "Enable All")
                        .font(.caption)
                        .foregroundStyle(Color.saneSilver)
                }
            }

            // Scripts list (collapsible)
            if showAllSection && !allScripts.isEmpty {
                VStack(spacing: 8) {
                    ForEach(allScripts, id: \.name) { libraryScript in
                        let installedScript = scriptStore.scripts.first { $0.name == libraryScript.name }
                        let isEnabled = installedScript?.isEnabled ?? false
                        let categoryColor = colorForCategory(libraryScript.category)

                        LibraryScriptRow(
                            libraryScript: libraryScript,
                            isInstalled: installedScript != nil,
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
            } else if showAllSection && allScripts.isEmpty && !searchText.isEmpty {
                Text("No matching scripts")
                    .font(.subheadline)
                    .foregroundStyle(Color.saneSilver)
                    .padding(.leading, 44)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.saneCarbon)
        }
    }

    private var filteredAllScripts: [ScriptLibrary.LibraryScript] {
        if searchText.isEmpty {
            return ScriptLibrary.allScripts
        }

        return ScriptLibrary.allScripts.filter { script in
            script.name.localizedCaseInsensitiveContains(searchText) ||
            script.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Category Section

    private func categorySection(_ category: ScriptLibrary.ScriptCategory) -> some View {
        let categoryColor = colorForCategory(category)
        let libraryScripts = filteredScripts(for: category)
        let enabledInCategory = enabledCount(for: category)
        let totalInCategory = ScriptLibrary.scripts(for: category).count
        let allCategoryEnabled = enabledInCategory == totalInCategory && totalInCategory > 0
        let isExpanded = expandedCategories.contains(category)

        return VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack {
                // Collapse/expand button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedCategories.remove(category)
                        } else {
                            expandedCategories.insert(category)
                            showAllSection = false  // Collapse "All" when expanding a category
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .foregroundStyle(Color.saneSilver)

                        Image(systemName: category.icon)
                            .font(.title2)
                            .foregroundStyle(categoryColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.rawValue)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            HStack(spacing: 4) {
                                Text("\(enabledInCategory)")
                                    .foregroundStyle(enabledInCategory > 0 ? successGreen : Color.saneSilver)
                                Text("of \(totalInCategory) enabled")
                                    .foregroundStyle(Color.saneSilver)
                            }
                            .font(.caption)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Enable All toggle for this category
                VStack(alignment: .trailing, spacing: 2) {
                    Toggle("", isOn: Binding(
                        get: { allCategoryEnabled },
                        set: { enableAll in
                            toggleAllScripts(in: category, enable: enableAll)
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .tint(categoryColor)

                    Text(allCategoryEnabled ? "All On" : "Enable All")
                        .font(.caption)
                        .foregroundStyle(Color.saneSilver)
                }
            }

            // Scripts list (collapsible)
            if isExpanded && !libraryScripts.isEmpty {
                VStack(spacing: 8) {
                    ForEach(libraryScripts, id: \.name) { libraryScript in
                        let installedScript = scriptStore.scripts.first { $0.name == libraryScript.name }
                        let isEnabled = installedScript?.isEnabled ?? false

                        LibraryScriptRow(
                            libraryScript: libraryScript,
                            isInstalled: installedScript != nil,
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
            } else if isExpanded && libraryScripts.isEmpty && !searchText.isEmpty {
                Text("No matching scripts")
                    .font(.subheadline)
                    .foregroundStyle(Color.saneSilver)
                    .padding(.leading, 44)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.saneCarbon)
        }
    }

    // MARK: - Helpers

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

    private func filteredScripts(for category: ScriptLibrary.ScriptCategory) -> [ScriptLibrary.LibraryScript] {
        let categoryScripts = ScriptLibrary.scripts(for: category)

        if searchText.isEmpty {
            return categoryScripts
        }

        return categoryScripts.filter { script in
            script.name.localizedCaseInsensitiveContains(searchText) ||
            script.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func enabledCount(for category: ScriptLibrary.ScriptCategory?) -> Int {
        let libraryScriptNames: Set<String>
        if let category = category {
            libraryScriptNames = Set(ScriptLibrary.scripts(for: category).map { $0.name })
        } else {
            libraryScriptNames = Set(ScriptLibrary.allScripts.map { $0.name })
        }

        return scriptStore.scripts.filter { script in
            libraryScriptNames.contains(script.name) && script.isEnabled
        }.count
    }

    private func handleScriptToggle(libraryScript: ScriptLibrary.LibraryScript, installedScript: Script?, enable: Bool) {
        if enable {
            if let script = installedScript {
                if !script.isEnabled {
                    var updated = script
                    updated.isEnabled = true
                    scriptStore.updateScript(updated)
                }
            } else {
                let newScript = Script(
                    name: libraryScript.name,
                    type: libraryScript.type,
                    content: libraryScript.content,
                    isEnabled: true,
                    icon: libraryScript.icon,
                    appliesTo: libraryScript.appliesTo,
                    fileExtensions: libraryScript.fileExtensions,
                    extensionMatchMode: libraryScript.extensionMatchMode,
                    minSelection: libraryScript.minSelection,
                    maxSelection: libraryScript.maxSelection
                )
                scriptStore.addScript(newScript)
            }
        } else {
            if let script = installedScript, script.isEnabled {
                var updated = script
                updated.isEnabled = false
                scriptStore.updateScript(updated)
            }
        }
    }

    private func toggleAllScripts(in category: ScriptLibrary.ScriptCategory, enable: Bool) {
        for libraryScript in ScriptLibrary.scripts(for: category) {
            let installedScript = scriptStore.scripts.first { $0.name == libraryScript.name }
            handleScriptToggle(libraryScript: libraryScript, installedScript: installedScript, enable: enable)
        }
    }

    private func toggleAllLibrary(enable: Bool) {
        for libraryScript in ScriptLibrary.allScripts {
            let installedScript = scriptStore.scripts.first { $0.name == libraryScript.name }
            handleScriptToggle(libraryScript: libraryScript, installedScript: installedScript, enable: enable)
        }
    }
}

#Preview {
    ScriptLibraryView()
        .environment(ScriptStore.shared)
}
