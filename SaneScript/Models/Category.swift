import Foundation

/// Represents a category for organizing scripts
struct ScriptCategory: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var icon: String

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder"
    ) {
        self.id = id
        self.name = name
        self.icon = icon
    }
}

// MARK: - Built-in Categories

extension ScriptCategory {
    /// System-defined categories that cannot be deleted
    static let uncategorized = ScriptCategory(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        name: "Uncategorized",
        icon: "tray"
    )
}
