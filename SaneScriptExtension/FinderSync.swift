//
//  FinderSync.swift
//  SaneScriptExtension
//
//  Finder Sync Extension for SaneClick
//

import Cocoa
import FinderSync

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
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "M78L6FXD48.group.com.sanescript.app") else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent("SaneScript/scripts.json")
        }
        return containerURL.appendingPathComponent("scripts.json")
    }

    override init() {
        super.init()

        let finderSync = FIFinderSyncController.default()
        if let mountedVolumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) {
            finderSync.directoryURLs = Set(mountedVolumes)
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
            name: NSNotification.Name("com.sanescript.scriptsChanged"),
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func scriptsDidChange() {}

    // MARK: - Context Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "SaneScript")

        let scripts = loadScripts()
        let selectedURLs = FIFinderSyncController.default().selectedItemURLs() ?? []

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
            return script.matchesFiles(selectedURLs)
        }

        self.currentScripts = applicableScripts
        for (index, script) in applicableScripts.enumerated() {
            let item = NSMenuItem(title: script.name, action: #selector(executeScript(_:)), keyEquivalent: "")
            item.tag = index
            item.image = NSImage(systemSymbolName: script.icon, accessibilityDescription: script.name)
            menu.addItem(item)
        }

        if !applicableScripts.isEmpty {
            menu.addItem(.separator())
        }

        let settingsItem = NSMenuItem(title: "Open SaneClick...", action: #selector(openMainApp), keyEquivalent: "")
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)

        return menu
    }

    @objc func executeScript(_ sender: AnyObject?) {
        guard let menuItem = sender as? NSMenuItem else { return }

        let tag = menuItem.tag
        guard tag >= 0, tag < currentScripts.count else { return }
        let script = currentScripts[tag]

        guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }
        let paths = items.map { $0.path }

        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "M78L6FXD48.group.com.sanescript.app"
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
            NSNotification.Name("com.sanescript.executeScript"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )

        launchHostApp()
    }

    @objc func openMainApp() {
        launchHostApp()
    }

    private func launchHostApp() {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.sanescript.SaneScript") {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private func loadScripts() -> [ExtensionScript] {
        guard FileManager.default.fileExists(atPath: scriptsFileURL.path),
              let data = try? Data(contentsOf: scriptsFileURL),
              let scripts = try? JSONDecoder().decode([ExtensionScript].self, from: data) else {
            return []
        }
        return scripts
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
    var categoryId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, name, type, content, isEnabled, icon, appliesTo, fileExtensions, extensionMatchMode, categoryId
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
        categoryId = try container.decodeIfPresent(UUID.self, forKey: .categoryId)
    }

    func matchesFiles(_ urls: [URL]) -> Bool {
        guard !fileExtensions.isEmpty else { return true }

        let fileURLs = urls.filter { !$0.hasDirectoryPath }
        guard !fileURLs.isEmpty else {
            return appliesTo == "Folders Only" || appliesTo == "Files & Folders"
        }

        let normalizedExtensions = Set(fileExtensions.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) })

        if extensionMatchMode == "All files match" {
            return fileURLs.allSatisfy { url in
                normalizedExtensions.contains(url.pathExtension.lowercased())
            }
        } else {
            return fileURLs.contains { url in
                normalizedExtensions.contains(url.pathExtension.lowercased())
            }
        }
    }
}
