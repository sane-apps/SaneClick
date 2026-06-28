import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import PDFKit
@testable import SaneClick
import Testing
import UniformTypeIdentifiers

struct AppStoreNativeActionTests {
    @Test("App Store action catalog matches library items")
    func actionCatalogMatchesLibrary() {
        let supportedNames = Set(AppStoreNativeAction.allCases.map(\.rawValue))
        let libraryNames = Set(ScriptLibrary.allScripts.map(\.name))

        #expect(supportedNames.isSubset(of: libraryNames))
        #expect(!supportedNames.contains("Move to Folder..."))
        #expect(!supportedNames.contains("Show Hidden Files"))
    }

    @Test("requiresNativeRuntime is true only for the nine native-only actions")
    func requiresNativeRuntimeOnlyForNativeOnlyActions() {
        let nativeOnly: Set<AppStoreNativeAction> = [
            .copyTextFromImage,
            .saveTextFromImage,
            .combineImagesIntoPDF,
            .splitPDFIntoPages,
            .pdfToImages,
            .copyFileURL,
            .copyFilenameNoExtension,
            .copyParentPath,
            .copyMarkdownLink
        ]

        #expect(nativeOnly.count == 9)
        for action in AppStoreNativeAction.allCases {
            #expect(action.requiresNativeRuntime == nativeOnly.contains(action))
        }
    }

    @Test("AppStoreNativeAction(script:) returns nil for non-matching scripts")
    func initReturnsNilForNonMatchingScript() {
        let mismatched = Script(
            name: "Copy as File URL",
            type: .bash,
            content: "echo not-the-library-content",
            icon: "link",
            appliesTo: .allItems,
            fileExtensions: []
        )
        #expect(AppStoreNativeAction(script: mismatched) == nil)

        let unknown = Script(
            name: "Totally Custom Action",
            type: .bash,
            content: "echo hi",
            icon: "gear",
            appliesTo: .allItems,
            fileExtensions: []
        )
        #expect(AppStoreNativeAction(script: unknown) == nil)

        // A faithful library copy still matches.
        if let library = ScriptLibrary.libraryScript(named: "Copy as File URL") {
            #expect(AppStoreNativeAction(script: library.toScript()) == .copyFileURL)
        }
    }

    @Test("New behavior fields are guardrail-neutral for native-action matching")
    func behaviorFieldsDoNotAffectNativeMatching() throws {
        // Every library script must still resolve to its native action regardless
        // of the new outputMode / confirmBeforeRun fields, because matching keys
        // only on name + type + content. This covers the pre-enabled destructive
        // built-ins (which now carry confirmBeforeRun: true).
        for action in AppStoreNativeAction.allCases {
            let library = try #require(ScriptLibrary.libraryScript(named: action.rawValue))
            #expect(AppStoreNativeAction(script: library.toScript()) == action, "\(action.rawValue) should still match")
        }

        // Flipping the new fields on a copy of a native library script must not
        // break the match either.
        let flatten = try #require(ScriptLibrary.libraryScript(named: "Flatten Folder")).toScript()
        var modified = flatten
        modified.outputMode = .showResult
        modified.confirmBeforeRun = false
        #expect(AppStoreNativeAction(script: modified) == .flattenFolder)
    }

