import Foundation

/// Represents a custom script that can be executed from Finder context menu
struct Script: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var type: ScriptType
    var content: String
    var isEnabled: Bool
    var icon: String // SF Symbol name
    var appliesTo: AppliesTo
    var fileExtensions: [String] // Empty = all files, otherwise only these extensions
    var extensionMatchMode: ExtensionMatchMode
    var minSelection: Int
    var maxSelection: Int?
    var categoryId: UUID? // nil = uncategorized
    var outputMode: ScriptOutputMode // What to do with the action's output when it finishes
    var confirmBeforeRun: Bool // Ask the user to confirm before running this action
    /// The built-in library category this action belongs to, e.g. "Images & Media"
    /// (a `ScriptLibrary.ScriptCategory.rawValue`). `nil` for purely custom actions.
    /// This is metadata only: it never participates in `AppStoreNativeAction(script:)`
    /// name/type/content matching, so it is guardrail-neutral and App-Store-safe. It
    /// lets the Finder right-click menu group fresh-install built-ins into submenus
    /// even when the user has not created their own categories.
    var libraryCategory: String?

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
        minSelection: Int = 1,
        maxSelection: Int? = nil,
        categoryId: UUID? = nil,
        outputMode: ScriptOutputMode = .standard,
        confirmBeforeRun: Bool = false,
        libraryCategory: String? = nil
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
        self.minSelection = minSelection
        self.maxSelection = maxSelection
        self.categoryId = categoryId
        self.outputMode = outputMode
        self.confirmBeforeRun = confirmBeforeRun
        self.libraryCategory = libraryCategory
    }

    /// Check if this script applies to the given file URLs
    func matchesFiles(_ urls: [URL]) -> Bool {
        let hasFiles = urls.contains { !$0.hasDirectoryPath }
        let hasFolders = urls.contains { $0.hasDirectoryPath }

        switch appliesTo {
        case .filesOnly:
            guard hasFiles, !hasFolders else { return false }
        case .foldersOnly, .container:
            guard hasFolders, !hasFiles else { return false }
        case .allItems:
            break
        }

        // No filter = matches everything
        guard !fileExtensions.isEmpty else { return true }

        // Folders don't have extensions, only check files
        let fileURLs = urls.filter { !$0.hasDirectoryPath }
        guard !fileURLs.isEmpty else {
            // If only folders selected and script has file filters, don't show
            return false
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

    /// Check if this script applies to the selection count
    func matchesSelectionCount(_ count: Int) -> Bool {
        if count < minSelection {
            return false
        }
        if let maxSelection, count > maxSelection {
            return false
        }
        return true
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case content
        case isEnabled
        case icon
        case appliesTo
        case fileExtensions
        case extensionMatchMode
        case minSelection
        case maxSelection
        case categoryId
        case outputMode
        case confirmBeforeRun
        case libraryCategory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(ScriptType.self, forKey: .type)
        content = try container.decode(String.self, forKey: .content)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        icon = try container.decode(String.self, forKey: .icon)
        appliesTo = try container.decode(AppliesTo.self, forKey: .appliesTo)
        fileExtensions = try container.decodeIfPresent([String].self, forKey: .fileExtensions) ?? []
        extensionMatchMode = try container.decodeIfPresent(ExtensionMatchMode.self, forKey: .extensionMatchMode) ?? .any
        minSelection = try container.decodeIfPresent(Int.self, forKey: .minSelection) ?? 1
        maxSelection = try container.decodeIfPresent(Int.self, forKey: .maxSelection)
        categoryId = try container.decodeIfPresent(UUID.self, forKey: .categoryId)
        outputMode = try container.decodeIfPresent(ScriptOutputMode.self, forKey: .outputMode) ?? .standard
        confirmBeforeRun = try container.decodeIfPresent(Bool.self, forKey: .confirmBeforeRun) ?? false
        libraryCategory = try container.decodeIfPresent(String.self, forKey: .libraryCategory) ?? nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(icon, forKey: .icon)
        try container.encode(appliesTo, forKey: .appliesTo)
        try container.encode(fileExtensions, forKey: .fileExtensions)
        try container.encode(extensionMatchMode, forKey: .extensionMatchMode)
        try container.encode(minSelection, forKey: .minSelection)
        try container.encodeIfPresent(maxSelection, forKey: .maxSelection)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encode(outputMode, forKey: .outputMode)
        try container.encode(confirmBeforeRun, forKey: .confirmBeforeRun)
        try container.encodeIfPresent(libraryCategory, forKey: .libraryCategory)
    }
}

/// What SaneClick does with an action's output once it finishes.
/// `.standard` preserves the historical behavior (optional completion notification,
/// honoring scripts that surface their own notifications), so existing actions are
/// unchanged. The other modes let a user opt a specific action into surfacing its
/// result a particular way.
enum ScriptOutputMode: String, Codable, CaseIterable {
    case standard // Today's behavior: optional "completed" notification only.
    case notifyResult // Post a notification whose body is the action's output.
    case copyResult // Copy the action's output to the clipboard.
    case showResult // Show the output in a result window.
}

/// How to match file extensions
enum ExtensionMatchMode: String, Codable, CaseIterable {
    case any = "Show if any selected file matches"
    case all = "Show only if all selected files match"

    var description: String {
        rawValue
    }
}

/// Type of script to execute
enum ScriptType: String, Codable, CaseIterable {
    case bash = "Shell Command"
    case applescript = "Mac Automation"
    case automator = "Automator Workflow"

    var icon: String {
        switch self {
        case .bash: "terminal"
        case .applescript: "applescript"
        case .automator: "gearshape.2"
        }
    }
}

/// What the script applies to
enum AppliesTo: String, Codable, CaseIterable {
    case allItems = "Files & Folders"
    case filesOnly = "Files Only"
    case foldersOnly = "Folders Only"
    case container = "Inside Folder"

    var icon: String {
        switch self {
        case .allItems: "square.stack"
        case .filesOnly: "doc"
        case .foldersOnly: "folder"
        case .container: "rectangle"
        }
    }
}
