import Foundation
import Testing
@testable import SaneClick

struct ScriptLibraryTests {

    // MARK: - Library Content Tests

    @Test("All library scripts have valid content")
    func allScriptsHaveContent() {
        for script in ScriptLibrary.allScripts {
            #expect(!script.name.isEmpty, "Script name should not be empty")
            #expect(!script.content.isEmpty, "Script \(script.name) should have content")
            #expect(!script.icon.isEmpty, "Script \(script.name) should have an icon")
            #expect(!script.description.isEmpty, "Script \(script.name) should have a description")
        }
    }

    @Test("Library has 50+ scripts")
    func libraryHasManyScripts() {
        let count = ScriptLibrary.allScripts.count
        #expect(count >= 50, "Library should have at least 50 scripts, has \(count)")
    }

    @Test("All categories have scripts")
    func allCategoriesHaveScripts() {
        for category in ScriptLibrary.ScriptCategory.allCases {
            let scripts = ScriptLibrary.scripts(for: category)
            #expect(!scripts.isEmpty, "Category \(category.rawValue) should have scripts")
        }
    }

    @Test("Categories have icons and descriptions")
    func categoriesHaveMetadata() {
        for category in ScriptLibrary.ScriptCategory.allCases {
            #expect(!category.icon.isEmpty, "Category \(category.rawValue) should have an icon")
            #expect(!category.description.isEmpty, "Category \(category.rawValue) should have a description")
        }
    }

    @Test("Library scripts can be converted to Script model")
    func scriptsCanBeConverted() {
        for libraryScript in ScriptLibrary.allScripts {
            let script = libraryScript.toScript()
            #expect(script.name == libraryScript.name)
            #expect(script.type == libraryScript.type)
            #expect(script.content == libraryScript.content)
            #expect(script.icon == libraryScript.icon)
            #expect(script.appliesTo == libraryScript.appliesTo)
            #expect(script.fileExtensions == libraryScript.fileExtensions)
        }
    }

    // MARK: - Category Tests

    @Test("Universal category has essential scripts")
    func universalHasEssentials() {
        let scripts = ScriptLibrary.universalScripts
        let names = scripts.map { $0.name }

        #expect(names.contains("Copy Path"), "Should have Copy Path script")
        #expect(names.contains("Open in Terminal"), "Should have Open in Terminal script")
    }

    @Test("Developer category has dev tools")
    func developerHasDevTools() {
        let scripts = ScriptLibrary.developerScripts
        let names = scripts.map { $0.name }

        #expect(names.contains("Git Init"), "Should have Git Init script")
        #expect(names.contains("Open in VS Code"), "Should have Open in VS Code script")
    }

    @Test("Designer category has image tools")
    func designerHasImageTools() {
        let scripts = ScriptLibrary.designerScripts
        let names = scripts.map { $0.name }

        #expect(names.contains("Convert to PNG"), "Should have Convert to PNG script")
        #expect(names.contains("Resize 50%"), "Should have Resize script")
    }

    @Test("Power user category has advanced tools")
    func powerUserHasAdvancedTools() {
        let scripts = ScriptLibrary.powerUserScripts
        let names = scripts.map { $0.name }

        #expect(names.contains("SHA256 Hash"), "Should have hash script")
        #expect(names.contains("Compress to ZIP"), "Should have compress script")
    }

    @Test("Organization category has file management")
    func organizationHasFileManagement() {
        let scripts = ScriptLibrary.organizationScripts
        let names = scripts.map { $0.name }

        #expect(names.contains("Flatten Folder"), "Should have flatten folder script")
        #expect(names.contains("Organize by Extension"), "Should have organize script")
    }

    // MARK: - Script Content Validation

    @Test("Bash scripts use proper arguments")
    func bashScriptsUseArguments() {
        let bashScripts = ScriptLibrary.allScripts.filter { $0.type == .bash }

        for script in bashScripts {
            // Most bash scripts should reference $@ or $1
            let usesArgs = script.content.contains("$@") ||
                           script.content.contains("$1") ||
                           script.content.contains("\"$") ||
                           script.content.contains("argv")
            #expect(usesArgs, "Bash script \(script.name) should use file arguments")
        }
    }

    @Test("AppleScript scripts have proper structure")
    func appleScriptsHaveStructure() {
        let appleScripts = ScriptLibrary.allScripts.filter { $0.type == .applescript }

        for script in appleScripts {
            // AppleScript should reference argv or tell application
            let hasStructure = script.content.contains("argv") ||
                               script.content.contains("tell application") ||
                               script.content.contains("tell app")
            #expect(hasStructure, "AppleScript \(script.name) should have proper structure")
        }
    }
}

// MARK: - Execution Request Tests

struct ExecutionRequestTests {

    @Test("ExecutionRequest is Codable")
    func requestIsCodable() throws {
        let original = ExecutionRequest(
            scriptId: UUID(),
            paths: ["/path/to/file1.txt", "/path/to/file2.txt"],
            timestamp: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ExecutionRequest.self, from: data)

        #expect(decoded.scriptId == original.scriptId)
        #expect(decoded.paths == original.paths)
    }

    @Test("ExecutionRequest handles empty paths")
    func requestHandlesEmptyPaths() throws {
        let request = ExecutionRequest(
            scriptId: UUID(),
            paths: [],
            timestamp: Date()
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(ExecutionRequest.self, from: data)

        #expect(decoded.paths.isEmpty)
    }

    @Test("ExecutionRequest handles special characters in paths")
    func requestHandlesSpecialChars() throws {
        let paths = [
            "/Users/test/file with spaces.txt",
            "/Users/test/résumé.pdf",
            "/Users/test/日本語.txt"
        ]

        let request = ExecutionRequest(
            scriptId: UUID(),
            paths: paths,
            timestamp: Date()
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(ExecutionRequest.self, from: data)

        #expect(decoded.paths == paths)
    }
}

// MARK: - Onboarding Helper Tests

struct OnboardingHelperTests {

    @Test("Onboarding state can be checked and reset")
    func onboardingStateManagement() {
        // Reset to known state
        OnboardingHelper.reset()
        #expect(OnboardingHelper.needsOnboarding == true)

        // Mark as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        #expect(OnboardingHelper.needsOnboarding == false)

        // Reset again
        OnboardingHelper.reset()
        #expect(OnboardingHelper.needsOnboarding == true)
    }
}
