import Foundation

struct MonitoredFolder: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let path: String
    let bookmarkData: Data

    init(id: UUID = UUID(), name: String, path: String, bookmarkData: Data) {
        self.id = id
        self.name = name
        self.path = path
        self.bookmarkData = bookmarkData
    }

    var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }
}

enum SaneClickSharedDefaults {
    static let showOpenMainWindowMenuItemKey = "showOpenMainWindowMenuItem"
    static let foldersInRightClickMenuKey = "foldersInRightClickMenu"

    static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: MonitoredFolders.appGroupID)
    }

    static func registerDefaults(in defaults: UserDefaults? = userDefaults) {
        defaults?.register(defaults: [
            showOpenMainWindowMenuItemKey: true,
            foldersInRightClickMenuKey: true
        ])
    }

    static func showOpenMainWindowMenuItem(in defaults: UserDefaults? = userDefaults) -> Bool {
        defaults?.object(forKey: showOpenMainWindowMenuItemKey) as? Bool ?? true
    }

    static func foldersInRightClickMenu(in defaults: UserDefaults? = userDefaults) -> Bool {
        defaults?.object(forKey: foldersInRightClickMenuKey) as? Bool ?? true
    }
}

/// The built-in library categories, mirrored in Shared so the Finder extension and
/// the test target can resolve their display order and icons without importing the
/// host-app-only `ScriptLibrary.ScriptCategory` enum.
///
/// `rawValue` matches `ScriptLibrary.ScriptCategory.rawValue`, and `icon` mirrors
/// `ScriptLibrary.ScriptCategory.icon`. `displayOrder` lists them most-common first
/// (Essentials, Files & Folders, Images & Media, Coding, Advanced) so built-in
/// submenus lead the right-click menu ahead of any user-created categories.
enum BuiltInMenuCategory: String, CaseIterable {
    case essentials = "Essentials"
    case filesAndFolders = "Files & Folders"
    case imagesAndMedia = "Images & Media"
    case coding = "Coding"
    case advanced = "Advanced"

    var icon: String {
        switch self {
        case .essentials: "star.fill"
        case .filesAndFolders: "folder.fill"
        case .imagesAndMedia: "photo.on.rectangle.angled"
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .advanced: "wrench.and.screwdriver.fill"
        }
    }

    /// Built-in category names, most-common first, for top-level submenu ordering.
    static var displayOrder: [String] {
        allCases.map(\.rawValue)
    }

    static func icon(forRawValue rawValue: String) -> String? {
        BuiltInMenuCategory(rawValue: rawValue)?.icon
    }
}

/// Pure grouping of applicable scripts into category folders for the right-click menu.
///
/// Lives in Shared so the Finder extension and the test target can both use it.
/// The result preserves the original index of each script (its position in the
/// applicable list) so the extension can keep menu item `.tag` == index, which is
/// what `executeScript(_:)` relies on to look the script up in `currentScripts`.
enum RightClickMenuGrouping {
    /// One category folder plus the scripts that belong in it.
    struct Folder<CategoryID: Hashable> {
        let categoryId: CategoryID
        /// Script indices (into the original applicable list), in original order.
        let scriptIndices: [Int]
    }

    /// Group `categoryIds` (one per applicable script, in order) into folders.
    ///
    /// - Parameters:
    ///   - categoryIds: the category id for each applicable script, by index. `nil` means uncategorized.
    ///   - orderedCategoryIds: all known category ids, in the order folders should appear.
    /// - Returns: folders in `orderedCategoryIds` order (only those with at least one
    ///   script), plus the indices of loose (uncategorized or unknown-category) scripts
    ///   in their original order.
    static func group<CategoryID: Hashable>(
        categoryIds: [CategoryID?],
        orderedCategoryIds: [CategoryID]
    ) -> (folders: [Folder<CategoryID>], looseIndices: [Int]) {
        let knownIds = Set(orderedCategoryIds)
        var indicesByCategory: [CategoryID: [Int]] = [:]
        var looseIndices: [Int] = []

        for (index, categoryId) in categoryIds.enumerated() {
            if let categoryId, knownIds.contains(categoryId) {
                indicesByCategory[categoryId, default: []].append(index)
            } else {
                looseIndices.append(index)
            }
        }

        let folders = orderedCategoryIds.compactMap { categoryId -> Folder<CategoryID>? in
            guard let indices = indicesByCategory[categoryId], !indices.isEmpty else { return nil }
            return Folder(categoryId: categoryId, scriptIndices: indices)
        }

        return (folders, looseIndices)
    }

