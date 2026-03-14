import AppKit
import Observation

@Observable
@MainActor
final class MonitoredFolderService {
    static let shared = MonitoredFolderService()

    private(set) var folders: [MonitoredFolder] = []
    private(set) var lastError: String?

    private init() {
        refresh()
    }

    func refresh() {
        folders = MonitoredFolders.load()
    }

    func addFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Monitor"
        panel.message = "Choose the folders where SaneClick should appear in Finder."

        guard panel.runModal() == .OK else { return }

        do {
            var updatedFolders = folders
            for url in panel.urls {
                updatedFolders = try MonitoredFolders.addFolder(url: url, to: updatedFolders)
            }
            folders = updatedFolders
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func removeFolder(_ folder: MonitoredFolder) {
        do {
            folders = try MonitoredFolders.removeFolder(id: folder.id, from: folders)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    var monitoredFolderCount: Int {
        folders.count
    }
}
