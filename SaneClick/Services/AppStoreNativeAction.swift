import AppKit
import CryptoKit
import Foundation
import ImageIO
import PDFKit
import Vision

enum AppStoreNativeAction: String, CaseIterable {
    case copyPath = "Copy Path"
    case copyFilename = "Copy Filename"
    case openInTerminal = "Open in Terminal"
    case newTextFile = "New Text File"
    case deleteDSStoreFiles = "Delete .DS_Store Files"
    case duplicateWithTimestamp = "Duplicate with Timestamp"
    case getFileInfo = "Get File Info"
    case revealInFinder = "Reveal in Finder"
    case makeExecutable = "Make Executable"
    case md5Hash = "MD5 Hash"
    case sha256Hash = "SHA256 Hash"
    case createFolderFromSelection = "Create Folder from Selection"
    case flattenFolder = "Flatten Folder"
    case organizeByExtension = "Organize by Extension"
    case organizeByDate = "Organize by Date"
    case renameWithSequence = "Rename with Sequence"
    case lowercaseFilenames = "Lowercase Filenames"
    case replaceSpacesWithUnderscores = "Replace Spaces with Underscores"
    // Native-only actions (no shell equivalent): these run through the native
    // executor on BOTH the direct and App Store builds.
    case copyTextFromImage = "Copy Text from Image"
    case saveTextFromImage = "Save Text from Image"
    case combineImagesIntoPDF = "Combine Images into PDF"
    case splitPDFIntoPages = "Split PDF into Pages"
    case pdfToImages = "PDF to Images"
    case copyFileURL = "Copy as File URL"
    case copyFilenameNoExtension = "Copy Filename without Extension"
    case copyParentPath = "Copy Parent Folder Path"
    case copyMarkdownLink = "Copy as Markdown Link"

    /// Actions that have no shell/AppleScript equivalent (OCR, PDF) or are
    /// cleaner native (path variants). These route through the native executor
    /// on the direct build as well as the App Store build.
    var requiresNativeRuntime: Bool {
        switch self {
        case .copyTextFromImage,
             .saveTextFromImage,
             .combineImagesIntoPDF,
             .splitPDFIntoPages,
             .pdfToImages,
             .copyFileURL,
             .copyFilenameNoExtension,
             .copyParentPath,
             .copyMarkdownLink:
            true
        case .copyPath,
             .copyFilename,
             .openInTerminal,
             .newTextFile,
             .deleteDSStoreFiles,
             .duplicateWithTimestamp,
             .getFileInfo,
             .revealInFinder,
             .makeExecutable,
             .md5Hash,
             .sha256Hash,
             .createFolderFromSelection,
             .flattenFolder,
             .organizeByExtension,
             .organizeByDate,
             .renameWithSequence,
             .lowercaseFilenames,
             .replaceSpacesWithUnderscores:
            false
        }
    }

    init?(script: Script) {
        guard let action = Self(rawValue: script.name),
              let libraryScript = ScriptLibrary.libraryScript(named: script.name),
              script.type == libraryScript.type,
              script.content == libraryScript.content
        else {
            return nil
        }

        self = action
    }
}

enum AppStoreActionCatalog {
    static let basicActions: [AppStoreNativeAction] = [
        .copyPath,
        .copyFilename,
        .openInTerminal,
        .newTextFile,
        .deleteDSStoreFiles,
        .duplicateWithTimestamp,
        .getFileInfo,
        .revealInFinder,
        .makeExecutable,
        .copyFileURL,
        .copyFilenameNoExtension,
        .copyParentPath,
        .copyMarkdownLink
    ]

    static let proActions: [AppStoreNativeAction] = [
        .md5Hash,
        .sha256Hash,
        .createFolderFromSelection,
        .flattenFolder,
        .organizeByExtension,
        .organizeByDate,
        .renameWithSequence,
        .lowercaseFilenames,
        .replaceSpacesWithUnderscores,
        .copyTextFromImage,
        .saveTextFromImage,
        .combineImagesIntoPDF,
        .splitPDFIntoPages,
        .pdfToImages
    ]
}