    /// Identifies where an applicable script's submenu should live.
    /// A script belongs to its USER category when it has one (`categoryId` that maps
    /// to a known user category); otherwise it falls back to its built-in
    /// `libraryCategory`. Scripts with neither are loose (top level).
    struct ScriptCategoryAssignment {
        let userCategoryId: UUID?
        /// `ScriptLibrary.ScriptCategory.rawValue` (built-in) when present.
        let libraryCategory: String?
    }

    /// One ordered submenu: a display title + icon plus the original indices of the
    /// applicable scripts inside it. `userCategoryId` is set for user categories,
    /// `nil` for built-in library categories.
    struct MenuCategory {
        let title: String
        let icon: String
        let userCategoryId: UUID?
        let scriptIndices: [Int]
    }

    /// Build the ordered right-click submenu plan.
    ///
    /// Effective category per script: its user category (when `userCategoryId` maps
    /// to a known user category) ELSE its built-in `libraryCategory`. Built-in
    /// submenus come first in `BuiltInMenuCategory.displayOrder` (Essentials, Files &
    /// Folders, Images & Media, Coding, Advanced), then user categories in
    /// `orderedUserCategories` order, then loose/uncategorized indices at top level.
    /// Original indices are preserved so menu-item `.tag` == applicable-list index
    /// keeps working for `executeScript(_:)`.
    static func menuPlan(
        assignments: [ScriptCategoryAssignment],
        orderedUserCategories: [(id: UUID, name: String, icon: String)]
    ) -> (categories: [MenuCategory], looseIndices: [Int]) {
        let knownUserIds = Set(orderedUserCategories.map(\.id))

        var builtInIndices: [String: [Int]] = [:]
        var userIndices: [UUID: [Int]] = [:]
        var looseIndices: [Int] = []

        for (index, assignment) in assignments.enumerated() {
            if let userId = assignment.userCategoryId, knownUserIds.contains(userId) {
                userIndices[userId, default: []].append(index)
            } else if let libraryCategory = assignment.libraryCategory,
                      BuiltInMenuCategory(rawValue: libraryCategory) != nil {
                builtInIndices[libraryCategory, default: []].append(index)
            } else {
                looseIndices.append(index)
            }
        }

        var categories: [MenuCategory] = []

        // Built-in categories first, in fixed most-common-first order.
        for builtIn in BuiltInMenuCategory.allCases {
            guard let indices = builtInIndices[builtIn.rawValue], !indices.isEmpty else { continue }
            categories.append(
                MenuCategory(
                    title: builtIn.rawValue,
                    icon: builtIn.icon,
                    userCategoryId: nil,
                    scriptIndices: indices
                )
            )
        }

        // Then user categories, in their configured order.
        for category in orderedUserCategories {
            guard let indices = userIndices[category.id], !indices.isEmpty else { continue }
            categories.append(
                MenuCategory(
                    title: category.name,
                    icon: category.icon,
                    userCategoryId: category.id,
                    scriptIndices: indices
                )
            )
        }

        return (categories, looseIndices)
    }
}

struct MonitoredFolderAccessScope {
    private let urls: [URL]
    private let startedUrls: [URL]

