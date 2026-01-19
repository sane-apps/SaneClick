import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

    /// Shared file location via App Group container
    private var scriptsFileURL: URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "M78L6FXD48.group.com.sanescript.app") else {
            // Fallback to regular app support (won't work in sandbox, but useful for debugging)
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent("SaneScript/scripts.json")
        }
        return containerURL.appendingPathComponent("scripts.json")
    }

    override init() {
        super.init()

        // Watch all directories
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]

        // Listen for script changes from the host app
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

    @objc private func scriptsDidChange() {
        // Scripts have been updated - menu will rebuild on next request
    }

    // MARK: - Context Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "SaneScript")

        let scripts = loadScripts()
        let selectedURLs = FIFinderSyncController.default().selectedItemURLs() ?? []

        let applicableScripts = scripts.filter { script in
            guard script.isEnabled else { return false }

            // First check menu kind compatibility
            let menuKindMatch: Bool
            switch menuKind {
            case .contextualMenuForItems:
                menuKindMatch = script.appliesTo == "All Items" ||
                                script.appliesTo == "Files Only" ||
                                script.appliesTo == "Folders Only"
            case .contextualMenuForContainer:
                menuKindMatch = script.appliesTo == "Folder Background" ||
                                script.appliesTo == "All Items"
            case .contextualMenuForSidebar:
                menuKindMatch = script.appliesTo == "Folders Only" ||
                                script.appliesTo == "All Items"
            default:
                menuKindMatch = false
            }

            guard menuKindMatch else { return false }

            // Then check file extension filter
            return script.matchesFiles(selectedURLs)
        }

        for script in applicableScripts {
            let item = NSMenuItem(
                title: script.name,
                action: #selector(executeScript(_:)),
                keyEquivalent: ""
            )
            item.representedObject = script.id.uuidString
            item.image = NSImage(systemSymbolName: script.icon, accessibilityDescription: script.name)
            menu.addItem(item)
        }

        // Add separator and settings link if we have scripts
        if !applicableScripts.isEmpty {
            menu.addItem(.separator())
        }

        let settingsItem = NSMenuItem(
            title: "Open SaneScript...",
            action: #selector(openMainApp),
            keyEquivalent: ""
        )
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)

        return menu
    }

    @objc private func executeScript(_ sender: NSMenuItem) {
        guard let scriptIdString = sender.representedObject as? String,
              let items = FIFinderSyncController.default().selectedItemURLs() else {
            return
        }

        let paths = items.map { $0.path }

        // Encode paths to send to host app
        guard let pathsData = try? JSONEncoder().encode(paths) else { return }

        // Send execution request to host app
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.sanescript.executeScript"),
            object: nil,
            userInfo: [
                "scriptId": scriptIdString,
                "paths": pathsData
            ],
            deliverImmediately: true
        )

        // Also launch the host app to ensure it's running
        launchHostApp()
    }

    @objc private func openMainApp() {
        launchHostApp()
    }

    private func launchHostApp() {
        let appBundleId = "com.sanescript.SaneScript"
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appBundleId) {
            NSWorkspace.shared.openApplication(
                at: appURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }

    // MARK: - Script Loading

    private func loadScripts() -> [ExtensionScript] {
        guard FileManager.default.fileExists(atPath: scriptsFileURL.path),
              let data = try? Data(contentsOf: scriptsFileURL),
              let scripts = try? JSONDecoder().decode([ExtensionScript].self, from: data) else {
            return []
        }
        return scripts
    }
}

// MARK: - Script Model (Extension-local copy)

/// Lightweight script model for the extension
/// Must match the main app's Script model structure
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
        // Handle missing keys for backwards compatibility
        fileExtensions = try container.decodeIfPresent([String].self, forKey: .fileExtensions) ?? []
        extensionMatchMode = try container.decodeIfPresent(String.self, forKey: .extensionMatchMode) ?? "Any file matches"
        categoryId = try container.decodeIfPresent(UUID.self, forKey: .categoryId)
    }

    /// Check if this script matches the given file URLs
    func matchesFiles(_ urls: [URL]) -> Bool {
        guard !fileExtensions.isEmpty else { return true }

        let fileURLs = urls.filter { !$0.hasDirectoryPath }
        guard !fileURLs.isEmpty else {
            return appliesTo == "Folders Only" || appliesTo == "All Items"
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
