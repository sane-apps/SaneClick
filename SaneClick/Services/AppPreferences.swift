import Foundation
import SaneUI

struct AppVisibilityState: Equatable {
    let showMenuBarIcon: Bool
    let showDockIcon: Bool
}

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