enum AppStoreNativeActionExecutor {
    static func execute(_ action: AppStoreNativeAction, paths: [String]) throws -> String {
        let urls = paths.map { URL(fileURLWithPath: $0).standardizedFileURL }
        switch action {
        case .copyPath:
            return try copyPath(urls)
        case .copyFilename:
            return try copyFilename(urls)
        case .openInTerminal:
            return try openInTerminal(urls)
        case .newTextFile:
            return try newTextFile(urls)
        case .deleteDSStoreFiles:
            return try deleteDSStoreFiles(urls)
        case .duplicateWithTimestamp:
            return try duplicateWithTimestamp(urls)
        case .getFileInfo:
            return try getFileInfo(urls)
        case .revealInFinder:
            return revealInFinder(urls)
        case .makeExecutable:
            return try makeExecutable(urls)
        case .md5Hash:
            return try hashFile(urls, algorithm: .md5)
        case .sha256Hash:
            return try hashFile(urls, algorithm: .sha256)
        case .createFolderFromSelection:
            return try createFolderFromSelection(urls)
        case .flattenFolder:
            return try flattenFolder(urls)
        case .organizeByExtension:
            return try organizeByExtension(urls)
        case .organizeByDate:
            return try organizeByDate(urls)
        case .renameWithSequence:
            return try renameWithSequence(urls)
        case .lowercaseFilenames:
            return try renameItems(urls) { $0.lowercased() }
        case .replaceSpacesWithUnderscores:
            return try renameItems(urls) { $0.replacingOccurrences(of: " ", with: "_") }
        case .copyTextFromImage:
            return try copyTextFromImage(urls)
        case .saveTextFromImage:
            return try saveTextFromImage(urls)
        case .combineImagesIntoPDF:
            return try combineImagesIntoPDF(urls)
        case .splitPDFIntoPages:
            return try splitPDFIntoPages(urls)
        case .pdfToImages:
            return try pdfToImages(urls)
        case .copyFileURL:
            return try copyFileURL(urls)
        case .copyFilenameNoExtension:
            return try copyFilenameNoExtension(urls)
        case .copyParentPath:
            return try copyParentPath(urls)
        case .copyMarkdownLink:
            return try copyMarkdownLink(urls)
        }
    }

    private static func copyPath(_ urls: [URL]) throws -> String {
        let paths = urls.map(\.path)
        try copyToPasteboard(paths.joined(separator: "\n"))
        return paths.joined(separator: "\n")
    }

    private static func copyFilename(_ urls: [URL]) throws -> String {
        guard let url = urls.first else {
            throw ScriptError.executionFailed("No item selected.")
        }

        let filename = url.lastPathComponent
        try copyToPasteboard(filename)
        return filename
    }

    private static func openInTerminal(_ urls: [URL]) throws -> String {
        guard let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            throw ScriptError.launchFailed("Terminal.app could not be found.")
        }

