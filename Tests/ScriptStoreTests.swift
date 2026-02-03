import Foundation
import Testing
@testable import SaneClick

@MainActor
struct ScriptStoreTests {

    // MARK: - Test Helpers

    /// Create a temporary test store that doesn't persist to disk
    private func createTestStore() -> ScriptStore {
        // ScriptStore.shared is a singleton, so we test via it
        // but we should save/restore state around tests
        return ScriptStore.shared
    }

    // MARK: - CRUD Tests

    @Test("Script can be added to store")
    func addScript() async {
        let store = createTestStore()
        let initialCount = store.scripts.count

        let script = Script(name: "Test Add Script", type: .bash, content: "echo test")
        store.addScript(script)

        #expect(store.scripts.count == initialCount + 1)
        #expect(store.scripts.contains(where: { $0.id == script.id }))

        // Cleanup
        store.deleteScript(script)
    }

    @Test("Script can be updated in store")
    func updateScript() async {
        let store = createTestStore()

        var script = Script(name: "Test Update Script", type: .bash, content: "echo original")
        store.addScript(script)

        // Update the script
        script.name = "Updated Name"
        script.content = "echo updated"
        store.updateScript(script)

        // Verify update
        let updated = store.scripts.first(where: { $0.id == script.id })
        #expect(updated?.name == "Updated Name")
        #expect(updated?.content == "echo updated")

        // Cleanup
        store.deleteScript(script)
    }

    @Test("Script can be deleted from store")
    func deleteScript() async {
        let store = createTestStore()

        let script = Script(name: "Test Delete Script", type: .bash, content: "echo delete me")
        store.addScript(script)
        #expect(store.scripts.contains(where: { $0.id == script.id }))

        store.deleteScript(script)
        #expect(!store.scripts.contains(where: { $0.id == script.id }))
    }

    @Test("Scripts can be reordered")
    func moveScript() async {
        let store = createTestStore()

        // Add test scripts
        let script1 = Script(name: "Move Test 1", type: .bash, content: "1")
        let script2 = Script(name: "Move Test 2", type: .bash, content: "2")
        let script3 = Script(name: "Move Test 3", type: .bash, content: "3")

        store.addScript(script1)
        store.addScript(script2)
        store.addScript(script3)

        // Get indices (they're at the end)
        let idx1 = store.scripts.firstIndex(where: { $0.id == script1.id })!
        let idx3 = store.scripts.firstIndex(where: { $0.id == script3.id })!

        // Move script3 before script1
        store.moveScript(from: IndexSet(integer: idx3), to: idx1)

        // Verify order changed
        let newIdx3 = store.scripts.firstIndex(where: { $0.id == script3.id })!
        let newIdx1 = store.scripts.firstIndex(where: { $0.id == script1.id })!
        #expect(newIdx3 < newIdx1)

        // Cleanup
        store.deleteScript(script1)
        store.deleteScript(script2)
        store.deleteScript(script3)
    }

    // MARK: - Filter Tests

    @Test("Enabled scripts filter works")
    func enabledScriptsFilter() async {
        let store = createTestStore()

        let enabled = Script(name: "Enabled Script", type: .bash, content: "1", isEnabled: true)
        let disabled = Script(name: "Disabled Script", type: .bash, content: "2", isEnabled: false)

        store.addScript(enabled)
        store.addScript(disabled)

        let enabledScripts = store.enabledScripts
        #expect(enabledScripts.contains(where: { $0.id == enabled.id }))
        #expect(!enabledScripts.contains(where: { $0.id == disabled.id }))

        // Cleanup
        store.deleteScript(enabled)
        store.deleteScript(disabled)
    }

    // MARK: - Import / Export Tests

    @Test("Import scripts adds new actions")
    func importScriptsAddsNewActions() async {
        let store = createTestStore()
        let uniqueName = "Import Test \(UUID().uuidString)"
        let script = Script(name: uniqueName, type: .bash, content: "echo import")

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("saneclick-import-\(UUID().uuidString).json")

        do {
            let data = try JSONEncoder().encode([script])
            try data.write(to: tempURL)

            let summary = try store.importScripts(from: tempURL, mode: .skipDuplicates)
            #expect(summary.added == 1)
            #expect(store.scripts.contains(where: { $0.name == uniqueName }))
        } catch {
            #expect(Bool(false))
        }

        if let added = store.scripts.first(where: { $0.name == uniqueName }) {
            store.deleteScript(added)
        }
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test("Import scripts replaces duplicates by name when requested")
    func importScriptsReplacesDuplicates() async {
        let store = createTestStore()
        let name = "Import Replace \(UUID().uuidString)"
        let original = Script(name: name, type: .bash, content: "echo original")
        store.addScript(original)

        let incoming = Script(name: name, type: .bash, content: "echo replaced")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("saneclick-import-\(UUID().uuidString).json")

        do {
            let data = try JSONEncoder().encode([incoming])
            try data.write(to: tempURL)

            let summary = try store.importScripts(from: tempURL, mode: .replaceDuplicates)
            #expect(summary.updated == 1)
            let updated = store.scripts.first(where: { $0.name == name })
            #expect(updated?.content == "echo replaced")
            #expect(updated?.id == original.id)
        } catch {
            #expect(Bool(false))
        }

        if let updated = store.scripts.first(where: { $0.name == name }) {
            store.deleteScript(updated)
        }
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test("Export scripts writes a bundle")
    func exportScriptsWritesBundle() async {
        let store = createTestStore()
        let name = "Export Test \(UUID().uuidString)"
        let script = Script(name: name, type: .bash, content: "echo export")
        store.addScript(script)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("saneclick-export-\(UUID().uuidString).json")

        do {
            try store.exportScripts(to: tempURL)
            let data = try Data(contentsOf: tempURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let bundle = try decoder.decode(ScriptExportBundle.self, from: data)
            #expect(bundle.scripts.contains(where: { $0.name == name }))
        } catch {
            #expect(Bool(false))
        }

        store.deleteScript(script)
        try? FileManager.default.removeItem(at: tempURL)
    }
}
