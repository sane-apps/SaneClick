import SaneUI

/// Pro features for SaneClick's freemium model.
/// Free tier: Essentials (`.universal`) scripts only.
/// Pro tier: all script categories, custom editor, and import/export.
enum ProFeature: String, ProFeatureDescribing, CaseIterable {
    case codingScripts = "Coding Scripts"
    case imageScripts = "Images & Media Scripts"
    case advancedScripts = "Advanced Scripts"
    case organizationScripts = "Files & Folders Scripts"
    case scriptEditor = "Custom Script Editor"
    case importExport = "Import / Export Scripts"

    var id: String { rawValue }
    var featureName: String { rawValue }

    var featureDescription: String {
        switch self {
        case .codingScripts: "12 developer tools for coding workflows"
        case .imageScripts: "10 scripts for image resizing, conversion, and editing"
        case .advancedScripts: "10 power tools for compression, hashing, and system tasks"
        case .organizationScripts: "8 scripts for sorting, renaming, and file management"
        case .scriptEditor: "Create your own custom Finder scripts"
        case .importExport: "Share and back up your script collection"
        }
    }

    var featureIcon: String {
        switch self {
        case .codingScripts: "chevron.left.forwardslash.chevron.right"
        case .imageScripts: "photo.on.rectangle.angled"
        case .advancedScripts: "wrench.and.screwdriver.fill"
        case .organizationScripts: "folder.fill"
        case .scriptEditor: "square.and.pencil"
        case .importExport: "square.and.arrow.up.on.square"
        }
    }
}