        let folders = urls.map(parentFolder(for:))
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        NSWorkspace.shared.open(folders, withApplicationAt: terminalURL, configuration: configuration)
        return "Opened \(folders.count) location(s) in Terminal."
    }

    private static func newTextFile(_ urls: [URL]) throws -> String {
        guard let url = urls.first else {
            throw ScriptError.executionFailed("No folder selected.")
        }

        let folderURL = parentFolder(for: url)
        let destinationURL = uniqueDestinationURL(
            in: folderURL,
            preferredName: "Untitled",
            pathExtension: "txt"
        )
        FileManager.default.createFile(atPath: destinationURL.path, contents: Data())
        return destinationURL.lastPathComponent
    }

    private static func deleteDSStoreFiles(_ urls: [URL]) throws -> String {
        var deleted = 0

        for url in urls {
            let root = parentFolder(for: url)
            if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) {
                for case let itemURL as URL in enumerator where itemURL.lastPathComponent == ".DS_Store" {
                    try FileManager.default.removeItem(at: itemURL)
                    deleted += 1
                }
            }
        }

        return "Deleted \(deleted) .DS_Store file(s)."
    }

    private static func duplicateWithTimestamp(_ urls: [URL]) throws -> String {
        let timestamp = timestampFormatter.string(from: Date())
        var created = 0

        for url in urls {
            let destinationURL = duplicatedItemURL(for: url, timestamp: timestamp)
            try FileManager.default.copyItem(at: url, to: destinationURL)
            created += 1
        }

        return "Created \(created) duplicate item(s)."
    }

    private static func getFileInfo(_ urls: [URL]) throws -> String {
        guard let url = urls.first else {
            throw ScriptError.executionFailed("No file selected.")
        }

        let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey, .fileSizeKey])
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let permissions = attributes[.posixPermissions] as? NSNumber
        let permissionString = permissions.map { String($0.intValue, radix: 8) } ?? "unknown"
        let sizeString = values.fileSize.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? "unknown"
        let created = values.creationDate.map(readableDateFormatter.string(from:)) ?? "unknown"
        let modified = values.contentModificationDate.map(readableDateFormatter.string(from:)) ?? "unknown"

        let info = [
            "Name: \(url.lastPathComponent)",
            "Path: \(url.path)",
            "Size: \(sizeString)",
            "Created: \(created)",
            "Modified: \(modified)",
            "Permissions: \(permissionString)"
        ].joined(separator: "\n")

        try copyToPasteboard(info)
        return info
    }

    private static func revealInFinder(_ urls: [URL]) -> String {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
        return "Revealed \(urls.count) item(s) in Finder."
    }

    private static func makeExecutable(_ urls: [URL]) throws -> String {
        var updated = 0

        for url in urls {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let existingPermissions = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0o644
            let newPermissions = existingPermissions | 0o111
            try FileManager.default.setAttributes([.posixPermissions: newPermissions], ofItemAtPath: url.path)
            updated += 1
        }

        return "Updated permissions for \(updated) item(s)."
    }

    private static func hashFile(_ urls: [URL], algorithm: HashAlgorithm) throws -> String {
        guard let url = urls.first else {
            throw ScriptError.executionFailed("No file selected.")
        }

        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let hash: String = switch algorithm {
        case .md5:
            Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case .sha256:
            SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }

        try copyToPasteboard(hash)
        return hash
    }

    private static func createFolderFromSelection(_ urls: [URL]) throws -> String {
        guard let firstURL = urls.first else {
            throw ScriptError.executionFailed("No items selected.")
        }

        let folderName = "New Folder \(folderDateFormatter.string(from: Date()))"
        let parentURL = firstURL.deletingLastPathComponent()
        let destinationFolder = uniqueDestinationURL(in: parentURL, preferredName: folderName)
        try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)

        for url in urls {
            let destinationURL = uniqueDestinationURL(in: destinationFolder, preferredName: url.deletingPathExtension().lastPathComponent, pathExtension: url.pathExtension)
            try FileManager.default.moveItem(at: url, to: destinationURL)
        }

        return destinationFolder.lastPathComponent
    }

    private static func flattenFolder(_ urls: [URL]) throws -> String {
        guard let folderURL = urls.first else {
            throw ScriptError.executionFailed("No folder selected.")
        }

        let rootURL = folderURL.standardizedFileURL
        let nestedFiles = try collectNestedRegularFiles(in: rootURL)
        var moved = 0

        for fileURL in nestedFiles {
            let destinationURL = uniqueDestinationURL(
                in: rootURL,
                preferredName: fileURL.deletingPathExtension().lastPathComponent,
                pathExtension: fileURL.pathExtension
            )
            try FileManager.default.moveItem(at: fileURL, to: destinationURL)
            moved += 1
        }

        try deleteEmptyDirectories(in: rootURL)
        return "Flattened \(moved) file(s)."
    }

    private static func organizeByExtension(_ urls: [URL]) throws -> String {
        guard let folderURL = urls.first else {
            throw ScriptError.executionFailed("No folder selected.")
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )

        var moved = 0
        for fileURL in contents where try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]).isRegularFile == true {
            guard try fileURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { continue }
            let ext = fileURL.pathExtension.lowercased()
            guard !ext.isEmpty else { continue }

            let targetDirectory = folderURL.appendingPathComponent(ext, isDirectory: true)
            try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
            let destinationURL = uniqueDestinationURL(
                in: targetDirectory,
                preferredName: fileURL.deletingPathExtension().lastPathComponent,
                pathExtension: fileURL.pathExtension
            )
            try FileManager.default.moveItem(at: fileURL, to: destinationURL)
            moved += 1
        }

        return "Organized \(moved) file(s) by extension."
    }

    private static func organizeByDate(_ urls: [URL]) throws -> String {
        guard let folderURL = urls.first else {
            throw ScriptError.executionFailed("No folder selected.")
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )

        var moved = 0
        for fileURL in contents where try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]).isRegularFile == true {
            guard try fileURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { continue }
            let values = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            let monthFolder = monthlyFolderFormatter.string(from: values.contentModificationDate ?? Date())
            let targetDirectory = folderURL.appendingPathComponent(monthFolder, isDirectory: true)
            try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
            let destinationURL = uniqueDestinationURL(
                in: targetDirectory,
                preferredName: fileURL.deletingPathExtension().lastPathComponent,
                pathExtension: fileURL.pathExtension
            )
            try FileManager.default.moveItem(at: fileURL, to: destinationURL)
            moved += 1
        }

        return "Organized \(moved) file(s) by date."
    }

    private static func renameWithSequence(_ urls: [URL]) throws -> String {
        let orderedURLs = urls.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        var stagedURLs: [(source: URL, staged: URL)] = []

        for url in orderedURLs {
            let stagedURL = uniqueDestinationURL(
                in: url.deletingLastPathComponent(),
                preferredName: ".saneclick-staged-\(UUID().uuidString)",
                pathExtension: url.pathExtension
            )
            try FileManager.default.moveItem(at: url, to: stagedURL)
            stagedURLs.append((source: url, staged: stagedURL))
        }

        for (index, entry) in stagedURLs.enumerated() {
            let ext = entry.source.pathExtension
            let baseName = String(format: "%03d", index + 1)
            let destinationURL = uniqueDestinationURL(
                in: entry.source.deletingLastPathComponent(),
                preferredName: baseName,
                pathExtension: ext
            )
            try FileManager.default.moveItem(at: entry.staged, to: destinationURL)
        }

        return "Renamed \(stagedURLs.count) file(s)."
    }

    private static func renameItems(_ urls: [URL], transform: (String) -> String) throws -> String {
        var renamed = 0

        for url in urls {
            let currentName = url.lastPathComponent
            let newName = transform(currentName)
            guard currentName != newName else { continue }

            let nameComponents = newName.split(separator: ".", omittingEmptySubsequences: false)
            let preferredName: String
            let pathExtension: String
            if nameComponents.count > 1 {
                pathExtension = String(nameComponents.last ?? "")
                preferredName = nameComponents.dropLast().joined(separator: ".")
            } else {
                preferredName = newName
                pathExtension = ""
            }

            let destinationURL = uniqueDestinationURL(
                in: url.deletingLastPathComponent(),
                preferredName: preferredName,
                pathExtension: pathExtension
            )
            try FileManager.default.moveItem(at: url, to: destinationURL)
            renamed += 1
        }

        return "Renamed \(renamed) item(s)."
    }

    // MARK: - OCR (Vision)

    private static func copyTextFromImage(_ urls: [URL]) throws -> String {
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

    private static func saveTextFromImage(_ urls: [URL]) throws -> String {
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

    private static func combineImagesIntoPDF(_ urls: [URL]) throws -> String {
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

    private static func splitPDFIntoPages(_ urls: [URL]) throws -> String {
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

    private static func pdfToImages(_ urls: [URL]) throws -> String {
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

    private static func imageURLsSortedByFilename(_ urls: [URL]) -> [URL] {
        urls
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp", "webp"
    ]

    // MARK: - Copy path variants

    private static func copyFileURL(_ urls: [URL]) throws -> String {
        guard !urls.isEmpty else {
            throw ScriptError.executionFailed("No item selected.")
        }
        let value = urls.map(\.absoluteString).joined(separator: "\n")
        try copyToPasteboard(value)
        return value
    }

    private static func copyFilenameNoExtension(_ urls: [URL]) throws -> String {
        guard let url = urls.first else {
            throw ScriptError.executionFailed("No item selected.")
        }
        let value = url.deletingPathExtension().lastPathComponent
        try copyToPasteboard(value)
        return value
    }

    private static func copyParentPath(_ urls: [URL]) throws -> String {
        guard let url = urls.first else {
            throw ScriptError.executionFailed("No item selected.")
        }
        let value = url.deletingLastPathComponent().path
        try copyToPasteboard(value)
        return value
    }

    private static func copyMarkdownLink(_ urls: [URL]) throws -> String {
        guard let url = urls.first else {
            throw ScriptError.executionFailed("No item selected.")
        }
        let value = "[\(url.lastPathComponent)](\(url.absoluteString))"
        try copyToPasteboard(value)
        return value
    }

    private static func copyToPasteboard(_ string: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(string, forType: .string) else {
            throw ScriptError.executionFailed("Failed to write to the clipboard.")
        }
    }

    private static func parentFolder(for url: URL) -> URL {
        url.hasDirectoryPath ? url : url.deletingLastPathComponent()
    }

    private static func duplicatedItemURL(for url: URL, timestamp: String) -> URL {
        let parentURL = url.deletingLastPathComponent()
        let name = url.deletingPathExtension().lastPathComponent
        let extensionString = url.pathExtension
        return uniqueDestinationURL(
            in: parentURL,
            preferredName: "\(name)_\(timestamp)",
            pathExtension: extensionString
        )
    }

    private static func uniqueDestinationURL(in directory: URL, preferredName: String, pathExtension: String = "") -> URL {
        let sanitizedName = preferredName.isEmpty ? "Untitled" : preferredName
        var candidate = directory.appendingPathComponent(sanitizedName, isDirectory: false)
        if !pathExtension.isEmpty {
            candidate.appendPathExtension(pathExtension)
        }

        guard !FileManager.default.fileExists(atPath: candidate.path) else {
            var counter = 2
            while true {
                let suffixedName = "\(sanitizedName)-\(counter)"
                candidate = directory.appendingPathComponent(suffixedName, isDirectory: false)
                if !pathExtension.isEmpty {
                    candidate.appendPathExtension(pathExtension)
                }
                if !FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
                counter += 1
            }
        }

        return candidate
    }

    private static func collectNestedRegularFiles(in rootURL: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let itemURL as URL in enumerator {
            guard itemURL.deletingLastPathComponent() != rootURL else { continue }
            let values = try itemURL.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                files.append(itemURL)
            }
        }

        return files
    }

    private static func deleteEmptyDirectories(in rootURL: URL) throws {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let directories = enumerator.compactMap { $0 as? URL }
            .sorted { $0.path.count > $1.path.count }

        for directoryURL in directories where directoryURL != rootURL {
            let values = try directoryURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { continue }
            let contents = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            if contents.isEmpty {
                try FileManager.default.removeItem(at: directoryURL)
            }
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    private static let folderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    private static let monthlyFolderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    private static let readableDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private enum HashAlgorithm {
        case md5
        case sha256
    }
}
