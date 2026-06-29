import AppKit
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import Vision

/// Media / image executors split out of AppStoreNativeAction.swift to keep each
/// component-owner file under the size limit (Rule #10). These run on the App
/// Store (sandboxed) build, where shelling out to `sips` is impossible, and also
/// back the OCR/PDF native-only actions on both builds. The matching shared
/// helpers (`uniqueDestinationURL`, `copyToPasteboard`) live in the main file.
///
/// Image actions always write to a NEW file via `uniqueDestinationURL`; they
/// never overwrite the source, even where the equivalent `sips` command edits in
/// place. The output naming/extension matches the sips behavior where the sips
/// command already produced a new file, and uses a clear suffix where sips edited
/// in place.
extension AppStoreNativeActionExecutor {
    // MARK: - OCR (Vision)

    static func copyTextFromImage(_ urls: [URL]) throws -> String {
        let images = imageURLsSortedByFilename(urls)
        guard !images.isEmpty else {
            throw ScriptError.executionFailed("No image selected.")
        }

        var lines: [String] = []
        for url in images {
            try lines.append(contentsOf: recognizeText(in: url))
        }

        let text = lines.joined(separator: "\n")
        guard !text.isEmpty else {
            return "No text found in the selected image(s)."
        }

        try copyToPasteboard(text)
        return text
    }

    static func saveTextFromImage(_ urls: [URL]) throws -> String {
        let images = imageURLsSortedByFilename(urls)
        guard !images.isEmpty else {
            throw ScriptError.executionFailed("No image selected.")
        }

        var written = 0
        for url in images {
            let lines = try recognizeText(in: url)
            let text = lines.joined(separator: "\n")
            guard !text.isEmpty else { continue }

            let destinationURL = uniqueDestinationURL(
                in: url.deletingLastPathComponent(),
                preferredName: url.deletingPathExtension().lastPathComponent,
                pathExtension: "txt"
            )
            try text.write(to: destinationURL, atomically: true, encoding: .utf8)
            written += 1
        }

        guard written > 0 else {
            return "No text found in the selected image(s)."
        }

        return "Saved text for \(written) image(s)."
    }

