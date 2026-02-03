import Foundation
import Testing
@testable import SaneClick

struct ScriptTests {

    @Test("Script model initializes with defaults")
    func scriptInitializesWithDefaults() {
        let script = Script(name: "Test Script")

        #expect(script.name == "Test Script")
        #expect(script.type == .bash)
        #expect(script.content == "")
        #expect(script.isEnabled == true)
        #expect(script.icon == "terminal")
        #expect(script.appliesTo == .allItems)
        #expect(script.minSelection == 1)
        #expect(script.maxSelection == nil)
    }

    @Test("Script model is Codable")
    func scriptIsCodable() throws {
        let original = Script(
            name: "My Script",
            type: .applescript,
            content: "tell app \"Finder\" to activate",
            isEnabled: true,
            icon: "applescript",
            appliesTo: .foldersOnly
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Script.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.type == original.type)
        #expect(decoded.content == original.content)
        #expect(decoded.isEnabled == original.isEnabled)
        #expect(decoded.icon == original.icon)
        #expect(decoded.appliesTo == original.appliesTo)
        #expect(decoded.minSelection == original.minSelection)
        #expect(decoded.maxSelection == original.maxSelection)
    }

    @Test("ScriptType has correct icons")
    func scriptTypeIcons() {
        #expect(ScriptType.bash.icon == "terminal")
        #expect(ScriptType.applescript.icon == "applescript")
        #expect(ScriptType.automator.icon == "gearshape.2")
    }

    @Test("AppliesTo has correct icons")
    func appliesToIcons() {
        #expect(AppliesTo.allItems.icon == "square.stack")
        #expect(AppliesTo.filesOnly.icon == "doc")
        #expect(AppliesTo.foldersOnly.icon == "folder")
        #expect(AppliesTo.container.icon == "rectangle")
    }

    @Test("Script equality works correctly")
    func scriptEquality() {
        let script1 = Script(name: "Test", type: .bash, content: "echo hello")
        let script2 = Script(id: script1.id, name: "Test", type: .bash, content: "echo hello")
        let script3 = Script(name: "Test", type: .bash, content: "echo hello")

        #expect(script1 == script2)
        #expect(script1 != script3) // Different IDs
    }

    // MARK: - File Type Filter Tests

    @Test("Script with no extensions matches all files")
    func noExtensionsMatchesAll() {
        let script = Script(name: "Test", fileExtensions: [])
        let urls = [
            URL(fileURLWithPath: "/test/file.jpg"),
            URL(fileURLWithPath: "/test/file.pdf"),
            URL(fileURLWithPath: "/test/file.txt")
        ]
        #expect(script.matchesFiles(urls) == true)
    }

    @Test("Script with extensions matches files with those extensions (any mode)")
    func extensionsMatchAnyMode() {
        let script = Script(
            name: "Image Script",
            fileExtensions: ["jpg", "png"],
            extensionMatchMode: .any
        )

        // One matching file
        let mixedFiles = [
            URL(fileURLWithPath: "/test/image.jpg"),
            URL(fileURLWithPath: "/test/document.pdf")
        ]
        #expect(script.matchesFiles(mixedFiles) == true)

        // No matching files
        let noMatch = [
            URL(fileURLWithPath: "/test/document.pdf"),
            URL(fileURLWithPath: "/test/file.txt")
        ]
        #expect(script.matchesFiles(noMatch) == false)
    }

    @Test("Script with extensions requires all files match (all mode)")
    func extensionsMatchAllMode() {
        let script = Script(
            name: "Image Script",
            fileExtensions: ["jpg", "png"],
            extensionMatchMode: .all
        )

        // All files match
        let allMatch = [
            URL(fileURLWithPath: "/test/image1.jpg"),
            URL(fileURLWithPath: "/test/image2.png")
        ]
        #expect(script.matchesFiles(allMatch) == true)

        // Mixed files - not all match
        let mixed = [
            URL(fileURLWithPath: "/test/image.jpg"),
            URL(fileURLWithPath: "/test/document.pdf")
        ]
        #expect(script.matchesFiles(mixed) == false)
    }

    @Test("Extension matching is case insensitive")
    func extensionsCaseInsensitive() {
        let script = Script(
            name: "Test",
            fileExtensions: ["jpg", "PNG"],
            extensionMatchMode: .any
        )

        let upperCase = [URL(fileURLWithPath: "/test/image.JPG")]
        #expect(script.matchesFiles(upperCase) == true)

        let lowerCase = [URL(fileURLWithPath: "/test/image.png")]
        #expect(script.matchesFiles(lowerCase) == true)
    }

    @Test("Extension matching handles dots in input")
    func extensionsWithDots() {
        let script = Script(
            name: "Test",
            fileExtensions: [".jpg", "png"],
            extensionMatchMode: .any
        )

        let file = [URL(fileURLWithPath: "/test/image.jpg")]
        #expect(script.matchesFiles(file) == true)
    }

    @Test("Script with file filter shows for folders when appliesTo allows")
    func fileFilterWithFolders() {
        // Script set to foldersOnly should match even with file extensions
        let foldersOnlyScript = Script(
            name: "Folder Script",
            appliesTo: .foldersOnly,
            fileExtensions: ["jpg"],
            extensionMatchMode: .any
        )

        // Directory URL (trailing slash convention for test)
        let folderURL = URL(fileURLWithPath: "/test/folder", isDirectory: true)
        #expect(foldersOnlyScript.matchesFiles([folderURL]) == true)
    }

    @Test("Selection count filter respects min and max")
    func selectionCountFilter() {
        let script = Script(
            name: "Selection Test",
            minSelection: 2,
            maxSelection: 3
        )

        #expect(script.matchesSelectionCount(1) == false)
        #expect(script.matchesSelectionCount(2) == true)
        #expect(script.matchesSelectionCount(3) == true)
        #expect(script.matchesSelectionCount(4) == false)
    }

    @Test("Script is Codable with file extensions")
    func scriptCodableWithExtensions() throws {
        let original = Script(
            name: "Image Script",
            type: .bash,
            content: "convert $@",
            fileExtensions: ["jpg", "png", "gif"],
            extensionMatchMode: .all
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Script.self, from: data)

        #expect(decoded.fileExtensions == original.fileExtensions)
        #expect(decoded.extensionMatchMode == original.extensionMatchMode)
    }

    @Test("ExtensionMatchMode has correct raw values")
    func extensionMatchModeRawValues() {
        #expect(ExtensionMatchMode.any.rawValue == "Show if any selected file matches")
        #expect(ExtensionMatchMode.all.rawValue == "Show only if all selected files match")
    }

    @Test("AppliesTo has correct raw values for extension compatibility")
    func appliesToRawValues() {
        // These raw values must match what FinderSync.swift expects
        #expect(AppliesTo.allItems.rawValue == "Files & Folders")
        #expect(AppliesTo.filesOnly.rawValue == "Files Only")
        #expect(AppliesTo.foldersOnly.rawValue == "Folders Only")
        #expect(AppliesTo.container.rawValue == "Inside Folder")
    }
}
