import os.log
import SaneUI
import SwiftUI

private let logger = Logger(subsystem: "com.saneclick.SaneClick", category: "ContentView")

/// Main view - sidebar with categories, detail with scripts
/// Mirrors SaneHosts design: organized sections, clear primary action
struct ContentView: View {
    var licenseService: LicenseService
    @Environment(ScriptStore.self) private var scriptStore
    @Environment(MonitoredFolderService.self) private var monitoredFolderService
    @State private var selectedCategory: ScriptLibrary.ScriptCategory? = .universal
    @State private var showLibrary = false
    @State private var showCustomScriptEditor = false
    @State private var showMoreOptions = false
    @State private var showImportExport = false
    @State private var importExportMode: ImportExportView.Mode = .importScripts
    @State private var editingScript: Script?
    @State private var showDeleteConfirmation = false
    @State private var scriptToDelete: Script?
    @State private var proUpsellFeature: ProFeature?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
        } detail: {
            detailBackground
        }
        .navigationTitle("SaneClick")
        .sheet(isPresented: $showLibrary) {
            ScriptLibraryView(licenseService: licenseService)
                .environment(scriptStore)
        }
        .sheet(isPresented: $showCustomScriptEditor) {
            ScriptEditorView(script: nil) { newScript in
                scriptStore.addScript(newScript)
            }
        }
        .sheet(isPresented: $showImportExport) {
            ImportExportView(mode: $importExportMode, licenseService: licenseService)
                .environment(scriptStore)
        }
        .sheet(item: $editingScript) { script in
            ScriptEditorView(script: script) { updatedScript in
                scriptStore.updateScript(updatedScript)
            }
        }
        .sheet(item: $proUpsellFeature) { feature in
            ProUpsellView(feature: feature, licenseService: licenseService)
                .preferredColorScheme(.dark)
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
        .onReceive(NotificationCenter.default.publisher(for: .importScriptsRequested)) { _ in
            if licenseService.isPro {
                importExportMode = .importScripts
                showImportExport = true
            } else {
                proUpsellFeature = .importExport
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportAllScriptsRequested)) { _ in
            if licenseService.isPro {
                importExportMode = .exportScripts
                showImportExport = true
            } else {
                proUpsellFeature = .importExport
            }
        }
    }

    private var detailBackground: some View {
        ZStack {
            Color.saneNavy.opacity(0.3)
                .ignoresSafeArea()
            detailView
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
                    subtitle: librarySubtitle,
                    icon: "books.vertical.fill",
                    color: .saneTeal
                ) {
                    showLibrary = true
                }

                #if APP_STORE
                    if !licenseService.isPro {
                        QuickActionRow(
                            title: "Unlock Pro",
                            subtitle: "Get 9 more built-in file actions",
                            icon: "lock.open.fill",
                            color: .teal
                        ) {
                            proUpsellFeature = .organizationScripts
                        }
                    }

                    QuickActionRow(
                        title: "Manage Folders",
                        subtitle: monitoredFolderSubtitle,
                        icon: "folder.badge.gearshape",
                        color: .green
                    ) {
                        openSettingsWindow()
                    }
                #endif

                // More options (collapsed by default)
                #if !APP_STORE
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
                        // Custom Script Editor — Pro feature
                        QuickActionRow(
                            title: "Write Custom Action",
                            subtitle: licenseService.isPro ? "For advanced users" : "Pro — create your own scripts",
                            icon: "terminal",
                            color: .orange,
                            isLocked: !licenseService.isPro
                        ) {
                            if licenseService.isPro {
                                showCustomScriptEditor = true
                            } else {
                                proUpsellFeature = .scriptEditor
                            }
                        }

                        // Import / Export — Pro feature
                        QuickActionRow(
                            title: "Import / Export",
                            subtitle: licenseService.isPro ? "Move actions between Macs" : "Pro — backup & share scripts",
                            icon: "square.and.arrow.up.on.square",
                            color: .saneTeal,
                            isLocked: !licenseService.isPro
                        ) {
                            if licenseService.isPro {
                                importExportMode = .importScripts
                                showImportExport = true
                            } else {
                                proUpsellFeature = .importExport
                            }
                        }
                    }
                #endif
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
                ForEach(ScriptLibrary.availableCategories, id: \.self) { category in
                    let libraryCount = ScriptLibrary.availableScripts(for: category).count
                    let installedScripts = scriptsForCategory(category)
                    let activeCount = installedScripts.filter(\.isEnabled).count
                    let isProCategory = category != .universal

                    CategoryRow(
                        category: category,
                        totalCount: libraryCount,
                        activeCount: activeCount,
                        isLocked: isProCategory && !licenseService.isPro
                    )
                    .padding(.top, category == .universal ? 7 : 0)
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
        .scrollContentBackground(.hidden)
        .background(Color.saneNavy.opacity(0.3))
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
        case "blue": .blue
        case "green": Color(red: 0.13, green: 0.77, blue: 0.37)
        case "pink": .pink
        case "purple": .teal
        case "orange": .orange
        default: .blue
        }
    }

    private func categoryDetail(category: ScriptLibrary.ScriptCategory) -> some View {
        let categoryColor = colorForCategory(category)
        let libraryScripts = ScriptLibrary.availableScripts(for: category)
        let installedScripts = scriptsForCategory(category)
        let activeCount = installedScripts.filter(\.isEnabled).count
        let allEnabled = activeCount == libraryScripts.count && activeCount > 0
        let isProCategory = category != .universal
        let isLocked = isProCategory && !licenseService.isPro

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Category header with semantic color
                HStack {
                    Image(systemName: category.icon)
                        .font(.title)
                        .foregroundStyle(categoryColor)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(category.rawValue)
                                .font(.title2)
                                .fontWeight(.bold)

                            if isLocked {
                                proBadge
                            }
                        }

                        // Active count in green (success), total available
                        HStack(spacing: 4) {
                            if isLocked {
                                Text("\(libraryScripts.count) scripts included with Pro")
                                    .foregroundStyle(Color.saneSilver)
                            } else {
                                Text("\(activeCount)")
                                    .foregroundStyle(activeCount > 0 ? Color(red: 0.13, green: 0.77, blue: 0.37) : Color.saneSilver)
                                Text("of \(libraryScripts.count) enabled")
                                    .foregroundStyle(Color.saneSilver)
                            }
                        }
                        .font(.subheadline)
                    }

                    Spacer()

                    if isLocked {
                        // Unlock button for Pro categories
                        Button {
                            proUpsellFeature = proFeatureForCategory(category)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                Text("Unlock Pro")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.teal)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
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
                }
                .padding(.bottom, 8)

                #if APP_STORE
                    if monitoredFolderService.monitoredFolderCount == 0 {
                        monitoredFoldersNotice
                    }
                #endif

                if isLocked {
                    // Locked state — show the actual scripts with clear Pro tagging
                    lockedCategoryOverlay(category: category, color: categoryColor)
                } else {
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
            }
            .padding(24)
        }
    }

    /// Show the actual scripts in Pro categories so users can see what Pro includes.
    private func lockedCategoryOverlay(category: ScriptLibrary.ScriptCategory, color _: Color) -> some View {
        let libraryScripts = ScriptLibrary.availableScripts(for: category)

        return VStack(spacing: 8) {
            ForEach(libraryScripts, id: \.name) { libraryScript in
                LibraryScriptRow(
                    libraryScript: libraryScript,
                    isInstalled: false,
                    isEnabled: false,
                    categoryColor: colorForCategory(category),
                    isLocked: true,
                    onToggle: { _ in },
                    onLockedTap: {
                        proUpsellFeature = proFeatureForCategory(category)
                    }
                )
            }

            HStack {
                Text("\(libraryScripts.count) scripts included with Pro")
                    .font(.subheadline)
                    .foregroundStyle(Color.saneSilver)

                Spacer()

                Button {
                    proUpsellFeature = proFeatureForCategory(category)
                } label: {
                    Label("Unlock Pro", systemImage: "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
            }
            .padding(.top, 8)
        }
    }

    /// Map a script category to its corresponding ProFeature for upsell.
    private func proFeatureForCategory(_ category: ScriptLibrary.ScriptCategory) -> ProFeature {
        switch category {
        case .developer: .codingScripts
        case .designer: .imageScripts
        case .powerUser: .advancedScripts
        case .organization: .organizationScripts
        case .universal: .codingScripts // Fallback (universal is free, shouldn't reach here)
        }
    }

    /// Small Pro lock badge used inline.
    private var proBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
            Text("Pro")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.teal)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.teal.opacity(0.15))
        .clipShape(Capsule())
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
        let libraryScripts = ScriptLibrary.availableScripts(for: category)
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

            Text(emptyStateBody)
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

            #if APP_STORE
                if !licenseService.isPro {
                    Button {
                        proUpsellFeature = .organizationScripts
                    } label: {
                        Label("Unlock Pro", systemImage: "lock.open.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)
                    .tint(.teal)
                    .controlSize(.large)
                }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func scriptsForCategory(_ category: ScriptLibrary.ScriptCategory) -> [Script] {
        // Map library category to installed scripts by matching names
        let libraryScriptNames = Set(ScriptLibrary.availableScripts(for: category).map(\.name))
        return scriptStore.scripts.filter { libraryScriptNames.contains($0.name) }
    }

    private var librarySubtitle: String {
        #if APP_STORE
            "\(ScriptLibrary.availableAllScripts.count) built-in Finder actions"
        #else
            "50+ ready-to-use actions"
        #endif
    }

    private var monitoredFolderSubtitle: String {
        let count = monitoredFolderService.monitoredFolderCount
        return count == 0 ? "Choose where SaneClick appears in Finder" : "\(count) monitored folder\(count == 1 ? "" : "s")"
    }

    private var emptyStateBody: String {
        #if APP_STORE
            "Choose built-in actions from the library, then add monitored folders in Settings so they appear in Finder."
        #else
            "Add actions to your Finder right-click menu from our curated library."
        #endif
    }

    #if APP_STORE
        private var monitoredFoldersNotice: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add at least one monitored folder in Settings before testing actions in Finder.")
                    .font(.subheadline)
                    .foregroundStyle(.white)

                Button("Open Settings") {
                    openSettingsWindow()
                }
                .buttonStyle(.borderedProminent)
                .tint(.saneTeal)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.saneCarbon))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.saneSmoke, lineWidth: 1))
        }
    #endif

    private func openSettingsWindow() {
        SettingsActionStorage.shared.showSettings()
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
    var isLocked: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isLocked ? Color.saneSilver : color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                if isLocked {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                        Text("Pro")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.teal)
                }
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
    var isLocked: Bool = false

    /// Semantic colors (from SaneApps Brand Guidelines):
    /// - Blue: Essential/primary features
    /// - Green: Safe/file management (also success state)
    /// - Pink: Creative/visual
    /// - Teal: Technical/developer
    /// - Orange: Warning/advanced (be careful)
    private var categoryColor: Color {
        switch category.colorName {
        case "blue": .blue
        case "green": Color(red: 0.13, green: 0.77, blue: 0.37) // Brand success green
        case "pink": .pink
        case "purple": .teal
        case "orange": .orange
        default: .blue
        }
    }

    /// Success green for active count
    private let successGreen = Color(red: 0.13, green: 0.77, blue: 0.37)

    var body: some View {
        HStack(spacing: 12) {
            // Icon uses category color for free, muted for locked
            Image(systemName: category.icon)
                .font(.body)
                .foregroundStyle(isLocked ? Color.saneSilver : categoryColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.body)
                    .foregroundStyle(.primary)

                if isLocked {
                    Text("Pro")
                        .font(.caption)
                        .foregroundStyle(.teal)
                } else {
                    // Active count in green (success state)
                    Text("\(activeCount) active")
                        .font(.caption)
                        .foregroundStyle(activeCount > 0 ? successGreen : .white.opacity(0.9))
                }
            }

            Spacer()

            if isLocked {
                // Lock badge for Pro categories
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Text("Pro")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.teal)
            } else {
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
    var isLocked: Bool = false
    let onToggle: (Bool) -> Void // Pass new state: true = enable (add if needed), false = disable
    var onLockedTap: (() -> Void)?

    @State private var isHovered = false

    /// Success green for enabled state
    private let successGreen = Color(red: 0.13, green: 0.77, blue: 0.37)

    var body: some View {
        let rowContent = HStack(spacing: 14) {
            // Icon - keep script identity visible for locked Pro rows
            Image(systemName: libraryScript.icon)
                .font(.title3)
                .foregroundStyle(isLocked ? categoryColor : (isEnabled ? successGreen : Color.saneSilver))
                .frame(width: 36, height: 36)
                .background(isLocked ? categoryColor.opacity(0.15) : (isEnabled ? successGreen.opacity(0.15) : Color.saneSmoke))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Name and description
            VStack(alignment: .leading, spacing: 2) {
                Text(libraryScript.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(isLocked ? .primary : (isEnabled ? Color.saneCloud : Color.saneSilver))

                Text(libraryScript.description)
                    .font(.caption)
                    .foregroundStyle(Color.saneSilver)
                    .lineLimit(1)
            }

            Spacer()

            if isLocked {
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                    Text("Pro")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.teal)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.teal.opacity(0.15))
                .clipShape(Capsule())
            } else {
                // Always show toggle - consistent UI for all scripts
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in onToggle(newValue) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(successGreen)
            }
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

        return Group {
            if isLocked, let onLockedTap {
                Button(action: onLockedTap) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(isLocked ? .isButton : [])
        .accessibilityHint(isLocked ? "Shows what is included with Pro" : "")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    ContentView(licenseService: contentPreviewLicenseService())
    .environment(ScriptStore.shared)
    .environment(MonitoredFolderService.shared)
}

@MainActor
private func contentPreviewLicenseService() -> LicenseService {
    #if APP_STORE
        LicenseService(
            appName: "SaneClick",
            purchaseBackend: .appStore(productID: "com.saneclick.app.pro.unlock.v3")
        )
    #else
        LicenseService(
            appName: "SaneClick",
            checkoutURL: LicenseService.directCheckoutURL(appSlug: "saneclick"),
            directCopy: LicenseService.DirectCopy.saneClick
        )
    #endif
}
