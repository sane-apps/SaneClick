//
//  FinderSync.swift
//  SaneClickExtension
//
//  Finder Sync Extension for SaneClick
//

import Cocoa
import FinderSync
import os.log

private let logger = Logger(subsystem: "com.saneclick.SaneClick.FinderSync", category: "FinderSync")

/// Execution request written to App Group container for host app to process
struct ExecutionRequest: Codable {
    let scriptId: UUID
    let paths: [String]
    let timestamp: Date
    let requestId: UUID  // Unique ID to prevent duplicate processing

    init(scriptId: UUID, paths: [String], timestamp: Date = Date(), requestId: UUID = UUID()) {
        self.scriptId = scriptId
        self.paths = paths
        self.timestamp = timestamp
        self.requestId = requestId
    }
}

class FinderSync: FIFinderSync {

    /// Scripts available for current menu
    private var currentScripts: [ExtensionScript] = []

    private var scriptsFileURL: URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "M78L6FXD48.group.com.saneclick.app") else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent("SaneClick/scripts.json")
        }
        return containerURL.appendingPathComponent("scripts.json")
    }

    override init() {
        super.init()
        logger.info("FinderSync extension init() called")

        let finderSync = FIFinderSyncController.default()
        if let mountedVolumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) {
            finderSync.directoryURLs = Set(mountedVolumes)
            logger.info("Set directoryURLs to \(mountedVolumes.count) volumes")
        } else {
            finderSync.directoryURLs = [URL(fileURLWithPath: "/")]
            logger.warning("mountedVolumeURLs returned nil, using root /")
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let volumeURL = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL {
                FIFinderSyncController.default().directoryURLs.insert(volumeURL)
            }
        }

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(scriptsDidChange),
            name: NSNotification.Name("com.saneclick.scriptsChanged"),
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func scriptsDidChange() {}

    // MARK: - Context Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        logger.info("menu(for:) called with menuKind: \(String(describing: menuKind))")
        let menu = NSMenu(title: "SaneClick")

        let scripts = loadScripts()
        let selectedURLs = resolvedSelectionURLs()
        let selectionCount = selectedURLs.count

        let applicableScripts = scripts.filter { script in
            guard script.isEnabled else { return false }

            let menuKindMatch: Bool
            switch menuKind {
            case .contextualMenuForItems:
                menuKindMatch = script.appliesTo == "Files & Folders" ||
                                script.appliesTo == "Files Only" ||
                                script.appliesTo == "Folders Only"
            case .contextualMenuForContainer:
                menuKindMatch = script.appliesTo == "Inside Folder" ||
                                script.appliesTo == "Files & Folders"
            case .contextualMenuForSidebar:
                menuKindMatch = script.appliesTo == "Folders Only" ||
                                script.appliesTo == "Files & Folders"
            default:
                menuKindMatch = false
            }

            guard menuKindMatch else { return false }
            guard script.matchesSelectionCount(selectionCount) else { return false }
            return script.matchesFiles(selectedURLs)
        }

        self.currentScripts = applicableScripts
        for (index, script) in applicableScripts.enumerated() {
            let item = NSMenuItem(title: script.name, action: #selector(executeScript(_:)), keyEquivalent: "")
            item.tag = index
            item.image = tintedSFSymbol(name: script.icon, accessibilityDescription: script.name)
            menu.addItem(item)
        }

        if !applicableScripts.isEmpty {
            menu.addItem(.separator())
        }

        let settingsItem = NSMenuItem(title: "Open SaneClick...", action: #selector(openMainApp), keyEquivalent: "")
        settingsItem.image = tintedSFSymbol(name: "gearshape", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)

        return menu
    }

    @objc func executeScript(_ sender: AnyObject?) {
        guard let menuItem = sender as? NSMenuItem else { return }

        let tag = menuItem.tag
        guard tag >= 0, tag < currentScripts.count else { return }
        let script = currentScripts[tag]

        let items = resolvedSelectionURLs()
        guard !items.isEmpty else { return }
        let paths = items.map { $0.path }

        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "M78L6FXD48.group.com.saneclick.app"
        ) else { return }

        let pendingURL = containerURL.appendingPathComponent("pending_execution.json")
        let request = ExecutionRequest(scriptId: script.id, paths: paths, timestamp: Date())

        do {
            let data = try JSONEncoder().encode(request)
            try data.write(to: pendingURL, options: .atomic)
        } catch {
            return
        }

        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.saneclick.executeScript"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )

        ensureHostAppRunning()
    }

    @objc func openMainApp() {
        launchHostApp(activate: true)
    }

    private func ensureHostAppRunning() {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.saneclick.SaneClick")
        if running.isEmpty {
            launchHostApp(activate: false)
        }
    }

    private func launchHostApp(activate: Bool) {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.saneclick.SaneClick") {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = activate
            configuration.addsToRecentItems = false
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
        }
    }

    private func resolvedSelectionURLs() -> [URL] {
        let controller = FIFinderSyncController.default()
        let selected = controller.selectedItemURLs() ?? []
        if !selected.isEmpty {
            return selected
        }
        if let targeted = controller.targetedURL() {
            return [targeted]
        }
        return []
    }

    private func loadScripts() -> [ExtensionScript] {
        guard FileManager.default.fileExists(atPath: scriptsFileURL.path),
              let data = try? Data(contentsOf: scriptsFileURL),
              let scripts = try? JSONDecoder().decode([ExtensionScript].self, from: data) else {
            return []
        }
        return scripts
    }

    /// Render an SF Symbol as a tinted bitmap image.
    /// Finder forces template rendering on NSMenuItem images, so we rasterize
    /// with a palette color configuration to produce a non-template bitmap.
    private func tintedSFSymbol(name: String, accessibilityDescription: String?) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription) else {
            return nil
        }

        // Apply palette color so the symbol renders with a specific color
        let config = NSImage.SymbolConfiguration(paletteColors: [.controlAccentColor])
        guard let colored = symbol.withSymbolConfiguration(config) else { return nil }

        // Rasterize into a bitmap so Finder cannot re-template it
        let size = NSSize(width: 16, height: 16)
        let bitmap = NSImage(size: size, flipped: false) { rect in
            colored.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
            return true
        }
        bitmap.isTemplate = false
        return bitmap
    }
}

