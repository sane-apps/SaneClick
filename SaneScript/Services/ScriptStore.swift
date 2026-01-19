import Foundation
import Observation

/// Manages script configurations with file-based persistence
@Observable
@MainActor
final class ScriptStore: Sendable {
    static let shared = ScriptStore()

    private(set) var scripts: [Script] = []
    private(set) var categories: [ScriptCategory] = []

    /// Shared file location via App Group container (accessible by both app and extension)
    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "M78L6FXD48.group.com.sanescript.app")
    }

    private static var scriptsFileURL: URL {
        guard let containerURL = containerURL else {
            // Fallback to regular app support
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let saneScriptDir = appSupport.appendingPathComponent("SaneScript", isDirectory: true)
            try? FileManager.default.createDirectory(at: saneScriptDir, withIntermediateDirectories: true)
            return saneScriptDir.appendingPathComponent("scripts.json")
        }
        return containerURL.appendingPathComponent("scripts.json")
    }

    private static var categoriesFileURL: URL {
        guard let containerURL = containerURL else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let saneScriptDir = appSupport.appendingPathComponent("SaneScript", isDirectory: true)
            try? FileManager.default.createDirectory(at: saneScriptDir, withIntermediateDirectories: true)
            return saneScriptDir.appendingPathComponent("categories.json")
        }
        return containerURL.appendingPathComponent("categories.json")
    }

    private init() {
        loadCategories()
        loadScripts()
    }

    // MARK: - CRUD Operations

    func addScript(_ script: Script) {
        scripts.append(script)
        saveScripts()
        notifyExtension()
    }

    func updateScript(_ script: Script) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        scripts[index] = script
        saveScripts()
        notifyExtension()
    }

    func deleteScript(_ script: Script) {
        scripts.removeAll { $0.id == script.id }
        saveScripts()
        notifyExtension()
    }

    func moveScript(from source: IndexSet, to destination: Int) {
        scripts.move(fromOffsets: source, toOffset: destination)
        saveScripts()
        notifyExtension()
    }

    // MARK: - ScriptCategory CRUD Operations

    func addScriptCategory(_ category: ScriptCategory) {
        categories.append(category)
        saveCategories()
    }

    func updateScriptCategory(_ category: ScriptCategory) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index] = category
        saveCategories()
    }

    func deleteScriptCategory(_ category: ScriptCategory) {
        // Move scripts in this category to uncategorized
        for index in scripts.indices where scripts[index].categoryId == category.id {
            scripts[index].categoryId = nil
        }
        categories.removeAll { $0.id == category.id }
        saveCategories()
        saveScripts()
        notifyExtension()
    }

    func moveScriptCategory(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        saveCategories()
    }

    // MARK: - Persistence

    private func loadScripts() {
        let fileURL = Self.scriptsFileURL

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Script].self, from: data) else {
            // Create default scripts on first launch
            scripts = createDefaultScripts()
            saveScripts()
            return
        }
        scripts = decoded
    }

    private func saveScripts() {
        let fileURL = Self.scriptsFileURL

        guard let data = try? JSONEncoder().encode(scripts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func loadCategories() {
        let fileURL = Self.categoriesFileURL

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ScriptCategory].self, from: data) else {
            categories = []
            return
        }
        categories = decoded
    }

    private func saveCategories() {
        let fileURL = Self.categoriesFileURL

        guard let data = try? JSONEncoder().encode(categories) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func notifyExtension() {
        // Notify the Finder Sync Extension that scripts have changed
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.sanescript.scriptsChanged"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    private func createDefaultScripts() -> [Script] {
        [
            Script(
                name: "Open in Terminal",
                type: .bash,
                content: "open -a Terminal \"$@\"",
                icon: "terminal",
                appliesTo: .foldersOnly
            ),
            Script(
                name: "Copy Path",
                type: .bash,
                content: "echo -n \"$@\" | pbcopy",
                icon: "doc.on.clipboard",
                appliesTo: .allItems
            )
        ]
    }
}

// MARK: - Extension Helpers

extension ScriptStore {
    /// Get scripts that apply to a specific menu kind
    func scripts(for appliesTo: AppliesTo) -> [Script] {
        scripts.filter { $0.isEnabled && ($0.appliesTo == appliesTo || $0.appliesTo == .allItems) }
    }

    /// Get all enabled scripts
    var enabledScripts: [Script] {
        scripts.filter { $0.isEnabled }
    }

    /// Get scripts for a specific category
    func scripts(in category: ScriptCategory?) -> [Script] {
        if let category = category {
            return scripts.filter { $0.categoryId == category.id }
        } else {
            // Uncategorized scripts
            return scripts.filter { $0.categoryId == nil }
        }
    }

    /// Get scripts that are uncategorized
    var uncategorizedScripts: [Script] {
        scripts.filter { $0.categoryId == nil }
    }
}
