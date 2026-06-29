import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import PDFKit
@testable import SaneClick
import Testing
import UniformTypeIdentifiers

/// Image conversion / transform tests for the native executor. Split out of
/// AppStoreNativeActionTests so each test component owner stays under the size
/// limit (Rule #10). These exercise the native-preferred image actions, which
/// now run through the native engine on BOTH builds (non-destructive: they
/// always write a new file and never edit the original).
struct AppStoreNativeActionMediaTests {
    @Test("Each ported image action matches its library entry via init(script:)")
    func portedImageActionsMatchLibrary() throws {
        let ported: [AppStoreNativeAction] = [
            .convertToPNG, .convertToJPEG, .heicToJPEG, .resize50, .resizeTo1920,
            .createThumbnail256, .removePhotoInfo, .rotate90Clockwise, .createRetinaCopy,
            .getImageDimensions,
        ]
        for action in ported {
            let library = try #require(ScriptLibrary.libraryScript(named: action.rawValue))
            #expect(AppStoreNativeAction(script: library.toScript()) == action, "\(action.rawValue) should match")
            // These keep their sips bash content for identity matching, but now run
            // through the native engine on both builds (non-destructive).
            #expect(action.requiresNativeRuntime == true, "\(action.rawValue) must run via the native engine")
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
                kCGImagePropertyGPSLongitudeRef: "W",
            ] as CFDictionary
            properties[kCGImagePropertyExifDictionary] = [
                kCGImagePropertyExifUserComment: "test",
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
}
