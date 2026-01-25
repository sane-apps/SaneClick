import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.sanescript.SaneScript", category: "ContentView")

struct ContentView: View {
    @Environment(ScriptStore.self) private var scriptStore
    @State private var selectedScript: Script?
    @State private var isAddingScript = false
    @State private var showDeleteConfirmation = false
    @State private var scriptToDelete: Script?
    @State private var showExecutionResult = false
    @State private var executionResult: ScriptExecutionResult?
    @State private var isAddingScriptCategory = false
    @State private var editingScriptCategory: ScriptCategory?
    @State private var showDeleteScriptCategoryConfirmation = false
    @State private var categoryToDelete: ScriptCategory?
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .navigationTitle("SaneScript")
        .toolbar {
            toolbarContent
        }
        .onReceive(NotificationCenter.default.publisher(for: ScriptExecutor.executionCompletedNotification)) { notification in
            if let result = notification.userInfo?["result"] as? ScriptExecutionResult {
                executionResult = result
                // Only show alert for failures
                if !result.success {
                    showExecutionResult = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .importScriptsRequested)) { _ in
            importScripts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportAllScriptsRequested)) { _ in
            exportAllScripts()
        }
        .alert("Script Error", isPresented: $showExecutionResult, presenting: executionResult) { _ in
            Button("OK", role: .cancel) {}
        } message: { result in
            Text("\"\(result.scriptName)\" failed:\n\(result.error ?? "Unknown error")")
        }
        .alert("Import Result", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
        .sheet(isPresented: $isAddingScript) {
            ScriptEditorView(script: nil) { newScript in
                scriptStore.addScript(newScript)
            }
        }
        .sheet(isPresented: $isAddingScriptCategory) {
            ScriptCategoryEditorView(category: nil) { newScriptCategory in
                scriptStore.addScriptCategory(newScriptCategory)
            }
        }
        .sheet(item: $editingScriptCategory) { category in
            ScriptCategoryEditorView(category: category) { updatedScriptCategory in
                scriptStore.updateScriptCategory(updatedScriptCategory)
            }
        }
        .confirmationDialog(
            "Delete ScriptCategory",
            isPresented: $showDeleteScriptCategoryConfirmation,
            presenting: categoryToDelete
        ) { category in
            Button("Delete \"\(category.name)\"", role: .destructive) {
                scriptStore.deleteScriptCategory(category)
            }
            Button("Cancel", role: .cancel) {}
        } message: { category in
            Text("Are you sure you want to delete \"\(category.name)\"? Scripts in this category will become uncategorized.")
        }
        .confirmationDialog(
            "Delete Script",
            isPresented: $showDeleteConfirmation,
            presenting: scriptToDelete
        ) { script in
            Button("Delete \"\(script.name)\"", role: .destructive) {
                scriptStore.deleteScript(script)
                if selectedScript?.id == script.id {
                    selectedScript = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { script in
            Text("Are you sure you want to delete \"\(script.name)\"? This cannot be undone.")
        }
    }

    // MARK: - Sidebar

    /// Scripts filtered by search text
    private var filteredScripts: [Script] {
        guard !searchText.isEmpty else { return scriptStore.scripts }
        return scriptStore.scripts.filter { script in
            script.name.localizedCaseInsensitiveContains(searchText) ||
            script.type.rawValue.localizedCaseInsensitiveContains(searchText) ||
            script.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Filter scripts in a specific category by search
    private func filteredScripts(in category: ScriptCategory?) -> [Script] {
        let categoryScripts = category == nil
            ? scriptStore.uncategorizedScripts
            : scriptStore.scripts(in: category)

        guard !searchText.isEmpty else { return categoryScripts }
        return categoryScripts.filter { script in
            script.name.localizedCaseInsensitiveContains(searchText) ||
            script.type.rawValue.localizedCaseInsensitiveContains(searchText) ||
            script.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var sidebar: some View {
        List(selection: $selectedScript) {
            // User-created categories
            ForEach(scriptStore.categories) { category in
                let scripts = filteredScripts(in: category)
                if !scripts.isEmpty || searchText.isEmpty {
                    Section {
                        ForEach(scripts) { script in
                            scriptRow(for: script)
                        }
                    } header: {
                        categoryHeader(for: category)
                    }
                }
            }

            // Uncategorized scripts
            let uncategorized = filteredScripts(in: nil)
            if !uncategorized.isEmpty || searchText.isEmpty {
                Section("Uncategorized") {
                    ForEach(uncategorized) { script in
                        scriptRow(for: script)
                    }
                }
            }

            // Show "no results" when searching
            if !searchText.isEmpty && filteredScripts.isEmpty {
                Text("No scripts match \"\(searchText)\"")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .searchable(text: $searchText, prompt: "Search scripts")
        .accessibilityIdentifier("scriptList")
    }

    private func scriptRow(for script: Script) -> some View {
        ScriptRow(script: script)
            .tag(script)
            .contextMenu {
                if !scriptStore.categories.isEmpty {
                    Menu("Move to ScriptCategory") {
                        Button("Uncategorized") {
                            moveScriptToScriptCategory(script, category: nil)
                        }
                        Divider()
                        ForEach(scriptStore.categories) { category in
                            Button(category.name) {
                                moveScriptToScriptCategory(script, category: category)
                            }
                        }
                    }
                    Divider()
                }
                Button("Duplicate") {
                    duplicateScript(script)
                }
                Divider()
                Button("Delete", role: .destructive) {
                    scriptToDelete = script
                    showDeleteConfirmation = true
                }
            }
    }

    private func categoryHeader(for category: ScriptCategory) -> some View {
        HStack {
            Image(systemName: category.icon)
            Text(category.name)
        }
        .contextMenu {
            Button("Edit ScriptCategory") {
                editingScriptCategory = category
            }
            Divider()
            Button("Delete ScriptCategory", role: .destructive) {
                categoryToDelete = category
                showDeleteScriptCategoryConfirmation = true
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        if let script = selectedScript {
            ScriptEditorView(script: script) { updatedScript in
                scriptStore.updateScript(updatedScript)
            }
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Select a Script")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Choose a script from the sidebar or create a new one.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button {
                isAddingScript = true
            } label: {
                Label("Add Script", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("addScriptButtonEmpty")
        }
        .padding()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    isAddingScript = true
                } label: {
                    Label("New Script", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)

                Button {
                    isAddingScriptCategory = true
                } label: {
                    Label("New Category", systemImage: "folder.badge.plus")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            } label: {
                Label("Add", systemImage: "plus")
            }
            .accessibilityIdentifier("addMenu")
            .help("Add a new script or category")
        }

        ToolbarItem(placement: .navigation) {
            Button {
                importScripts()
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("importButton")
            .help("Import scripts from a JSON file")
        }

    }

    // MARK: - Helpers

    private func duplicateScript(_ script: Script) {
        let newScript = Script(
            name: "\(script.name) Copy",
            type: script.type,
            content: script.content,
            isEnabled: script.isEnabled,
            icon: script.icon,
            appliesTo: script.appliesTo,
            fileExtensions: script.fileExtensions,
            extensionMatchMode: script.extensionMatchMode,
            categoryId: script.categoryId
        )
        scriptStore.addScript(newScript)
    }

    private func moveScriptToScriptCategory(_ script: Script, category: ScriptCategory?) {
        var updatedScript = script
        updatedScript.categoryId = category?.id
        scriptStore.updateScript(updatedScript)
    }

    // MARK: - Import/Export

    private func importScripts() {
        logger.info("importScripts() called - using NSOpenPanel")
        // Use NSOpenPanel directly (workaround for .fileImporter not working with NavigationSplitView)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Select script files to import"
        panel.prompt = "Import"

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        processImportedFiles(panel.urls)
    }

    private func processImportedFiles(_ urls: [URL]) {
        var importedCount = 0
        var skippedCount = 0

        for url in urls {
            do {
                let data = try Data(contentsOf: url)

                // Try to decode as array of scripts first
                if let scripts = try? JSONDecoder().decode([Script].self, from: data) {
                    for script in scripts {
                        // Check for duplicates by name
                        if scriptStore.scripts.contains(where: { $0.name == script.name }) {
                            skippedCount += 1
                        } else {
                            // Create new script with new ID to avoid conflicts
                            let newScript = Script(
                                name: script.name,
                                type: script.type,
                                content: script.content,
                                isEnabled: script.isEnabled,
                                icon: script.icon,
                                appliesTo: script.appliesTo,
                                fileExtensions: script.fileExtensions,
                                extensionMatchMode: script.extensionMatchMode,
                                categoryId: nil // Don't import category associations
                            )
                            scriptStore.addScript(newScript)
                            importedCount += 1
                        }
                    }
                } else if let script = try? JSONDecoder().decode(Script.self, from: data) {
                    // Single script
                    if scriptStore.scripts.contains(where: { $0.name == script.name }) {
                        skippedCount += 1
                    } else {
                        let newScript = Script(
                            name: script.name,
                            type: script.type,
                            content: script.content,
                            isEnabled: script.isEnabled,
                            icon: script.icon,
                            appliesTo: script.appliesTo,
                            fileExtensions: script.fileExtensions,
                            extensionMatchMode: script.extensionMatchMode,
                            categoryId: nil
                        )
                        scriptStore.addScript(newScript)
                        importedCount += 1
                    }
                } else {
                    throw NSError(domain: "SaneScript", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Invalid file format"
                    ])
                }
            } catch {
                importErrorMessage = "Failed to import \(url.lastPathComponent): \(error.localizedDescription)"
                showImportError = true
                return
            }
        }

        if skippedCount > 0 {
            importErrorMessage = "Imported \(importedCount) script(s). Skipped \(skippedCount) duplicate(s)."
            showImportError = true
        }
    }

    private func exportScript(_ script: Script) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(script.name).json"
        panel.message = "Export script"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(script)
            try data.write(to: url)
        } catch {
            importErrorMessage = "Failed to export: \(error.localizedDescription)"
            showImportError = true
        }
    }

    private func exportAllScripts() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "SaneScript-export.json"
        panel.message = "Export all scripts"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(scriptStore.scripts)
            try data.write(to: url)
        } catch {
            importErrorMessage = "Failed to export: \(error.localizedDescription)"
            showImportError = true
        }
    }
}

// MARK: - Script Row

struct ScriptRow: View {
    let script: Script

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: script.icon)
                .foregroundStyle(script.isEnabled ? .teal : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(script.name)
                    .font(.body)
                    .foregroundStyle(script.isEnabled ? .primary : .secondary)

                Text(script.type.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !script.isEnabled {
                Image(systemName: "pause.circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("scriptRow_\(script.id.uuidString)")
    }
}

#Preview {
    ContentView()
        .environment(ScriptStore.shared)
}
