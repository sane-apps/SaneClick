import Foundation
import Testing
@testable import SaneClick

struct CategoryTests {

    // MARK: - ScriptCategory Model Tests

    @Test("ScriptCategory initializes with defaults")
    func categoryInitializesWithDefaults() {
        let category = ScriptCategory(name: "Test Category")

        #expect(category.name == "Test Category")
        #expect(category.icon == "folder")
    }

    @Test("ScriptCategory initializes with custom icon")
    func categoryInitializesWithCustomIcon() {
        let category = ScriptCategory(name: "Dev Tools", icon: "hammer")

        #expect(category.name == "Dev Tools")
        #expect(category.icon == "hammer")
    }

    @Test("ScriptCategory is Codable")
    func categoryIsCodable() throws {
        let original = ScriptCategory(
            name: "Image Scripts",
            icon: "photo"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScriptCategory.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.icon == original.icon)
    }

    @Test("ScriptCategory equality works")
    func categoryEquality() {
        let category1 = ScriptCategory(name: "Test")
        let category2 = ScriptCategory(id: category1.id, name: "Test")
        let category3 = ScriptCategory(name: "Test")

        #expect(category1 == category2)
        #expect(category1 != category3) // Different IDs
    }

    @Test("ScriptCategory.uncategorized has fixed UUID")
    func uncategorizedHasFixedUUID() {
        let uncategorized = ScriptCategory.uncategorized

        #expect(uncategorized.id == UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(uncategorized.name == "Uncategorized")
        #expect(uncategorized.icon == "tray")
    }
}

@MainActor
struct CategoryStoreTests {

    // MARK: - Test Helpers

    private func createTestStore() -> ScriptStore {
        return ScriptStore.shared
    }

    // MARK: - Category CRUD Tests

    @Test("Category can be added to store")
    func addCategory() async {
        let store = createTestStore()
        let initialCount = store.categories.count

        let category = ScriptCategory(name: "Test Add Category")
        store.addScriptCategory(category)

        #expect(store.categories.count == initialCount + 1)
        #expect(store.categories.contains(where: { $0.id == category.id }))

        // Cleanup
        store.deleteScriptCategory(category)
    }

    @Test("Category can be updated in store")
    func updateCategory() async {
        let store = createTestStore()

        var category = ScriptCategory(name: "Test Update Category")
        store.addScriptCategory(category)

        // Update the category
        category.name = "Updated Category Name"
        category.icon = "star"
        store.updateScriptCategory(category)

        // Verify update
        let updated = store.categories.first(where: { $0.id == category.id })
        #expect(updated?.name == "Updated Category Name")
        #expect(updated?.icon == "star")

        // Cleanup
        store.deleteScriptCategory(category)
    }

    @Test("Category can be deleted from store")
    func deleteCategory() async {
        let store = createTestStore()

        let category = ScriptCategory(name: "Test Delete Category")
        store.addScriptCategory(category)
        #expect(store.categories.contains(where: { $0.id == category.id }))

        store.deleteScriptCategory(category)
        #expect(!store.categories.contains(where: { $0.id == category.id }))
    }

    @Test("Deleting category moves scripts to uncategorized")
    func deleteCategoryMovesScripts() async {
        let store = createTestStore()

        // Create category and script
        let category = ScriptCategory(name: "Temp Category")
        store.addScriptCategory(category)

        let script = Script(
            name: "Test Script In Category",
            type: .bash,
            content: "echo test",
            categoryId: category.id
        )
        store.addScript(script)

        // Verify script is in category
        #expect(store.scripts.first(where: { $0.id == script.id })?.categoryId == category.id)

        // Delete category
        store.deleteScriptCategory(category)

        // Verify script is now uncategorized
        #expect(store.scripts.first(where: { $0.id == script.id })?.categoryId == nil)

        // Cleanup
        store.deleteScript(script)
    }

    @Test("Scripts can be filtered by category")
    func scriptsFilteredByCategory() async {
        let store = createTestStore()

        // Create category
        let category = ScriptCategory(name: "Filter Test Category")
        store.addScriptCategory(category)

        // Create scripts
        let scriptInCategory = Script(
            name: "In Category",
            type: .bash,
            content: "1",
            categoryId: category.id
        )
        let scriptUncategorized = Script(
            name: "Uncategorized",
            type: .bash,
            content: "2",
            categoryId: nil
        )

        store.addScript(scriptInCategory)
        store.addScript(scriptUncategorized)

        // Test filtering
        let categoryScripts = store.scripts(in: category)
        #expect(categoryScripts.contains(where: { $0.id == scriptInCategory.id }))
        #expect(!categoryScripts.contains(where: { $0.id == scriptUncategorized.id }))

        let uncategorizedScripts = store.uncategorizedScripts
        #expect(uncategorizedScripts.contains(where: { $0.id == scriptUncategorized.id }))

        // Cleanup
        store.deleteScript(scriptInCategory)
        store.deleteScript(scriptUncategorized)
        store.deleteScriptCategory(category)
    }
}
