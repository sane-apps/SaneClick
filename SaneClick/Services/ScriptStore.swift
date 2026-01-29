import Foundation
import Observation
import os.log

private let storeLogger = Logger(subsystem: "com.saneclick.SaneClick", category: "ScriptStore")

/// Manages script configurations with file-based persistence
@Observable
@MainActor
final class ScriptStore: Sendable {
    static let shared = ScriptStore()

    private(set) var scripts: [Script] = []
    private(set) var categories: [ScriptCategory] = []

    /// Whether there was an error loading data (shown in UI)
    private(set) var loadError: String?

    /// Shared file location via App Group container (accessible by both app and extension)
    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "M78L6FXD48.group.com.saneclick.app")
    }

    private static var scriptsFileURL: URL {
        guard let containerURL = containerURL else {
            // Fallback to regular app support
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let saneClickDir = appSupport.appendingPathComponent("SaneClick", isDirectory: true)
            try? FileManager.default.createDirectory(at: saneClickDir, withIntermediateDirectories: true)
            return saneClickDir.appendingPathComponent("scripts.json")
        }
        return containerURL.appendingPathComponent("scripts.json")
    }

    private static var categoriesFileURL: URL {
        guard let containerURL = containerURL else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let saneClickDir = appSupport.appendingPathComponent("SaneClick", isDirectory: true)
            try? FileManager.default.createDirectory(at: saneClickDir, withIntermediateDirectories: true)
            return saneClickDir.appendingPathComponent("categories.json")
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

        // First launch - no file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            storeLogger.info("No scripts file found, creating defaults")
            scripts = createDefaultScripts()
            saveScripts()
            return
        }

        // Try to read the file
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            storeLogger.error("Failed to read scripts file: \(error.localizedDescription)")
            loadError = "Could not read scripts file: \(error.localizedDescription)"
            scripts = []  // Don't overwrite with defaults - preserve broken file for recovery
            return
        }

        // Try to decode
        do {
            scripts = try JSONDecoder().decode([Script].self, from: data)
            loadError = nil
            storeLogger.info("Loaded \(self.scripts.count) scripts")
        } catch {
            storeLogger.error("Failed to decode scripts: \(error.localizedDescription)")
            // Save corrupted file for recovery
            let backupURL = fileURL.deletingPathExtension().appendingPathExtension("corrupted.json")
            try? FileManager.default.removeItem(at: backupURL)  // Remove old backup
            try? FileManager.default.copyItem(at: fileURL, to: backupURL)
            loadError = "Scripts file corrupted. Backup saved to: \(backupURL.lastPathComponent)"
            scripts = []  // Don't overwrite - let user decide
        }
    }

    private func saveScripts() {
        let fileURL = Self.scriptsFileURL

        // Encode data first - fail fast if encoding fails
        let data: Data
        do {
            data = try JSONEncoder().encode(scripts)
        } catch {
            storeLogger.error("Failed to encode scripts: \(error.localizedDescription)")
            return
        }

        // Create backup of existing file before overwriting
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let backupURL = fileURL.deletingPathExtension().appendingPathExtension("backup.json")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: fileURL, to: backupURL)
        }

        // Write atomically
        do {
            try data.write(to: fileURL, options: .atomic)
            storeLogger.info("Saved \(self.scripts.count) scripts")
        } catch {
            storeLogger.error("CRITICAL: Failed to save scripts: \(error.localizedDescription)")
            // Consider: restore from backup? For now, log the error
            // The user's data is safe in the backup file
        }
    }

    private func loadCategories() {
        let fileURL = Self.categoriesFileURL

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            categories = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            categories = try JSONDecoder().decode([ScriptCategory].self, from: data)
            storeLogger.info("Loaded \(self.categories.count) categories")
        } catch {
            storeLogger.error("Failed to load categories: \(error.localizedDescription)")
            categories = []
        }
    }

    private func saveCategories() {
        let fileURL = Self.categoriesFileURL

        let data: Data
        do {
            data = try JSONEncoder().encode(categories)
        } catch {
            storeLogger.error("Failed to encode categories: \(error.localizedDescription)")
            return
        }

        // Backup existing file
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let backupURL = fileURL.deletingPathExtension().appendingPathExtension("backup.json")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: fileURL, to: backupURL)
        }

        do {
            try data.write(to: fileURL, options: .atomic)
            storeLogger.info("Saved \(self.categories.count) categories")
        } catch {
            storeLogger.error("Failed to save categories: \(error.localizedDescription)")
        }
    }

    private func notifyExtension() {
        // Notify the Finder Sync Extension that scripts have changed
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.saneclick.scriptsChanged"),
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
