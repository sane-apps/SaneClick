import Foundation
import SaneUI

enum ActionCatalog {
    private static let libraryScriptNames = Set(ScriptLibrary.allScripts.map(\.name))

    static func libraryScripts(in category: ScriptLibrary.ScriptCategory, from scripts: [Script]) -> [Script] {
        let categoryScriptNames = Set(ScriptLibrary.availableScripts(for: category).map(\.name))
        return scripts.filter { categoryScriptNames.contains($0.name) }
    }

    static func customScripts(from scripts: [Script]) -> [Script] {
        scripts
            .filter { !libraryScriptNames.contains($0.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

enum AppPreferences {
    static let showMenuBarIconKey = "showMenuBarIcon"
    static let showDockIconKey = "showDockIcon"
    static let showActionNotificationsKey = "showActionNotifications"
    static let defaultShowDockIcon = SaneBackgroundAppDefaults.showDockIcon

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [showMenuBarIconKey: true, showDockIconKey: defaultShowDockIcon, showActionNotificationsKey: true])
        SaneClickSharedDefaults.registerDefaults()
    }

    static var showMenuBarIcon: Bool {
        UserDefaults.standard.object(forKey: showMenuBarIconKey) as? Bool ?? true
    }

    static var showDockIcon: Bool {
        UserDefaults.standard.object(forKey: showDockIconKey) as? Bool ?? defaultShowDockIcon
    }
}
