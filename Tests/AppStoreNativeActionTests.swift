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

    // MARK: - Image conversion / transforms

    @Test("Each ported image action matches its library entry via init(script:)")
    func portedImageActionsMatchLibrary() throws {
        let ported: [AppStoreNativeAction] = [
            .convertToPNG, .convertToJPEG, .heicToJPEG, .resize50, .resizeTo1920,
            .createThumbnail256, .removePhotoInfo, .rotate90Clockwise, .createRetinaCopy,
            .getImageDimensions
        ]
        for action in ported {
            let library = try #require(ScriptLibrary.libraryScript(named: action.rawValue))
            #expect(AppStoreNativeAction(script: library.toScript()) == action, "\(action.rawValue) should match")
            // These keep their sips bash content on the direct build.
            #expect(action.requiresNativeRuntime == false, "\(action.rawValue) must not force native runtime")
        }
    }

    @Test("Image actions are App Store Pro actions")
    func imageActionsArePro() {
        let pro = Set(AppStoreActionCatalog.proActions)
        for action in [AppStoreNativeAction.convertToPNG, .resize50, .getImageDimensions, .heicToJPEG] {
            #expect(pro.contains(action))
        }
    }

    @Test("Convert to PNG yields a readable PNG sibling")
    func convertToPNGCreatesPNG() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("photo.jpg")
        try writeImageFile(width: 100, height: 60, to: source, format: .jpeg)

        let output = try AppStoreNativeActionExecutor.execute(.convertToPNG, paths: [source.path])
        let pngURL = root.appendingPathComponent("photo.png")

        #expect(output.contains("Converted 1"))
        #expect(FileManager.default.fileExists(atPath: pngURL.path))
        #expect(imageUTType(pngURL) == UTType.png.identifier)
    }

    @Test("Convert to JPEG yields a readable JPEG sibling")
    func convertToJPEGCreatesJPEG() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("photo.png")
        try writeImageFile(width: 100, height: 60, to: source, format: .png)

        let output = try AppStoreNativeActionExecutor.execute(.convertToJPEG, paths: [source.path])
        let jpgURL = root.appendingPathComponent("photo.jpg")

        #expect(output.contains("Converted 1"))
        #expect(FileManager.default.fileExists(atPath: jpgURL.path))
        #expect(imageUTType(jpgURL) == UTType.jpeg.identifier)
    }

    @Test("HEIC to JPEG only converts HEIC inputs")
    func heicToJPEGConvertsHEIC() throws {
        let root = try temporaryDirectory()
        let heic = root.appendingPathComponent("photo.heic")
        try writeImageFile(width: 80, height: 80, to: heic, format: .heic)

        let output = try AppStoreNativeActionExecutor.execute(.heicToJPEG, paths: [heic.path])
        let jpgURL = root.appendingPathComponent("photo.jpg")

        #expect(output.contains("Converted 1"))
        #expect(FileManager.default.fileExists(atPath: jpgURL.path))
        #expect(imageUTType(jpgURL) == UTType.jpeg.identifier)
    }

    @Test("Resize 50% halves the pixel width")
    func resize50HalvesDimensions() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("big.png")
        try writeImageFile(width: 400, height: 200, to: source, format: .png)

        let output = try AppStoreNativeActionExecutor.execute(.resize50, paths: [source.path])
        let resized = root.appendingPathComponent("big_half.png")

        #expect(output.contains("Resized 1"))
        let size = try #require(pixelSize(resized))
        #expect(size.width == 200)
        #expect(size.height == 100)
    }

    @Test("Resize to 1920px sets the width to 1920")
    func resizeTo1920SetsWidth() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("wide.png")
        try writeImageFile(width: 3840, height: 2160, to: source, format: .png)

        _ = try AppStoreNativeActionExecutor.execute(.resizeTo1920, paths: [source.path])
        let resized = root.appendingPathComponent("wide_1920.png")

        let size = try #require(pixelSize(resized))
        #expect(size.width == 1920)
        #expect(size.height == 1080)
    }

    @Test("Create Thumbnail fits the longest side to 256px")
    func thumbnailFitsLongestSide() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("pic.png")
        try writeImageFile(width: 1024, height: 512, to: source, format: .png)

        let output = try AppStoreNativeActionExecutor.execute(.createThumbnail256, paths: [source.path])
        let thumb = root.appendingPathComponent("pic_thumb.png")

        #expect(output.contains("Created 1"))
        let size = try #require(pixelSize(thumb))
        #expect(size.width == 256)
        #expect(size.height == 128)
    }

    @Test("Remove Photo Info drops GPS and identifying EXIF fields")
    func removePhotoInfoDropsMetadata() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("tagged.jpg")
        try writeImageFile(width: 120, height: 90, to: source, format: .jpeg, includeGPS: true)
        // Sanity check: the source actually carried GPS + an EXIF UserComment.
        #expect(hasMetadata(source, key: kCGImagePropertyGPSDictionary))
        #expect(exifField(source, key: kCGImagePropertyExifUserComment) != nil)

        let output = try AppStoreNativeActionExecutor.execute(.removePhotoInfo, paths: [source.path])
        let cleaned = root.appendingPathComponent("tagged_clean.jpg")

        #expect(output.contains("Removed photo info from 1"))
        #expect(FileManager.default.fileExists(atPath: cleaned.path))
        // The whole GPS dictionary (location) is gone.
        #expect(hasMetadata(cleaned, key: kCGImagePropertyGPSDictionary) == false)
        // Identifying EXIF fields (user comment, camera make/model) are gone. The
        // JPEG encoder always re-emits a baseline EXIF block with only technical
        // pixel fields (ColorSpace/PixelXDimension); that is not privacy data.
        #expect(exifField(cleaned, key: kCGImagePropertyExifUserComment) == nil)
        #expect(tiffField(cleaned, key: kCGImagePropertyTIFFMake) == nil)
        #expect(tiffField(cleaned, key: kCGImagePropertyTIFFModel) == nil)
    }

    @Test("Rotate 90 Clockwise swaps dimensions AND moves the source TOP edge to the RIGHT")
    func rotateSwapsDimensions() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("land.png")
        // White landscape image with a RED band along the TOP edge and the top-LEFT
        // corner marked GREEN. A correct 90-degree CLOCKWISE rotation puts the
        // source's TOP edge on the RIGHT, with the top-left end landing at the
        // BOTTOM-right corner. The OLD code drew off-canvas, so every pixel came
        // back transparent/black -- both the RED and GREEN assertions fail on it.
        try writeTopEdgeMarkedImage(width: 300, height: 100, to: source)

        let output = try AppStoreNativeActionExecutor.execute(.rotate90Clockwise, paths: [source.path])
        let rotated = root.appendingPathComponent("land_rotated.png")

        #expect(output.contains("Rotated 1"))
        let size = try #require(pixelSize(rotated))
        #expect(size.width == 100)
        #expect(size.height == 300)

        // The source TOP edge now runs down the RIGHT edge: sample top + bottom of
        // the right column. Both must be the (red/green) edge color, not white.
        let rightTop = try #require(visualPixelColor(rotated, x: size.width - 3, y: 3))
        #expect(rightTop.isRed, "expected the source top edge on the RIGHT (red at right-top), got \(rightTop)")
        // The top-LEFT corner of the source (green) lands at the BOTTOM-right.
        let rightBottom = try #require(visualPixelColor(rotated, x: size.width - 3, y: size.height - 3))
        #expect(rightBottom.isGreen, "expected the source top-left corner at BOTTOM-right, got \(rightBottom)")
        // The opposite (LEFT) edge of the rotated image must be plain white.
        let leftTop = try #require(visualPixelColor(rotated, x: 3, y: 3))
        #expect(leftTop.isWhite, "expected white on the LEFT after clockwise rotation, got \(leftTop)")
    }

    @Test("Resizing a non-PNG/JPEG (TIFF) source writes a valid PNG with a .png extension")
    func resizeNonPNGJPEGWritesValidPNG() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("scan.tiff")
        try writeImageFile(width: 400, height: 200, to: source, format: .tiff)

        let output = try AppStoreNativeActionExecutor.execute(.resize50, paths: [source.path])

        #expect(output.contains("Resized 1"))
        // Output is named .png (not .tiff), since loadOrientedImage re-encodes as PNG.
        let resized = root.appendingPathComponent("scan_half.png")
        #expect(FileManager.default.fileExists(atPath: resized.path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("scan_half.tiff").path) == false)
        // Bytes are a genuine PNG that round-trips through NSBitmapImageRep.
        let data = try Data(contentsOf: resized)
        let rep = try #require(NSBitmapImageRep(data: data))
        #expect(imageUTType(resized) == UTType.png.identifier)
        #expect(rep.pixelsWide == 200)
        #expect(rep.pixelsHigh == 100)
    }

    @Test("Thumbnailing a non-PNG/JPEG (TIFF) source writes a valid PNG with a .png extension")
    func thumbnailNonPNGJPEGWritesValidPNG() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("scan.tiff")
        try writeImageFile(width: 1024, height: 512, to: source, format: .tiff)

        let output = try AppStoreNativeActionExecutor.execute(.createThumbnail256, paths: [source.path])

        #expect(output.contains("Created 1"))
        let thumb = root.appendingPathComponent("scan_thumb.png")
        #expect(FileManager.default.fileExists(atPath: thumb.path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("scan_thumb.tiff").path) == false)
        let data = try Data(contentsOf: thumb)
        let rep = try #require(NSBitmapImageRep(data: data))
        #expect(imageUTType(thumb) == UTType.png.identifier)
        #expect(rep.pixelsWide == 256)
    }

    @Test("Convert to PNG bakes EXIF orientation so the result is upright (not sideways)")
    func convertToPNGBakesOrientation() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("portrait.jpg")
        // Stored pixels are 200x600 (landscape buffer) tagged orientation 6 (rotate
        // 90 CW to display upright) => the UPRIGHT image is 600x200. PNG ignores the
        // tag, so a correct conversion must BAKE it: output dims must be the upright
        // 600x200, not the raw stored 200x600.
        try writeOrientedJPEG(storedWidth: 200, storedHeight: 600, orientation: 6, to: source)

        let output = try AppStoreNativeActionExecutor.execute(.convertToPNG, paths: [source.path])
        let pngURL = root.appendingPathComponent("portrait.png")

        #expect(output.contains("Converted 1"))
        let size = try #require(pixelSize(pngURL))
        // Upright (oriented) dimensions, with the stored buffer's axes swapped.
        #expect(size.width == 600)
        #expect(size.height == 200)
        // The baked PNG carries no orientation tag (it is already upright).
        #expect(hasMetadata(pngURL, key: kCGImagePropertyOrientation) == false)
    }

    @Test("Create @2x Copy writes full-size @2x and half-size @1x")
    func retinaCopyCreatesBoth() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("icon.png")
        try writeImageFile(width: 200, height: 200, to: source, format: .png)

        let output = try AppStoreNativeActionExecutor.execute(.createRetinaCopy, paths: [source.path])
        let retina = root.appendingPathComponent("icon@2x.png")
        let standard = root.appendingPathComponent("icon@1x.png")

        #expect(output.contains("Created @2x and @1x copies for 1"))
        let retinaSize = try #require(pixelSize(retina))
        let standardSize = try #require(pixelSize(standard))
        #expect(retinaSize.width == 200)
        #expect(standardSize.width == 100)
        // Source is never modified.
        let sourceSize = try #require(pixelSize(source))
        #expect(sourceSize.width == 200)
    }

    @Test("Get Image Dimensions clipboards WxH for each image")
    func getDimensionsReturnsSize() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("measure.png")
        try writeImageFile(width: 640, height: 480, to: source, format: .png)

        let output = try AppStoreNativeActionExecutor.execute(.getImageDimensions, paths: [source.path])

        #expect(output.contains("measure.png: 640x480"))
        #expect(NSPasteboard.general.string(forType: .string) == output)
    }

    // MARK: - Image test helpers

    private enum TestImageFormat {
        case png, jpeg, heic, tiff

        var utType: UTType {
            switch self {
            case .png: .png
            case .jpeg: .jpeg
            case .heic: UTType("public.heic") ?? .jpeg
            case .tiff: .tiff
            }
        }
    }

    /// Write a solid-color image of the given pixel size in the requested format,
    /// optionally embedding a GPS dictionary so metadata-stripping can be proven.
    private func writeImageFile(
        width: Int,
        height: Int,
        to url: URL,
        format: TestImageFormat,
        includeGPS: Bool = false
    ) throws {
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
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let cgImage = context.makeImage() else {
            throw NSError(domain: "test", code: 2)
        }

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            format.utType.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "test", code: 3)
        }

        var properties: [CFString: Any] = [:]
        if includeGPS {
            properties[kCGImagePropertyGPSDictionary] = [
                kCGImagePropertyGPSLatitude: 37.7749,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 122.4194,
                kCGImagePropertyGPSLongitudeRef: "W"
            ] as CFDictionary
            properties[kCGImagePropertyExifDictionary] = [
                kCGImagePropertyExifUserComment: "test"
            ] as CFDictionary
        }

        CGImageDestinationAddImage(destination, cgImage, properties.isEmpty ? nil : properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "test", code: 4)
        }
    }

    /// Simple RGB sample with loose equality so PNG round-tripping doesn't flake
    /// the corner-pixel assertions.
    private struct SampledColor: CustomStringConvertible {
        let r: Int
        let g: Int
        let b: Int
        var isRed: Bool {
            r > 200 && g < 90 && b < 90
        }

        var isGreen: Bool {
            g > 200 && r < 90 && b < 90
        }

        var isWhite: Bool {
            r > 200 && g > 200 && b > 200
        }

        var description: String {
            "rgb(\(r), \(g), \(b))"
        }
    }

    /// Read one pixel from an image file using VISUAL coordinates: (0,0) is the
    /// TOP-LEFT, matching how the image displays. Decodes into a known RGBA8 byte
    /// buffer (CG origin bottom-left) and flips the row, which avoids the
    /// NSBitmapImageRep.colorAt quirk that returns transparent black for re-decoded
    /// PNGs.
    private func visualPixelColor(_ url: URL, x: Int, y: Int) -> SampledColor? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        guard x >= 0, x < width, y >= 0, y < height else { return nil }

        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Buffer row 0 is the CG bottom; flip so y counts from the visual top.
        let row = height - 1 - y
        let offset = (row * width + x) * 4
        return SampledColor(r: Int(buffer[offset]), g: Int(buffer[offset + 1]), b: Int(buffer[offset + 2]))
    }

    /// White landscape PNG with a RED band along the visual TOP edge and the
    /// top-LEFT end of that band marked GREEN, so a rotation's direction (which end
    /// of the top edge lands where) is unambiguous.
    private func writeTopEdgeMarkedImage(width: Int, height: Int, to url: URL) throws {
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
        let band = max(8, height / 5)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // CG origin is bottom-left, so the visual TOP edge is the high-y band.
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: height - band, width: width, height: band))
        // Mark the top-LEFT end of that band green.
        context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: height - band, width: max(8, width / 6), height: band))
        guard let cgImage = context.makeImage() else {
            throw NSError(domain: "test", code: 2)
        }
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "test", code: 3)
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "test", code: 4)
        }
    }

    /// Write a solid-color JPEG whose stored pixel buffer is `storedWidth` x
    /// `storedHeight` tagged with the given EXIF orientation. Used to prove that
    /// "Convert to PNG" bakes the orientation (PNG ignores the tag).
    private func writeOrientedJPEG(storedWidth: Int, storedHeight: Int, orientation: Int, to url: URL) throws {
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
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: storedWidth, height: storedHeight))
        guard let cgImage = context.makeImage() else {
            throw NSError(domain: "test", code: 2)
        }
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "test", code: 3)
        }
        let properties = [kCGImagePropertyOrientation: orientation] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "test", code: 4)
        }
    }

    private func pixelSize(_ url: URL) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    private func imageUTType(_ url: URL) -> String? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceGetType(source) as String?
    }

    private func hasMetadata(_ url: URL, key: CFString) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return false }
        return props[key] != nil
    }

    private func subdictionaryField(_ url: URL, dictionary: CFString, key: CFString) -> Any? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let sub = props[dictionary] as? [CFString: Any]
        else { return nil }
        return sub[key]
    }

    private func exifField(_ url: URL, key: CFString) -> Any? {
        subdictionaryField(url, dictionary: kCGImagePropertyExifDictionary, key: key)
    }

    private func tiffField(_ url: URL, key: CFString) -> Any? {
        subdictionaryField(url, dictionary: kCGImagePropertyTIFFDictionary, key: key)
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
