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
private let openMainWindowNotification = NSNotification.Name("com.saneclick.openMainWindow")

/// Execution request written to App Group container for host app to process
struct ExecutionRequest: Codable {
    let scriptId: UUID
    let paths: [String]
    let timestamp: Date
    let requestId: UUID // Unique ID to prevent duplicate processing

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

    private var categoriesFileURL: URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "M78L6FXD48.group.com.saneclick.app") else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent("SaneClick/categories.json")
        }
        return containerURL.appendingPathComponent("categories.json")
    }

    override init() {
        super.init()
        logger.info("FinderSync extension init() called")

        reloadMonitoredFolders()

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.reloadMonitoredFolders()
        }

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(scriptsDidChange),
            name: NSNotification.Name("com.saneclick.scriptsChanged"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(monitoredFoldersDidChange),
            name: MonitoredFolders.changedNotification,
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func scriptsDidChange() {}

    @objc private func monitoredFoldersDidChange() {
        reloadMonitoredFolders()
    }

    private func reloadMonitoredFolders() {
        let urls = Set(MonitoredFolders.monitoredURLs())
        FIFinderSyncController.default().directoryURLs = urls
        logger.info("Reloaded monitored folders: \(urls.count)")
    }

    // MARK: - Context Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        logger.info("menu(for:) called with menuKind: \(String(describing: menuKind))")
        let menu = NSMenu(title: "SaneClick")

        let scripts = loadScripts()
        let selectedURLs = resolvedSelectionURLs()
        let selectionCount = selectedURLs.count

        let applicableScripts = scripts.filter { script in
            guard script.isEnabled else { return false }

            let menuKindMatch: Bool = switch menuKind {
            case .contextualMenuForItems:
                script.appliesTo == "Files & Folders" ||
                    script.appliesTo == "Files Only" ||
                    script.appliesTo == "Folders Only"
            case .contextualMenuForContainer:
                script.appliesTo == "Inside Folder" ||
                    script.appliesTo == "Files & Folders"
            case .contextualMenuForSidebar:
                script.appliesTo == "Folders Only" ||
                    script.appliesTo == "Files & Folders"
            default:
                false
            }

            guard menuKindMatch else { return false }
            guard script.matchesSelectionCount(selectionCount) else { return false }
            return script.matchesFiles(selectedURLs)
        }

        currentScripts = applicableScripts

        let categories = loadCategories()

        // Effective category per applicable script: its USER category when set, else
        // its built-in `libraryCategory`. Built-in actions now always carry a library
        // category, so grouping engages by default for a fresh install even before
        // the user creates any of their own categories. This is what keeps the OCR
        // actions reachable one hover deep instead of buried in a flat 40+ item menu.
        let assignments = applicableScripts.map {
            RightClickMenuGrouping.ScriptCategoryAssignment(
                userCategoryId: $0.categoryId,
                libraryCategory: $0.libraryCategory
            )
        }

        let hasAnyCategory = assignments.contains {
            $0.userCategoryId != nil || $0.libraryCategory != nil
        }
        let useFolders = SaneClickSharedDefaults.foldersInRightClickMenu() && hasAnyCategory

        if useFolders {
            let plan = RightClickMenuGrouping.menuPlan(
                assignments: assignments,
                orderedUserCategories: categories.map { (id: $0.id, name: $0.name, icon: $0.icon) }
            )

            // Submenus, in order: built-in categories (most-common first), then user
            // categories. Empty categories are skipped by the plan.
            for category in plan.categories {
                let submenu = NSMenu(title: category.title)
                for index in category.scriptIndices {
                    submenu.addItem(makeScriptItem(applicableScripts[index], index: index))
                }

                let folderItem = NSMenuItem(title: category.title, action: nil, keyEquivalent: "")
                folderItem.image = tintedSFSymbol(name: category.icon, accessibilityDescription: category.title)
                folderItem.submenu = submenu
                menu.addItem(folderItem)
            }

            // Uncategorized / unknown-category actions stay at the top level, after
            // the folders, in their original order.
            for index in plan.looseIndices {
                menu.addItem(makeScriptItem(applicableScripts[index], index: index))
            }
        } else {
            for (index, script) in applicableScripts.enumerated() {
                menu.addItem(makeScriptItem(script, index: index))
            }
        }

        if SaneClickSharedDefaults.showOpenMainWindowMenuItem() {
            if !applicableScripts.isEmpty {
                menu.addItem(.separator())
            }

            let settingsItem = NSMenuItem(title: "Open SaneClick...", action: #selector(openMainApp), keyEquivalent: "")
            settingsItem.image = tintedSFSymbol(name: "gearshape", accessibilityDescription: "Settings")
            menu.addItem(settingsItem)
        }

        return menu
    }

    /// Build a script menu item. The `.tag` MUST equal the script's index in
    /// `currentScripts` (the applicable list); `executeScript(_:)` looks the
    /// script up by `currentScripts[sender.tag]`.
    private func makeScriptItem(_ script: ExtensionScript, index: Int) -> NSMenuItem {
        let item = NSMenuItem(title: script.name, action: #selector(executeScript(_:)), keyEquivalent: "")
        item.tag = index
        item.image = tintedSFSymbol(name: script.icon, accessibilityDescription: script.name)
        return item
    }

    @objc func executeScript(_ sender: AnyObject?) {
        guard let menuItem = sender as? NSMenuItem else { return }

        let tag = menuItem.tag
        guard tag >= 0, tag < currentScripts.count else { return }
        let script = currentScripts[tag]

        let items = resolvedSelectionURLs()
        guard !items.isEmpty else { return }
        let paths = items.map(\.path)

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
        let center = DistributedNotificationCenter.default()
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.saneclick.SaneClick").first {
            center.postNotificationName(openMainWindowNotification, object: nil, userInfo: nil, deliverImmediately: true)
            running.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        } else {
            launchHostApp(activate: true)
            for delay in [0.75, 1.5, 3.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    center.postNotificationName(openMainWindowNotification, object: nil, userInfo: nil, deliverImmediately: true)
                }
            }
        }
    }

    private func ensureHostAppRunning() {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.saneclick.SaneClick")
        if running.isEmpty {
            launchHostApp(activate: false, executionRequested: true)
            for delay in [0.75, 1.5, 3.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    DistributedNotificationCenter.default().postNotificationName(
                        NSNotification.Name("com.saneclick.executeScript"),
                        object: nil,
                        userInfo: nil,
                        deliverImmediately: true
                    )
                }
            }
        }
    }

    private func launchHostApp(activate: Bool, executionRequested: Bool = false) {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.saneclick.SaneClick") {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = activate
            configuration.addsToRecentItems = false
            if executionRequested {
                configuration.arguments = ["--saneclick-execution-requested"]
            }
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
              let scripts = try? JSONDecoder().decode([ExtensionScript].self, from: data)
        else {
            return []
        }
        return scripts
    }

    private func loadCategories() -> [ExtensionCategory] {
        guard FileManager.default.fileExists(atPath: categoriesFileURL.path),
              let data = try? Data(contentsOf: categoriesFileURL),
              let categories = try? JSONDecoder().decode([ExtensionCategory].self, from: data)
        else {
            return []
        }
        return categories
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

// MARK: - Category Model

struct ExtensionCategory: Codable {
    let id: UUID
    let name: String
    let icon: String
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
    /// Built-in library category name (a `ScriptLibrary.ScriptCategory.rawValue`),
    /// `nil` for purely custom actions. Lets fresh-install built-ins group into
    /// submenus even before the user creates any of their own categories.
    var libraryCategory: String?

    enum CodingKeys: String, CodingKey {
        case id, name, type, content, isEnabled, icon, appliesTo, fileExtensions, extensionMatchMode, minSelection, maxSelection, categoryId, libraryCategory
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
        libraryCategory = try container.decodeIfPresent(String.self, forKey: .libraryCategory) ?? nil
    }

    func matchesFiles(_ urls: [URL]) -> Bool {
        let hasFiles = urls.contains { !$0.hasDirectoryPath }
        let hasFolders = urls.contains { $0.hasDirectoryPath }

        switch appliesTo {
        case "Files Only":
            guard hasFiles, !hasFolders else { return false }
        case "Folders Only", "Inside Folder":
            guard hasFolders, !hasFiles else { return false }
        default:
            break
        }

        guard !fileExtensions.isEmpty else { return true }

        let fileURLs = urls.filter { !$0.hasDirectoryPath }
        guard !fileURLs.isEmpty else {
            return false
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
