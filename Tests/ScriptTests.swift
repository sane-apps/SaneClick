import Foundation
@testable import SaneClick
import Testing

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

    @Test("AppliesTo rejects wrong Finder selection kind")
    func appliesToRejectsWrongFinderSelectionKind() {
        let file = URL(fileURLWithPath: "/test/file.txt", isDirectory: false)
        let folder = URL(fileURLWithPath: "/test/folder", isDirectory: true)

        #expect(Script(name: "Files", appliesTo: .filesOnly).matchesFiles([file]) == true)
        #expect(Script(name: "Files", appliesTo: .filesOnly).matchesFiles([folder]) == false)
        #expect(Script(name: "Folders", appliesTo: .foldersOnly).matchesFiles([folder]) == true)
        #expect(Script(name: "Folders", appliesTo: .foldersOnly).matchesFiles([file]) == false)
        #expect(Script(name: "Folders", appliesTo: .foldersOnly).matchesFiles([file, folder]) == false)
        #expect(Script(name: "All", appliesTo: .allItems).matchesFiles([file, folder]) == true)
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

    @Test("Script with file filter does not match folder-only selection")
    func fileFilterRejectsFolderOnlySelection() {
        let foldersOnlyScript = Script(
            name: "Folder Script",
            appliesTo: .foldersOnly,
            fileExtensions: ["jpg"],
            extensionMatchMode: .any
        )

        let folderURL = URL(fileURLWithPath: "/test/folder", isDirectory: true)
        #expect(foldersOnlyScript.matchesFiles([folderURL]) == false)
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

    // MARK: - Output Mode & Confirmation Codable

    @Test("Script round-trips every outputMode and confirmBeforeRun", arguments: ScriptOutputMode.allCases)
    func scriptRoundTripsOutputModeAndConfirm(_ mode: ScriptOutputMode) throws {
        let original = Script(
            name: "Behavior",
            type: .bash,
            content: "echo hi",
            outputMode: mode,
            confirmBeforeRun: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Script.self, from: data)

        #expect(decoded.outputMode == mode)
        #expect(decoded.confirmBeforeRun == true)
    }

    @Test("Script defaults outputMode/confirmBeforeRun when JSON omits both (back-compat)")
    func scriptDecodesMissingBehaviorFieldsToDefaults() throws {
        // A legacy payload that predates the two new fields. It must still decode,
        // defaulting to .standard / false so older saved actions behave exactly
        // as before.
        let legacyJSON = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "name": "Legacy",
            "type": "Shell Command",
            "content": "echo hi",
            "isEnabled": true,
            "icon": "terminal",
            "appliesTo": "Files & Folders"
        }
        """
        let data = try #require(legacyJSON.data(using: .utf8))
        let decoded = try JSONDecoder().decode(Script.self, from: data)

        #expect(decoded.outputMode == .standard)
        #expect(decoded.confirmBeforeRun == false)
    }

    // MARK: - libraryCategory Codable

    @Test("Script round-trips libraryCategory through Codable")
    func scriptRoundTripsLibraryCategory() throws {
        let original = Script(
            name: "Copy Text from Image",
            type: .bash,
            content: "# native",
            libraryCategory: "Images & Media"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Script.self, from: data)

        #expect(decoded.libraryCategory == "Images & Media")
    }

    @Test("Script decodes missing libraryCategory to nil (back-compat)")
    func scriptDecodesMissingLibraryCategoryToNil() throws {
        // Legacy payload that predates the libraryCategory field must still decode,
        // defaulting libraryCategory to nil so older saved actions are unchanged.
        let legacyJSON = """
        {
            "id": "22222222-2222-2222-2222-222222222222",
            "name": "Legacy",
            "type": "Shell Command",
            "content": "echo hi",
            "isEnabled": true,
            "icon": "terminal",
            "appliesTo": "Files & Folders"
        }
        """
        let data = try #require(legacyJSON.data(using: .utf8))
        let decoded = try JSONDecoder().decode(Script.self, from: data)

        #expect(decoded.libraryCategory == nil)
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
