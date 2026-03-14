import Foundation
import Testing
@testable import SaneClick

struct AppStoreNativeActionTests {
    @Test("App Store action catalog matches library items")
    func actionCatalogMatchesLibrary() {
        let supportedNames = Set(AppStoreNativeAction.allCases.map(\.rawValue))
        let libraryNames = Set(ScriptLibrary.allScripts.map(\.name))

        #expect(supportedNames.isSubset(of: libraryNames))
        #expect(!supportedNames.contains("Move to Folder..."))
        #expect(!supportedNames.contains("Show Hidden Files"))
    }

    @Test("Duplicate with Timestamp creates a copy")
    func duplicateWithTimestampCreatesCopy() throws {
        let root = try temporaryDirectory()
        let fileURL = root.appendingPathComponent("report.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)

        let output = try AppStoreNativeActionExecutor.execute(.duplicateWithTimestamp, paths: [fileURL.path])
        let contents = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)

        #expect(output.contains("Created 1"))
        #expect(contents.count == 2)
        #expect(contents.contains(where: { $0.lastPathComponent == "report.txt" }))
        #expect(contents.contains(where: { $0.lastPathComponent.hasPrefix("report_") }))
    }

    @Test("Replace Spaces with Underscores renames the item")
    func replaceSpacesRenamesItem() throws {
        let root = try temporaryDirectory()
        let fileURL = root.appendingPathComponent("hello world.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)

        let output = try AppStoreNativeActionExecutor.execute(.replaceSpacesWithUnderscores, paths: [fileURL.path])
        let renamedURL = root.appendingPathComponent("hello_world.txt")

        #expect(output.contains("Renamed 1"))
        #expect(FileManager.default.fileExists(atPath: renamedURL.path))
    }

    @Test("Organize by Extension creates extension folders")
    func organizeByExtensionCreatesFolders() throws {
        let root = try temporaryDirectory()
        let pngURL = root.appendingPathComponent("photo.png")
        let txtURL = root.appendingPathComponent("notes.txt")
        try Data([0, 1, 2]).write(to: pngURL)
        try "notes".write(to: txtURL, atomically: true, encoding: .utf8)

        let output = try AppStoreNativeActionExecutor.execute(.organizeByExtension, paths: [root.path])

        #expect(output.contains("Organized 2"))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("png/photo.png").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("txt/notes.txt").path))
    }

    private func temporaryDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}