    private static func recognizeText(in url: URL) throws -> [String] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ScriptError.executionFailed("Could not read image: \(url.lastPathComponent)")
        }

        // Honor the image's EXIF/TIFF orientation so rotated photos and scans
        // (e.g. portrait iPhone shots) are OCR'd upright instead of sideways.
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawOrientation = (props?[kCGImagePropertyOrientation] as? UInt32) ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try handler.perform([request])

        guard let observations = request.results else { return [] }
        return observations.compactMap { $0.topCandidates(1).first?.string }
    }

    // MARK: - PDF (PDFKit)

    static func combineImagesIntoPDF(_ urls: [URL]) throws -> String {
        let images = imageURLsSortedByFilename(urls)
        guard let firstImage = images.first else {
            throw ScriptError.executionFailed("No image selected.")
        }

        let document = PDFDocument()
        var pageIndex = 0
        for url in images {
            guard let nsImage = NSImage(contentsOf: url),
                  let page = PDFPage(image: nsImage)
            else { continue }
            document.insert(page, at: pageIndex)
            pageIndex += 1
        }

        guard pageIndex > 0 else {
            throw ScriptError.executionFailed("None of the selected images could be read.")
        }

        let destinationURL = uniqueDestinationURL(
            in: firstImage.deletingLastPathComponent(),
            preferredName: "Combined",
            pathExtension: "pdf"
        )
        guard document.write(to: destinationURL) else {
            throw ScriptError.executionFailed("Failed to write the combined PDF.")
        }

        return "Created \(destinationURL.lastPathComponent) (\(pageIndex) page(s))."
    }

    static func splitPDFIntoPages(_ urls: [URL]) throws -> String {
        let pdfURL = try firstPDF(in: urls)
        guard let document = PDFDocument(url: pdfURL) else {
            throw ScriptError.executionFailed("Could not read PDF: \(pdfURL.lastPathComponent)")
        }

        let baseName = pdfURL.deletingPathExtension().lastPathComponent
        let directory = pdfURL.deletingLastPathComponent()
        var written = 0

        for index in 0 ..< document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let singlePageDocument = PDFDocument()
            guard let copiedPage = page.copy() as? PDFPage else { continue }
            singlePageDocument.insert(copiedPage, at: 0)

            let pageNumber = String(format: "%03d", index + 1)
            let destinationURL = uniqueDestinationURL(
                in: directory,
                preferredName: "\(baseName)-\(pageNumber)",
                pathExtension: "pdf"
            )
            if singlePageDocument.write(to: destinationURL) {
                written += 1
            }
        }

        guard written > 0 else {
            throw ScriptError.executionFailed("The PDF has no pages to split.")
        }

        return "Split into \(written) page(s)."
    }

    static func pdfToImages(_ urls: [URL]) throws -> String {
        let pdfURL = try firstPDF(in: urls)
        guard let document = PDFDocument(url: pdfURL) else {
            throw ScriptError.executionFailed("Could not read PDF: \(pdfURL.lastPathComponent)")
        }

        let baseName = pdfURL.deletingPathExtension().lastPathComponent
        let directory = pdfURL.deletingLastPathComponent()
        let dpi: CGFloat = 144
        let scale = dpi / 72
        var written = 0

        for index in 0 ..< document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            // `bounds` is the un-rotated mediaBox, but `thumbnail(of:for:)` applies
            // the page `/Rotate`. For 90/270 rotations, swap width/height so the
            // requested pixel size matches the rendered aspect ratio (no squish).
            var width = bounds.width
            var height = bounds.height
            if abs(page.rotation % 180) == 90 {
                swap(&width, &height)
            }
            let pixelSize = NSSize(width: width * scale, height: height * scale)
            guard pixelSize.width >= 1, pixelSize.height >= 1 else { continue }

            let thumbnail = page.thumbnail(of: pixelSize, for: .mediaBox)
            guard let tiffData = thumbnail.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:])
            else { continue }

            let pageNumber = String(format: "%03d", index + 1)
            let destinationURL = uniqueDestinationURL(
                in: directory,
                preferredName: "\(baseName)-\(pageNumber)",
                pathExtension: "png"
            )
            try pngData.write(to: destinationURL)
            written += 1
        }

        guard written > 0 else {
            throw ScriptError.executionFailed("The PDF has no pages to render.")
        }

        return "Rendered \(written) image(s)."
    }

    private static func firstPDF(in urls: [URL]) throws -> URL {
        guard let pdfURL = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else {
            throw ScriptError.executionFailed("No PDF selected.")
        }
        return pdfURL
    }

    // MARK: - Image conversion / transforms (ImageIO + CoreGraphics)

    enum ImageOutputFormat {
        case png
        case jpeg

        var pathExtension: String {
            switch self {
            case .png: "png"
            case .jpeg: "jpg"
            }
        }

        var utType: UTType {
            switch self {
            case .png: .png
            case .jpeg: .jpeg
            }
        }
    }

    /// Convert images to PNG/JPEG. Mirrors `sips -s format png/jpeg ... --out`:
    /// writes a sibling file with the new extension (e.g. `photo.png`). JPEG uses
    /// 0.85 quality to match `sips -s formatOptions 85` / a sensible HEIC export.
    /// Pixels and EXIF orientation are passed through unchanged (the displayed
    /// image is identical, only the container format changes).
    static func convertImages(
        _ urls: [URL],
        to format: ImageOutputFormat,
        sourceExtensions: Set<String>? = nil
    ) throws -> String {
        let images = imageURLsSortedByFilename(urls).filter { url in
            guard let allowed = sourceExtensions else { return true }
            return allowed.contains(url.pathExtension.lowercased())
        }
        guard !images.isEmpty else {
            throw ScriptError.executionFailed("No image selected.")
        }

        var converted = 0
        var lastError: Error?
        for url in images {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                lastError = ScriptError.executionFailed("Could not read image: \(url.lastPathComponent)")
                continue
            }

            let sourceProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let rawOrientation = (sourceProps?[kCGImagePropertyOrientation] as? UInt32) ?? 1

            do {
                let outputImage: CGImage
                var properties: [CFString: Any] = [:]
                if format == .jpeg {
                    // JPEG honors the orientation tag, so pass the raw pixels +
                    // tag through (matches sips, smaller files).
                    outputImage = cgImage
                    if rawOrientation != 1 {
                        properties[kCGImagePropertyOrientation] = rawOrientation
                    }
                    properties[kCGImageDestinationLossyCompressionQuality] = 0.85
                } else {
                    // PNG does NOT honor the orientation tag, so an orientation-
                    // tagged source would display sideways. Bake the orientation
                    // into the pixels and write upright with no tag.
                    outputImage = try bakeOrientation(cgImage, rawOrientation: rawOrientation)
                }

                let destinationURL = uniqueDestinationURL(
                    in: url.deletingLastPathComponent(),
                    preferredName: url.deletingPathExtension().lastPathComponent,
                    pathExtension: format.pathExtension
                )
                try writeImage(outputImage, to: destinationURL, format: format, properties: properties)
                converted += 1
            } catch {
                lastError = error
                continue
            }
        }

        guard converted > 0 else {
            throw lastError ?? ScriptError.executionFailed("None of the selected images could be converted.")
        }

        return "Converted \(converted) image(s)."
    }

    /// Resize by `scale` (e.g. 0.5) or to a fixed `maxWidth`. Mirrors
    /// `sips --resampleWidth` (which preserves aspect ratio) but writes a NEW
    /// suffixed file instead of editing the source in place.
    static func resizeImages(
        _ urls: [URL],
        scale: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        suffix: String
    ) throws -> String {
        let images = imageURLsSortedByFilename(urls)
        guard !images.isEmpty else {
            throw ScriptError.executionFailed("No image selected.")
        }

        var resized = 0
        var lastError: Error?
        for url in images {
            do {
                let (cgImage, format) = try loadOrientedImage(url)
                let currentWidth = CGFloat(cgImage.width)
                let targetWidth: CGFloat = if let scale {
                    max(1, (currentWidth * scale).rounded())
                } else {
                    max(1, maxWidth ?? currentWidth)
                }
                let targetHeight = max(1, (CGFloat(cgImage.height) * (targetWidth / currentWidth)).rounded())

                let scaled = try drawScaled(cgImage, width: Int(targetWidth), height: Int(targetHeight))
                let destinationURL = suffixedDestination(for: url, suffix: suffix, pathExtension: format.pathExtension)
                try writeImage(scaled, to: destinationURL, format: format, properties: [:])
                resized += 1
            } catch {
                lastError = error
                continue
            }
        }

        guard resized > 0 else {
            throw lastError ?? ScriptError.executionFailed("None of the selected images could be resized.")
        }

        return "Resized \(resized) image(s)."
    }

    /// Create a thumbnail that fits within `maxDimension` on its longest side,
    /// preserving aspect ratio and never upscaling (matches `sips -Z`). Writes
    /// `name_thumb.ext` next to the source.
    static func createThumbnails(_ urls: [URL], maxDimension: CGFloat) throws -> String {
        let images = imageURLsSortedByFilename(urls)
        guard !images.isEmpty else {
            throw ScriptError.executionFailed("No image selected.")
        }

        var created = 0
        var lastError: Error?
        for url in images {
            do {
                let (cgImage, format) = try loadOrientedImage(url)
                let longestSide = CGFloat(max(cgImage.width, cgImage.height))
                let ratio = min(1, maxDimension / longestSide)
                let targetWidth = max(1, (CGFloat(cgImage.width) * ratio).rounded())
                let targetHeight = max(1, (CGFloat(cgImage.height) * ratio).rounded())

                let scaled = try drawScaled(cgImage, width: Int(targetWidth), height: Int(targetHeight))
                let destinationURL = uniqueDestinationURL(
                    in: url.deletingLastPathComponent(),
                    preferredName: url.deletingPathExtension().lastPathComponent + "_thumb",
                    pathExtension: format.pathExtension
                )
                try writeImage(scaled, to: destinationURL, format: format, properties: [:])
                created += 1
            } catch {
                lastError = error
                continue
            }
        }

        guard created > 0 else {
            throw lastError ?? ScriptError.executionFailed("None of the selected images could be thumbnailed.")
        }

        return "Created \(created) thumbnail(s)."
    }

    /// Re-encode WITHOUT any metadata (no EXIF/GPS/TIFF dictionaries), matching
    /// the intent of the sips re-encode but guaranteeing the metadata is dropped.
    /// Writes a `name_clean.ext` sibling instead of overwriting the source.
    static func removePhotoInfo(_ urls: [URL]) throws -> String {
        let images = imageURLsSortedByFilename(urls)
        guard !images.isEmpty else {
            throw ScriptError.executionFailed("No image selected.")
        }

        var cleaned = 0
        var lastError: Error?
        for url in images {
            do {
                // Bake orientation into the pixels and write with orientation .up so
                // we can safely drop the EXIF/TIFF dictionaries (which carried it)
                // without the image rotating.
                let (cgImage, format) = try loadOrientedImage(url)
                let destinationURL = uniqueDestinationURL(
                    in: url.deletingLastPathComponent(),
                    preferredName: url.deletingPathExtension().lastPathComponent + "_clean",
                    pathExtension: format.pathExtension
                )
                // No properties dictionary => destination writes no metadata.
                try writeImage(cgImage, to: destinationURL, format: format, properties: [:])
                cleaned += 1
            } catch {
                lastError = error
                continue
            }
        }

        guard cleaned > 0 else {
            throw lastError ?? ScriptError.executionFailed("None of the selected images could be cleaned.")
        }

        return "Removed photo info from \(cleaned) image(s)."
    }

    /// Rotate 90 degrees clockwise (matches `sips -r 90`). Bakes any existing
    /// orientation first, rotates the pixels, and writes a `name_rotated.ext`
    /// sibling with orientation `.up`.
    static func rotateImagesClockwise(_ urls: [URL]) throws -> String {
        let images = imageURLsSortedByFilename(urls)
        guard !images.isEmpty else {
            throw ScriptError.executionFailed("No image selected.")
        }

        var rotated = 0
        var lastError: Error?
        for url in images {
            do {
                let (cgImage, format) = try loadOrientedImage(url)
                let turned = try rotate90Clockwise(cgImage)
                let destinationURL = suffixedDestination(for: url, suffix: "_rotated", pathExtension: format.pathExtension)
                try writeImage(turned, to: destinationURL, format: format, properties: [:])
                rotated += 1
            } catch {
                lastError = error
                continue
            }
        }

        guard rotated > 0 else {
            throw lastError ?? ScriptError.executionFailed("None of the selected images could be rotated.")
        }

        return "Rotated \(rotated) image(s)."
    }

    /// Create retina assets from PNGs. The sips version copies the source to
    /// `name@2x.png` (the full-size retina asset) then shrinks the original to
    /// 50% (the @1x). Native is non-destructive, so it writes BOTH a full-size
    /// `name@2x.png` and a half-size `name@1x.png` and leaves the source intact.
    static func createRetinaCopies(_ urls: [URL]) throws -> String {
        let images = imageURLsSortedByFilename(urls).filter { $0.pathExtension.lowercased() == "png" }
        guard !images.isEmpty else {
            throw ScriptError.executionFailed("No PNG image selected.")
        }

        var created = 0
        var lastError: Error?
        for url in images {
            do {
                let (cgImage, format) = try loadOrientedImage(url)
                let baseName = url.deletingPathExtension().lastPathComponent

                // Full-size copy is the @2x retina asset.
                let retinaURL = uniqueDestinationURL(
                    in: url.deletingLastPathComponent(),
                    preferredName: baseName + "@2x",
                    pathExtension: format.pathExtension
                )
                try writeImage(cgImage, to: retinaURL, format: format, properties: [:])

                // Half-size copy is the @1x asset.
                let halfWidth = max(1, (CGFloat(cgImage.width) * 0.5).rounded())
                let halfHeight = max(1, (CGFloat(cgImage.height) * 0.5).rounded())
                let scaled = try drawScaled(cgImage, width: Int(halfWidth), height: Int(halfHeight))
                let standardURL = uniqueDestinationURL(
                    in: url.deletingLastPathComponent(),
                    preferredName: baseName + "@1x",
                    pathExtension: format.pathExtension
                )
                try writeImage(scaled, to: standardURL, format: format, properties: [:])
                created += 1
            } catch {
                lastError = error
                continue
            }
        }

        guard created > 0 else {
            throw lastError ?? ScriptError.executionFailed("None of the selected images could be copied.")
        }

        return "Created @2x and @1x copies for \(created) image(s)."
    }

    /// Read pixel dimensions and copy `name: WxH` lines to the clipboard
    /// (matches the sips `pixelWidth`/`pixelHeight` read, shown to the user).
    static func getImageDimensions(_ urls: [URL]) throws -> String {
        let images = imageURLsSortedByFilename(urls)
        guard !images.isEmpty else {
            throw ScriptError.executionFailed("No image selected.")
        }

        var lines: [String] = []
        for url in images {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = props[kCGImagePropertyPixelWidth] as? Int,
                  let height = props[kCGImagePropertyPixelHeight] as? Int
            else {
                throw ScriptError.executionFailed("Could not read image: \(url.lastPathComponent)")
            }
            lines.append("\(url.lastPathComponent): \(width)x\(height)")
        }

        let text = lines.joined(separator: "\n")
        try copyToPasteboard(text)
        return text
    }

    // MARK: - Image helpers

    /// Load a CGImage with its EXIF orientation baked into the pixels (so width,
    /// height, and transforms are correct) and report the output format to use
    /// when writing it back (JPEG sources stay JPEG, everything else writes PNG).
    private static func loadOrientedImage(_ url: URL) throws -> (CGImage, ImageOutputFormat) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ScriptError.executionFailed("Could not read image: \(url.lastPathComponent)")
        }

        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawOrientation = (props?[kCGImagePropertyOrientation] as? UInt32) ?? 1
        let oriented = try bakeOrientation(cgImage, rawOrientation: rawOrientation)

        let ext = url.pathExtension.lowercased()
        let format: ImageOutputFormat = (ext == "jpg" || ext == "jpeg") ? .jpeg : .png
        return (oriented, format)
    }

    /// Redraw `cgImage` applying the EXIF orientation so the returned image is
    /// visually upright with orientation `.up`.
    private static func bakeOrientation(_ cgImage: CGImage, rawOrientation: UInt32) throws -> CGImage {
        guard rawOrientation != 1 else { return cgImage }

        let width = cgImage.width
        let height = cgImage.height
        // Orientations 5-8 swap the axes.
        let swapsAxes = rawOrientation >= 5
        let outWidth = swapsAxes ? height : width
        let outHeight = swapsAxes ? width : height

        guard let context = CGContext(
            data: nil,
            width: outWidth,
            height: outHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ScriptError.executionFailed("Could not allocate image context.")
        }

        // Build the transform that maps oriented output space back to the stored
        // pixels, then draw the original into the upright canvas.
        var transform = CGAffineTransform.identity
        let w = CGFloat(width)
        let h = CGFloat(height)
        switch rawOrientation {
        case 2: // horizontal flip
            transform = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: w, ty: 0)
        case 3: // 180
            transform = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: w, ty: h)
        case 4: // vertical flip
            transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: h)
        case 5: // transpose
            transform = CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
        case 6: // rotate 90 CW
            transform = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: w)
        case 7: // transverse
            transform = CGAffineTransform(a: 0, b: -1, c: -1, d: 0, tx: h, ty: w)
        case 8: // rotate 90 CCW
            transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: h, ty: 0)
        default:
            transform = .identity
        }

        context.concatenate(transform)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let result = context.makeImage() else {
            throw ScriptError.executionFailed("Could not bake image orientation.")
        }
        return result
    }

    private static func drawScaled(_ cgImage: CGImage, width: Int, height: Int) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ScriptError.executionFailed("Could not allocate image context.")
        }
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let result = context.makeImage() else {
            throw ScriptError.executionFailed("Could not resize the image.")
        }
        return result
    }

    private static func rotate90Clockwise(_ cgImage: CGImage) throws -> CGImage {
        let width = cgImage.width
        let height = cgImage.height
        // Output dimensions are swapped for a 90-degree rotation.
        guard let context = CGContext(
            data: nil,
            width: height,
            height: width,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ScriptError.executionFailed("Could not allocate image context.")
        }

        // Clockwise rotation in CoreGraphics' bottom-left origin space. The
        // output context is height-wide x width-tall; this transform maps the
        // source pixels onto it so the source's TOP edge lands on the RIGHT.
        context.translateBy(x: 0, y: CGFloat(width))
        context.rotate(by: -.pi / 2)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        guard let result = context.makeImage() else {
            throw ScriptError.executionFailed("Could not rotate the image.")
        }
        return result
    }

    private static func writeImage(
        _ cgImage: CGImage,
        to url: URL,
        format: ImageOutputFormat,
        properties: [CFString: Any]
    ) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            format.utType.identifier as CFString,
            1,
            nil
        ) else {
            throw ScriptError.executionFailed("Could not create output image: \(url.lastPathComponent)")
        }
        CGImageDestinationAddImage(destination, cgImage, properties.isEmpty ? nil : properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ScriptError.executionFailed("Could not write image: \(url.lastPathComponent)")
        }
    }

    /// Build a suffixed sibling destination. The extension comes from the OUTPUT
    /// `format`, not the source — `loadOrientedImage` re-encodes any non-JPEG
    /// source as PNG, so a `.heic`/`.tiff`/etc. input must be named `*.png` to
    /// avoid writing PNG bytes into a mislabeled container.
    private static func suffixedDestination(for url: URL, suffix: String, pathExtension: String) -> URL {
        uniqueDestinationURL(
            in: url.deletingLastPathComponent(),
            preferredName: url.deletingPathExtension().lastPathComponent + suffix,
            pathExtension: pathExtension
        )
    }

    // MARK: - Shared image selection

    static func imageURLsSortedByFilename(_ urls: [URL]) -> [URL] {
        urls
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp", "webp"
    ]
}
