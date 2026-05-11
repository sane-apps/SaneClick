import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Testing
@testable import SaneClick

struct ScriptExecutorTests {

    // MARK: - Bash Script Tests

    @Test("Bash script executes and returns output")
    func bashScriptExecutes() async {
        let script = Script(
            name: "Echo Test",
            type: .bash,
            content: "echo 'Hello World'"
        )

        let result = await executeBashDirectly(content: script.content, paths: [])

        switch result {
        case .success(let output):
            #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "Hello World")
        case .failure(let error):
            Issue.record("Bash execution failed: \(error)")
        }
    }

    @Test("Bash script receives file paths as arguments")
    func bashScriptReceivesPaths() async {
        let script = Script(
            name: "Print Args",
            type: .bash,
            content: "echo \"$1\""
        )

        let testPath = "/test/path/file.txt"
        let result = await executeBashDirectly(content: script.content, paths: [testPath])

        switch result {
        case .success(let output):
            #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == testPath)
        case .failure(let error):
            Issue.record("Bash execution failed: \(error)")
        }
    }

    @Test("Bash script handles multiple paths")
    func bashScriptHandlesMultiplePaths() async {
        let script = Script(
            name: "Count Args",
            type: .bash,
            content: "echo $#"
        )

        let paths = ["/path/one.txt", "/path/two.txt", "/path/three.txt"]
        let result = await executeBashDirectly(content: script.content, paths: paths)

        switch result {
        case .success(let output):
            #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "3")
        case .failure(let error):
            Issue.record("Bash execution failed: \(error)")
        }
    }

    @Test("Bash script reports failure on bad command")
    func bashScriptFailure() async {
        let script = Script(
            name: "Bad Command",
            type: .bash,
            content: "exit 1"
        )

        let result = await executeBashDirectly(content: script.content, paths: [])

        switch result {
        case .success:
            Issue.record("Expected failure but got success")
        case .failure:
            // Expected
            break
        }
    }

    // MARK: - AppleScript Tests

    @Test("AppleScript executes simple command")
    func appleScriptExecutes() async {
        let script = Script(
            name: "AppleScript Test",
            type: .applescript,
            content: "return \"Hello from AppleScript\""
        )

        let result = await executeAppleScriptDirectly(content: script.content, paths: [])

        switch result {
        case .success(let output):
            #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "Hello from AppleScript")
        case .failure(let error):
            Issue.record("AppleScript execution failed: \(error)")
        }
    }

    // MARK: - Library Script Tests

    @Test("Copy Path script has valid bash content")
    func copyPathScriptContent() {
        let copyPathScripts = ScriptLibrary.scripts(for: .universal)
            .filter { $0.name == "Copy Path" }

        #expect(copyPathScripts.count == 1, "Copy Path script should exist in library")

        if let script = copyPathScripts.first {
            #expect(script.type == .bash)
            #expect(script.content.contains("pbcopy"), "Copy Path should use pbcopy")
        }
    }

    @Test("Open in Terminal script has valid bash content")
    func openInTerminalScriptContent() {
        let scripts = ScriptLibrary.scripts(for: .universal)
            .filter { $0.name == "Open in Terminal" }

        #expect(scripts.count == 1, "Open in Terminal script should exist in library")

        if let script = scripts.first {
            #expect(script.type == .bash)
            #expect(script.content.contains("Terminal"), "Should reference Terminal app")
        }
    }

    @Test("All library scripts have non-empty content")
    func allLibraryScriptsHaveContent() {
        for category in ScriptLibrary.ScriptCategory.allCases {
            let scripts = ScriptLibrary.scripts(for: category)
            for script in scripts {
                #expect(!script.content.isEmpty, "\(script.name) should have content")
            }
        }
    }

    @Test("All library scripts have valid icons")
    func allLibraryScriptsHaveIcons() {
        for category in ScriptLibrary.ScriptCategory.allCases {
            let scripts = ScriptLibrary.scripts(for: category)
            for script in scripts {
                #expect(!script.icon.isEmpty, "\(script.name) should have an icon")
            }
        }
    }

    @Test("Representative right-click actions complete for every category")
    func representativeRightClickActionsCompleteForEveryCategory() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let duplicateFile = root.appendingPathComponent("duplicate.txt")
        try "duplicate".write(to: duplicateFile, atomically: true, encoding: .utf8)
        try await runLibraryScript("Duplicate with Timestamp", paths: [duplicateFile.path])
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix("duplicate_") })

        let spacedFile = root.appendingPathComponent("hello world.txt")
        try "rename".write(to: spacedFile, atomically: true, encoding: .utf8)
        try await runLibraryScript("Replace Spaces with Underscores", paths: [spacedFile.path])
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("hello_world.txt").path))

        let imageURL = root.appendingPathComponent("image.png")
        try makePNGFixture().write(to: imageURL)
        try await runLibraryScript("Convert to JPEG", paths: [imageURL.path])
        #expect(
            FileManager.default.fileExists(atPath: root.appendingPathComponent("image.jpg").path),
            "Convert to JPEG should create image.jpg. Directory contents: \(directoryContents(at: root))"
        )

        let projectFolder = root.appendingPathComponent("Project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectFolder, withIntermediateDirectories: true)
        try await runLibraryScript("Create .gitignore", paths: [projectFolder.path])
        #expect(FileManager.default.fileExists(atPath: projectFolder.appendingPathComponent(".gitignore").path))

        let hashFile = root.appendingPathComponent("hash-me.txt")
        try "hash".write(to: hashFile, atomically: true, encoding: .utf8)
        try await runLibraryScript("Create SHA256 File", paths: [hashFile.path])
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("hash-me.txt.sha256").path))
    }

    // MARK: - Helper Functions (duplicated from ScriptExecutor for testing)

    private func runLibraryScript(_ name: String, paths: [String]) async throws {
        let libraryScript = try #require(ScriptLibrary.allScripts.first { $0.name == name })
        let result = await executeBashDirectly(content: libraryScript.content, paths: paths)
        if case .failure(let error) = result {
            Issue.record("\(name) failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func temporaryDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private func makePNGFixture() throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try #require(CGContext(
            data: nil,
            width: 8,
            height: 8,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.1, green: 0.3, blue: 0.8, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func directoryContents(at url: URL) -> String {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return names.sorted().joined(separator: ", ")
    }

    private func executeBashDirectly(content: String, paths: [String]) async -> Result<String, ScriptError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        // Note: with bash -c, first arg after script becomes $0, so we add "bash" as placeholder
        process.arguments = ["-c", content, "bash"] + paths

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return .success(output)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return .failure(.executionFailed(errorOutput))
            }
        } catch {
            return .failure(.launchFailed(error.localizedDescription))
        }
    }

    private func executeAppleScriptDirectly(content: String, paths: [String]) async -> Result<String, ScriptError> {
        let fullScript = """
        on run argv
            \(content)
        end run
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", fullScript] + paths

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return .success(output)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return .failure(.executionFailed(errorOutput))
            }
        } catch {
            return .failure(.launchFailed(error.localizedDescription))
        }
    }
}