// MARK: - Script Model

struct ExtensionScript: Codable {
    let id: UUID
    var name: String
    var type: String
    var content: String
    var isEnabled: Bool
    var icon: String
    var appliesTo: String
    var fileExtensions: [String]
    var extensionMatchMode: String
    var minSelection: Int
    var maxSelection: Int?
    var categoryId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, name, type, content, isEnabled, icon, appliesTo, fileExtensions, extensionMatchMode, minSelection, maxSelection, categoryId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        content = try container.decode(String.self, forKey: .content)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        icon = try container.decode(String.self, forKey: .icon)
        appliesTo = try container.decode(String.self, forKey: .appliesTo)
        fileExtensions = try container.decodeIfPresent([String].self, forKey: .fileExtensions) ?? []
        extensionMatchMode = try container.decodeIfPresent(String.self, forKey: .extensionMatchMode) ?? "Any file matches"
        minSelection = try container.decodeIfPresent(Int.self, forKey: .minSelection) ?? 1
        maxSelection = try container.decodeIfPresent(Int.self, forKey: .maxSelection)
        categoryId = try container.decodeIfPresent(UUID.self, forKey: .categoryId)
    }

    func matchesFiles(_ urls: [URL]) -> Bool {
        guard !fileExtensions.isEmpty else { return true }

        let fileURLs = urls.filter { !$0.hasDirectoryPath }
        guard !fileURLs.isEmpty else {
            return appliesTo == "Folders Only" || appliesTo == "Files & Folders"
        }

        let normalizedExtensions = Set(fileExtensions.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) })

        if extensionMatchMode == "Show only if all selected files match" {
            return fileURLs.allSatisfy { url in
                normalizedExtensions.contains(url.pathExtension.lowercased())
            }
        } else {
            return fileURLs.contains { url in
                normalizedExtensions.contains(url.pathExtension.lowercased())
            }
        }
    }

    func matchesSelectionCount(_ count: Int) -> Bool {
        if count < minSelection {
            return false
        }
        if let maxSelection, count > maxSelection {
            return false
        }
        return true
    }
}