    init(urls: [URL], startedUrls: [URL]) {
        self.urls = urls
        self.startedUrls = startedUrls
    }

    func stop() {
        for url in startedUrls {
            url.stopAccessingSecurityScopedResource()
        }
    }

    var hasFullAccess: Bool {
        urls.count == startedUrls.count
    }
}

enum MonitoredFolderError: LocalizedError, Equatable {
    case privacyScopedAppData(URL)

    var errorDescription: String? {
        switch self {
        case .privacyScopedAppData:
            "Choose a normal folder such as Desktop, Documents, Downloads, or a project folder. macOS app-data folders inside Library are not supported because they can trigger repeated privacy prompts."
        }
    }
}

enum MonitoredFolders {
    static let appGroupID = "M78L6FXD48.group.com.saneclick.app"
    static let changedNotification = Notification.Name("com.saneclick.monitoredFoldersChanged")
    static let monitoredFoldersConfiguredKey = "monitoredFoldersUserConfigured"

    private static var storageURL: URL {
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            return containerURL.appendingPathComponent("monitored_folders.json")
        }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let saneClickDir = appSupport.appendingPathComponent("SaneClick", isDirectory: true)
        try? FileManager.default.createDirectory(at: saneClickDir, withIntermediateDirectories: true)
        return saneClickDir.appendingPathComponent("monitored_folders.json")
    }

    private static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private static var hasUserConfiguredFolders: Bool {
        userDefaults?.bool(forKey: monitoredFoldersConfiguredKey) ?? false
    }

    private static var isRunningTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil || env["XCTestSessionIdentifier"] != nil
    }

    static func load() -> [MonitoredFolder] {
        let fileURL = storageURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return seedInitialDefaultFoldersIfNeeded()
        }

        guard let data = try? Data(contentsOf: fileURL),
              let folders = try? JSONDecoder().decode([MonitoredFolder].self, from: data)
        else {
            return seedInitialDefaultFoldersIfNeeded()
        }

        let validFolders = folders.filter { isSupportedMonitoredFolder(URL(fileURLWithPath: $0.path, isDirectory: true)) }
        if validFolders.count != folders.count {
            try? write(validFolders, markUserConfigured: false)
        }

        if validFolders.isEmpty, !hasUserConfiguredFolders {
            return seedInitialDefaultFoldersIfNeeded()
        }

        return validFolders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func save(_ folders: [MonitoredFolder]) throws {
        try write(folders, markUserConfigured: true)
    }

    private static func write(_ folders: [MonitoredFolder], markUserConfigured: Bool) throws {
        let data = try JSONEncoder().encode(folders)
        try data.write(to: storageURL, options: .atomic)
        if markUserConfigured {
            userDefaults?.set(true, forKey: monitoredFoldersConfiguredKey)
        }

        DistributedNotificationCenter.default().postNotificationName(
            changedNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    static func paths() -> [String] {
        load().map(\.path)
    }

    static func monitoredURLs() -> [URL] {
        load().map(\.url)
    }

    @discardableResult
    static func seedInitialDefaultFoldersIfNeeded() -> [MonitoredFolder] {
        guard !isRunningTests else { return [] }

        if FileManager.default.fileExists(atPath: storageURL.path),
           let data = try? Data(contentsOf: storageURL),
           let folders = try? JSONDecoder().decode([MonitoredFolder].self, from: data) {
            let validFolders = folders.filter { isSupportedMonitoredFolder(URL(fileURLWithPath: $0.path, isDirectory: true)) }
            if !validFolders.isEmpty || hasUserConfiguredFolders {
                return validFolders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
        }

        let folders = initialDefaultFolders()
        if !folders.isEmpty {
            try? write(folders, markUserConfigured: false)
        }
        return folders
    }

    static func initialDefaultFolders(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) -> [MonitoredFolder] {
        #if APP_STORE
            return []
        #else
            let home = homeDirectory.standardizedFileURL
            let candidates = [
                home.appendingPathComponent("Desktop", isDirectory: true),
                home.appendingPathComponent("Documents", isDirectory: true),
                home.appendingPathComponent("Downloads", isDirectory: true),
                home.appendingPathComponent("Pictures", isDirectory: true),
                home.appendingPathComponent("Movies", isDirectory: true)
            ]

            return candidates
                .map(\.standardizedFileURL)
                .filter { isSupportedMonitoredFolder($0, homeDirectory: home) }
                .map { url in
                    MonitoredFolder(
                        name: fileManager.displayName(atPath: url.path),
                        path: url.path,
                        bookmarkData: Data()
                    )
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        #endif
    }

    static func addFolder(url: URL, to existingFolders: [MonitoredFolder]) throws -> [MonitoredFolder] {
        let standardizedURL = url.standardizedFileURL
        guard isSupportedMonitoredFolder(standardizedURL) else {
            throw MonitoredFolderError.privacyScopedAppData(standardizedURL)
        }

        guard !existingFolders.contains(where: { $0.path == standardizedURL.path }) else {
            return existingFolders
        }

        let bookmarkData = try standardizedURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        var folders = existingFolders
        folders.append(
            MonitoredFolder(
                name: FileManager.default.displayName(atPath: standardizedURL.path),
                path: standardizedURL.path,
                bookmarkData: bookmarkData
            )
        )
        try save(folders)
        return load()
    }

    static func isSupportedMonitoredFolder(_ url: URL, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let standardizedPath = url.standardizedFileURL.path
        let homePath = homeDirectory.standardizedFileURL.path
        let libraryPath = homePath + "/Library"

        guard standardizedPath != libraryPath,
              !standardizedPath.hasPrefix(libraryPath + "/")
        else {
            return false
        }

        return true
    }

    static func removeFolder(id: UUID, from existingFolders: [MonitoredFolder]) throws -> [MonitoredFolder] {
        let filtered = existingFolders.filter { $0.id != id }
        try save(filtered)
        return load()
    }

    static func beginAccess(for paths: [String]) -> MonitoredFolderAccessScope? {
        let folders = load()
        guard !folders.isEmpty else { return nil }

        let itemURLs = paths.map { URL(fileURLWithPath: $0).standardizedFileURL }
        let matchingFolders = matchingFolders(for: itemURLs, in: folders)
        guard !matchingFolders.isEmpty else { return nil }

        let resolvedURLs = matchingFolders.compactMap(resolveBookmarkURL)
        let started = resolvedURLs.filter { $0.startAccessingSecurityScopedResource() }
        let scope = MonitoredFolderAccessScope(urls: resolvedURLs, startedUrls: started)
        guard scope.hasFullAccess else {
            scope.stop()
            return nil
        }
        return scope
    }

    private static func matchingFolders(for itemURLs: [URL], in folders: [MonitoredFolder]) -> [MonitoredFolder] {
        var matchesByPath: [String: MonitoredFolder] = [:]

        for itemURL in itemURLs {
            guard let folder = bestMatchingFolder(for: itemURL, in: folders) else {
                return []
            }
            matchesByPath[folder.path] = folder
        }

        return matchesByPath.values.sorted { $0.path < $1.path }
    }

    private static func bestMatchingFolder(for itemURL: URL, in folders: [MonitoredFolder]) -> MonitoredFolder? {
        let itemPath = itemURL.path

        return folders
            .filter { folder in
                itemPath == folder.path || itemPath.hasPrefix(folder.path + "/")
            }
            .max { lhs, rhs in
                lhs.path.count < rhs.path.count
            }
    }

    private static func resolveBookmarkURL(for folder: MonitoredFolder) -> URL? {
        var isStale = false

        guard let resolvedURL = try? URL(
            resolvingBookmarkData: folder.bookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        return resolvedURL.standardizedFileURL
    }
}
