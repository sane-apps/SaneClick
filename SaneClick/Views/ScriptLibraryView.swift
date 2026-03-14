import SaneUI
import SwiftUI

/// Browse and install scripts from the curated library
/// Mirrors ContentView design: categories as sections, toggle-based UI
struct ScriptLibraryView: View {
    var licenseService: LicenseService
    @Environment(ScriptStore.self) private var scriptStore
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var expandedCategories: Set<ScriptLibrary.ScriptCategory> = []
    @State private var showAllSection = false // "All" section expanded
    @State private var proUpsellFeature: ProFeature?

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
                    ForEach(ScriptLibrary.availableCategories, id: \.self) { category in
                        categorySection(category)
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color.saneNavy.opacity(0.3))
        .sheet(item: $proUpsellFeature) { feature in
            ProUpsellView(feature: feature, licenseService: licenseService)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Script Library")
                    .font(.title2)
                    .fontWeight(.bold)

                let totalEnabled = enabledCount(for: nil)
                let totalAvailable = ScriptLibrary.availableAllScripts.count
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
        let totalAvailable = ScriptLibrary.availableAllScripts.count
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
            if showAllSection, !allScripts.isEmpty {
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
            } else if showAllSection, allScripts.isEmpty, !searchText.isEmpty {
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
            return ScriptLibrary.availableAllScripts
        }

        return ScriptLibrary.availableAllScripts.filter { script in
            script.name.localizedCaseInsensitiveContains(searchText) ||
                script.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Category Section

    private func categorySection(_ category: ScriptLibrary.ScriptCategory) -> some View {
        let categoryColor = colorForCategory(category)
        let libraryScripts = filteredScripts(for: category)
        let enabledInCategory = enabledCount(for: category)
        let totalInCategory = ScriptLibrary.availableScripts(for: category).count
        let allCategoryEnabled = enabledInCategory == totalInCategory && totalInCategory > 0
        let isExpanded = expandedCategories.contains(category)
        let isProCategory = category != .universal
        let isLocked = isProCategory && !licenseService.isPro

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
                            showAllSection = false // Collapse "All" when expanding a category
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
                            .foregroundStyle(isLocked ? Color.saneSilver : categoryColor)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(category.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                if isLocked {
                                    HStack(spacing: 4) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 9))
                                        Text("Pro")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundStyle(.teal)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.teal.opacity(0.15))
                                    .clipShape(Capsule())
                                }
                            }

                            if isLocked {
                                Text("Upgrade to enable")
                                    .font(.caption)
                                    .foregroundStyle(Color.saneSilver)
                            } else {
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
                }
                .buttonStyle(.plain)

                Spacer()

                if isLocked {
                    // Unlock CTA for Pro categories
                    Button {
                        proUpsellFeature = proFeatureForCategory(category)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                            Text("Unlock")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.teal)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
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
            }

            // Scripts list (collapsible) — always show for free categories, Pro shows teaser
            if isExpanded, !libraryScripts.isEmpty {
                if isLocked {
                    // Show a teaser with blur and unlock prompt
                    ZStack(alignment: .center) {
                        VStack(spacing: 8) {
                            ForEach(libraryScripts.prefix(3), id: \.name) { libraryScript in
                                HStack(spacing: 14) {
                                    Image(systemName: libraryScript.icon)
                                        .font(.title3)
                                        .foregroundStyle(Color.saneSilver)
                                        .frame(width: 36, height: 36)
                                        .background(Color.saneSmoke)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Text(libraryScript.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.saneSilver)

                                    Spacer()
                                }
                                .padding(14)
                                .background { RoundedRectangle(cornerRadius: 12).fill(Color.saneCarbon) }
                            }
                        }
                        .blur(radius: 3)
                        .allowsHitTesting(false)

                        Button {
                            proUpsellFeature = proFeatureForCategory(category)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 13))
                                Text("Unlock \(totalInCategory) scripts")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                    }
                } else {
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
                }
            } else if isExpanded, libraryScripts.isEmpty, !searchText.isEmpty {
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
        case "blue": .blue
        case "green": Color(red: 0.13, green: 0.77, blue: 0.37)
        case "pink": .pink
        case "purple": .teal
        case "orange": .orange
        default: .blue
        }
    }

    private func filteredScripts(for category: ScriptLibrary.ScriptCategory) -> [ScriptLibrary.LibraryScript] {
        let categoryScripts = ScriptLibrary.availableScripts(for: category)

        if searchText.isEmpty {
            return categoryScripts
        }

        return categoryScripts.filter { script in
            script.name.localizedCaseInsensitiveContains(searchText) ||
                script.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func enabledCount(for category: ScriptLibrary.ScriptCategory?) -> Int {
        let libraryScriptNames: Set<String> = if let category {
            Set(ScriptLibrary.availableScripts(for: category).map(\.name))
        } else {
            Set(ScriptLibrary.availableAllScripts.map(\.name))
        }

        return scriptStore.scripts.filter { script in
            libraryScriptNames.contains(script.name) && script.isEnabled
        }.count
    }

    private func handleScriptToggle(libraryScript: ScriptLibrary.LibraryScript, installedScript: Script?, enable: Bool) {
        if enable {
            // Gate non-Essentials scripts behind Pro
            if libraryScript.category != .universal, !licenseService.isPro {
                proUpsellFeature = proFeatureForCategory(libraryScript.category)
                return
            }

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
        // Gate enabling Pro categories behind Pro
        if enable, category != .universal, !licenseService.isPro {
            proUpsellFeature = proFeatureForCategory(category)
            return
        }
        for libraryScript in ScriptLibrary.availableScripts(for: category) {
            let installedScript = scriptStore.scripts.first { $0.name == libraryScript.name }
            handleScriptToggle(libraryScript: libraryScript, installedScript: installedScript, enable: enable)
        }
    }

    private func toggleAllLibrary(enable: Bool) {
        // When enabling all — only enable Essentials for free users
        if enable, !licenseService.isPro {
            for libraryScript in ScriptLibrary.scripts(for: .universal) {
                let installedScript = scriptStore.scripts.first { $0.name == libraryScript.name }
                handleScriptToggle(libraryScript: libraryScript, installedScript: installedScript, enable: enable)
            }
            proUpsellFeature = .codingScripts
            return
        }
        for libraryScript in ScriptLibrary.availableAllScripts {
            let installedScript = scriptStore.scripts.first { $0.name == libraryScript.name }
            handleScriptToggle(libraryScript: libraryScript, installedScript: installedScript, enable: enable)
        }
    }

    private func proFeatureForCategory(_ category: ScriptLibrary.ScriptCategory) -> ProFeature {
        switch category {
        case .developer: .codingScripts
        case .designer: .imageScripts
        case .powerUser: .advancedScripts
        case .organization: .organizationScripts
        case .universal: .codingScripts // Fallback
        }
    }
}

#Preview {
    ScriptLibraryView(licenseService: LicenseService(
        appName: "SaneClick",
        checkoutURL: LicenseService.directCheckoutURL(appSlug: "saneclick")
    ))
    .environment(ScriptStore.shared)
}