    @Test("Copy as File URL copies a percent-encoded file URL")
    func copyFileURLReturnsAbsoluteString() throws {
        let root = try temporaryDirectory()
        let fileURL = root.appendingPathComponent("My File.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)

        let output = try AppStoreNativeActionExecutor.execute(.copyFileURL, paths: [fileURL.path])

        #expect(output == fileURL.standardizedFileURL.absoluteString)
        #expect(output.hasPrefix("file://"))
        #expect(output.contains("My%20File.txt"))
    }

    @Test("Copy Filename without Extension drops the extension")
    func copyFilenameNoExtensionDropsExtension() throws {
        let root = try temporaryDirectory()
        let fileURL = root.appendingPathComponent("report.final.txt")
        try "hi".write(to: fileURL, atomically: true, encoding: .utf8)

        let output = try AppStoreNativeActionExecutor.execute(.copyFilenameNoExtension, paths: [fileURL.path])

        #expect(output == "report.final")
    }

    @Test("Copy Parent Folder Path returns the enclosing directory")
    func copyParentPathReturnsParent() throws {
        let root = try temporaryDirectory()
        let fileURL = root.appendingPathComponent("note.txt")
        try "hi".write(to: fileURL, atomically: true, encoding: .utf8)

        let output = try AppStoreNativeActionExecutor.execute(.copyParentPath, paths: [fileURL.path])

        #expect(output == root.standardizedFileURL.path)
    }

    @Test("Copy as Markdown Link formats a Markdown link")
    func copyMarkdownLinkFormatsLink() throws {
        let root = try temporaryDirectory()
        let fileURL = root.appendingPathComponent("doc.txt")
        try "hi".write(to: fileURL, atomically: true, encoding: .utf8)

        let output = try AppStoreNativeActionExecutor.execute(.copyMarkdownLink, paths: [fileURL.path])

        #expect(output == "[doc.txt](\(fileURL.standardizedFileURL.absoluteString))")
    }

    @Test("Copy Text from Image OCRs the rendered text")
    func copyTextFromImageRecognizesText() throws {
        let root = try temporaryDirectory()
        let imageURL = root.appendingPathComponent("scan.png")
        try writePNG(text: "HELLO", to: imageURL)

        let output = try AppStoreNativeActionExecutor.execute(.copyTextFromImage, paths: [imageURL.path])

        #expect(output.uppercased().contains("HELLO"))
    }

    @Test("Copy Text from Image honors EXIF orientation on a rotated image")
    func copyTextFromImageHonorsOrientation() throws {
        // The pixels are stored rotated 90 degrees with an EXIF orientation tag
        // that says "display rotated upright". Without orientation-aware OCR,
        // Vision reads sideways pixels and finds little/no text; with the fix it
        // recognizes the upright "HELLO".
        let root = try temporaryDirectory()
        let imageURL = root.appendingPathComponent("rotated.png")
        try writeRotatedPNG(text: "HELLO", to: imageURL)

        let output = try AppStoreNativeActionExecutor.execute(.copyTextFromImage, paths: [imageURL.path])

        #expect(output.uppercased().contains("HELLO"))
    }

    @Test("Save Text from Image writes a sidecar with the recognized text")
    func saveTextFromImageWritesSidecar() throws {
        let root = try temporaryDirectory()
        let imageURL = root.appendingPathComponent("scan.png")
        try writePNG(text: "HELLO", to: imageURL)

        let output = try AppStoreNativeActionExecutor.execute(.saveTextFromImage, paths: [imageURL.path])
        let sidecarURL = root.appendingPathComponent("scan.txt")

        #expect(output.contains("Saved text"))
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path))
        let contents = try String(contentsOf: sidecarURL, encoding: .utf8)
        #expect(contents.uppercased().contains("HELLO"))
    }

    @Test("Combine Images into PDF yields one page per image")
    func combineImagesIntoPDFCreatesMultiPagePDF() throws {
        let root = try temporaryDirectory()
        let first = root.appendingPathComponent("a.png")
        let second = root.appendingPathComponent("b.png")
        let third = root.appendingPathComponent("c.png")
        try writePNG(text: "A", to: first)
        try writePNG(text: "B", to: second)
        try writePNG(text: "C", to: third)

        let output = try AppStoreNativeActionExecutor.execute(
            .combineImagesIntoPDF,
            paths: [first.path, second.path, third.path]
        )
        let pdfURL = root.appendingPathComponent("Combined.pdf")
        let document = try #require(PDFDocument(url: pdfURL))

        #expect(output.contains("Combined.pdf"))
        #expect(document.pageCount == 3)
    }

    @Test("Split PDF into Pages writes one file per page")
    func splitPDFIntoPagesWritesPerPage() throws {
        let root = try temporaryDirectory()
        let pdfURL = root.appendingPathComponent("doc.pdf")
        try writePDF(pageCount: 2, to: pdfURL)

        let output = try AppStoreNativeActionExecutor.execute(.splitPDFIntoPages, paths: [pdfURL.path])

        #expect(output.contains("Split into 2"))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("doc-001.pdf").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("doc-002.pdf").path))
    }

    @Test("PDF to Images renders one readable PNG per page")
    func pdfToImagesRendersPerPage() throws {
        let root = try temporaryDirectory()
        let pdfURL = root.appendingPathComponent("doc.pdf")
        try writePDF(pageCount: 2, to: pdfURL)

        let output = try AppStoreNativeActionExecutor.execute(.pdfToImages, paths: [pdfURL.path])
        let firstPNG = root.appendingPathComponent("doc-001.png")
        let secondPNG = root.appendingPathComponent("doc-002.png")

        #expect(output.contains("Rendered 2"))
        #expect(NSImage(contentsOf: firstPNG) != nil)
        #expect(NSImage(contentsOf: secondPNG) != nil)
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

    /// Render `text` in large black type on a white background and save as PNG.
    private func writePNG(text: String, to url: URL) throws {
        let width = 600
        let height = 200
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "test", code: 1)
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 96, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)
        context.textPosition = CGPoint(x: 40, y: 70)
        CTLineDraw(line, context)

        guard let cgImage = context.makeImage() else {
            throw NSError(domain: "test", code: 2)
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "test", code: 3)
        }
        try data.write(to: url)
    }

    /// Render `text` upright but store the pixels rotated 90 degrees, then tag the
    /// file with EXIF orientation 6 (rotate 90 degrees CW to display upright).
    /// Orientation-blind OCR sees sideways pixels; orientation-aware OCR recovers
    /// the upright text. Used to prove the orientation fix in `recognizeText`.
    private func writeRotatedPNG(text: String, to url: URL) throws {
        // Stored pixel buffer is portrait (the upright image rotated 90 deg CCW).
        let storedWidth = 200
        let storedHeight = 600
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: storedWidth,
            height: storedHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "test", code: 1)
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: storedWidth, height: storedHeight))

        // Draw the text rotated 90 deg CCW into the portrait buffer so that, after
        // the EXIF orientation-6 rotation, it reads upright.
        context.translateBy(x: CGFloat(storedWidth), y: 0)
        context.rotate(by: .pi / 2)

        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 96, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)
        context.textPosition = CGPoint(x: 40, y: 70)
        CTLineDraw(line, context)

        guard let cgImage = context.makeImage() else {
            throw NSError(domain: "test", code: 2)
        }

        let type = UTType.png.identifier as CFString
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type, 1, nil) else {
            throw NSError(domain: "test", code: 3)
        }
        // 6 = rotate 90 deg CW to display upright.
        let properties = [kCGImagePropertyOrientation: 6] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "test", code: 4)
        }
    }

    /// Build a simple multi-page PDF with a labelled box on each page.
    private func writePDF(pageCount: Int, to url: URL) throws {
        let document = PDFDocument()
        for index in 0 ..< pageCount {
            let image = NSImage(size: NSSize(width: 200, height: 200))
            image.lockFocus()
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: 200, height: 200).fill()
            let label = "Page \(index + 1)"
            label.draw(
                at: NSPoint(x: 20, y: 90),
                withAttributes: [.font: NSFont.systemFont(ofSize: 24)]
            )
            image.unlockFocus()
            if let page = PDFPage(image: image) {
                document.insert(page, at: index)
            }
        }
        guard document.write(to: url) else {
            throw NSError(domain: "test", code: 4)
        }
    }
}
