import Foundation
import SaneUI

struct AppVisibilityState: Equatable {
    let showMenuBarIcon: Bool
    let showDockIcon: Bool
}

enum ActionCatalog {
    private static let libraryScriptNames = Set(ScriptLibrary.allScripts.map(\.name))
    private static let legacyLibrarySignatures: [String: [String]] = [
        "Copy Path": ["pbcopy"],
        "Open in Terminal": ["open -a Terminal"],
        "Convert to PNG": ["sips -s format png"],
        "Convert to JPEG": ["sips -s format jpeg"],
        "HEIC to JPEG": ["sips -s format jpeg"],
        "Resize 50%": ["sips", "--resampleWidth"],
        "Resize to 1920px": ["sips --resampleWidth 1920"],
        "Create Thumbnail (256px)": ["sips -Z 256"],
        "Remove Photo Info": ["sips -s format"],
        "Get Image Dimensions": ["sips -g pixelWidth", "pixelHeight"],
        "Rotate 90° Clockwise": ["sips -r 90"],
        "Create @2x Copy": ["@2x"]
    ]

    static func libraryScripts(in category: ScriptLibrary.ScriptCategory, from scripts: [Script]) -> [Script] {
        let categoryScriptsByName = Dictionary(
            uniqueKeysWithValues: ScriptLibrary.availableScripts(for: category).map { ($0.name, $0) }
        )
        return uniqueScriptsByName(
            scripts.filter { script in
                guard let libraryScript = categoryScriptsByName[script.name] else { return false }
                return isLibraryRecord(script, matching: libraryScript)
            }
        )
    }

    static func customScripts(from scripts: [Script]) -> [Script] {
        scripts
            .filter { script in
                guard libraryScriptNames.contains(script.name),
                      let libraryScript = ScriptLibrary.libraryScript(named: script.name)
                else { return true }
                return !isLibraryRecord(script, matching: libraryScript)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func isLibraryRecord(_ script: Script, matching libraryScript: ScriptLibrary.LibraryScript) -> Bool {
        guard script.name == libraryScript.name,
              script.type == libraryScript.type
        else { return false }

        if script.content == libraryScript.content {
            return true
        }

        return isLegacyLibraryRecord(script, matching: libraryScript)
    }

    private static func isLegacyLibraryRecord(_ script: Script, matching libraryScript: ScriptLibrary.LibraryScript) -> Bool {
        guard script.icon == libraryScript.icon,
              let signatures = legacyLibrarySignatures[libraryScript.name]
        else { return false }

        return signatures.allSatisfy { signature in
            script.content.localizedCaseInsensitiveContains(signature)
        }
    }

    private static func uniqueScriptsByName(_ scripts: [Script]) -> [Script] {
        var byName: [String: Script] = [:]
        var orderedNames: [String] = []

        for script in scripts {
            let key = script.name.lowercased()
            if byName[key] == nil {
                orderedNames.append(key)
                byName[key] = script
            } else if script.isEnabled == true, byName[key]?.isEnabled == false {
                byName[key] = script
            }
        }

        return orderedNames.compactMap { byName[$0] }
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

    static func visibilityState(settingMenuBarIcon newValue: Bool, currentDockIcon: Bool) -> AppVisibilityState {
        AppVisibilityState(
            showMenuBarIcon: newValue,
            showDockIcon: newValue ? currentDockIcon : true
        )
    }

    static func visibilityState(settingDockIcon newValue: Bool, currentMenuBarIcon: Bool) -> AppVisibilityState {
        AppVisibilityState(
            showMenuBarIcon: newValue ? currentMenuBarIcon : true,
            showDockIcon: newValue
        )
    }

    @discardableResult
    static func setMenuBarIconVisible(_ newValue: Bool) -> AppVisibilityState {
        let state = visibilityState(settingMenuBarIcon: newValue, currentDockIcon: showDockIcon)
        persistVisibility(state)
        return state
    }

    @discardableResult
    static func setDockIconVisible(_ newValue: Bool) -> AppVisibilityState {
        let state = visibilityState(settingDockIcon: newValue, currentMenuBarIcon: showMenuBarIcon)
        persistVisibility(state)
        return state
    }

    @discardableResult
    static func repairHiddenEntryPoints() -> AppVisibilityState {
        let state = AppVisibilityState(
            showMenuBarIcon: showMenuBarIcon || !showDockIcon,
            showDockIcon: showDockIcon
        )
        persistVisibility(state)
        return state
    }

    private static func persistVisibility(_ state: AppVisibilityState) {
        UserDefaults.standard.set(state.showMenuBarIcon, forKey: showMenuBarIconKey)
        UserDefaults.standard.set(state.showDockIcon, forKey: showDockIconKey)
    }
}

@MainActor
enum AppVisibilityCoordinator {
    @discardableResult
    static func setMenuBarIconVisible(_ newValue: Bool) -> AppVisibilityState {
        let state = AppPreferences.setMenuBarIconVisible(newValue)
        apply(state)
        return state
    }

    @discardableResult
    static func setDockIconVisible(_ newValue: Bool) -> AppVisibilityState {
        let state = AppPreferences.setDockIconVisible(newValue)
        apply(state)
        return state
    }

    static func applyInitialVisibility() {
        let state = AppPreferences.repairHiddenEntryPoints()
        MenuBarController.shared.setEnabled(state.showMenuBarIcon)
        SaneActivationPolicy.applyInitialPolicy(showDockIcon: state.showDockIcon)
    }

    private static func apply(_ state: AppVisibilityState) {
        MenuBarController.shared.setEnabled(state.showMenuBarIcon)
        SaneActivationPolicy.applyPolicy(showDockIcon: state.showDockIcon)
    }
}
