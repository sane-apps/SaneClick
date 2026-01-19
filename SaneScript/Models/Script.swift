import Foundation

/// Represents a custom script that can be executed from Finder context menu
struct Script: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var type: ScriptType
    var content: String
    var isEnabled: Bool
    var icon: String // SF Symbol name
    var appliesTo: AppliesTo
    var fileExtensions: [String] // Empty = all files, otherwise only these extensions
    var extensionMatchMode: ExtensionMatchMode
    var categoryId: UUID? // nil = uncategorized

    init(
        id: UUID = UUID(),
        name: String,
        type: ScriptType = .bash,
        content: String = "",
        isEnabled: Bool = true,
        icon: String = "terminal",
        appliesTo: AppliesTo = .allItems,
        fileExtensions: [String] = [],
        extensionMatchMode: ExtensionMatchMode = .any,
        categoryId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.content = content
        self.isEnabled = isEnabled
        self.icon = icon
        self.appliesTo = appliesTo
        self.fileExtensions = fileExtensions
        self.extensionMatchMode = extensionMatchMode
        self.categoryId = categoryId
    }

    /// Check if this script applies to the given file URLs
    func matchesFiles(_ urls: [URL]) -> Bool {
        // No filter = matches everything
        guard !fileExtensions.isEmpty else { return true }

        // Folders don't have extensions, only check files
        let fileURLs = urls.filter { !$0.hasDirectoryPath }
        guard !fileURLs.isEmpty else {
            // If only folders selected and script has file filters, don't show
            return appliesTo == .foldersOnly || appliesTo == .allItems
        }

        let normalizedExtensions = Set(fileExtensions.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) })

        switch extensionMatchMode {
        case .any:
            // At least one file matches
            return fileURLs.contains { url in
                normalizedExtensions.contains(url.pathExtension.lowercased())
            }
        case .all:
            // All files must match
            return fileURLs.allSatisfy { url in
                normalizedExtensions.contains(url.pathExtension.lowercased())
            }
        }
    }
}

/// How to match file extensions
enum ExtensionMatchMode: String, Codable, CaseIterable, Sendable {
    case any = "Any file matches"
    case all = "All files match"

    var description: String { rawValue }
}

/// Type of script to execute
enum ScriptType: String, Codable, CaseIterable, Sendable {
    case bash = "Bash"
    case applescript = "AppleScript"
    case automator = "Automator Workflow"

    var icon: String {
        switch self {
        case .bash: return "terminal"
        case .applescript: return "applescript"
        case .automator: return "gearshape.2"
        }
    }
}

/// What the script applies to
enum AppliesTo: String, Codable, CaseIterable, Sendable {
    case allItems = "All Items"
    case filesOnly = "Files Only"
    case foldersOnly = "Folders Only"
    case container = "Folder Background"

    var icon: String {
        switch self {
        case .allItems: return "square.stack"
        case .filesOnly: return "doc"
        case .foldersOnly: return "folder"
        case .container: return "rectangle"
        }
    }
}
