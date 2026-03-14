import Foundation

struct MonitoredFolder: Codable, Identifiable, Hashable, Sendable {
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

enum MonitoredFolders {
    static let appGroupID = "M78L6FXD48.group.com.saneclick.app"
    static let changedNotification = Notification.Name("com.saneclick.monitoredFoldersChanged")

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

    static func load() -> [MonitoredFolder] {
        let fileURL = storageURL
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let folders = try? JSONDecoder().decode([MonitoredFolder].self, from: data)
        else {
            return []
        }

        return folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func save(_ folders: [MonitoredFolder]) throws {
        let data = try JSONEncoder().encode(folders)
        try data.write(to: storageURL, options: .atomic)

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

    static func addFolder(url: URL, to existingFolders: [MonitoredFolder]) throws -> [MonitoredFolder] {
        let standardizedURL = url.standardizedFileURL
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
