import Foundation
import SaneUI

enum AppPreferences {
    static let showMenuBarIconKey = "showMenuBarIcon"
    static let showDockIconKey = "showDockIcon"
    static let showActionNotificationsKey = "showActionNotifications"
    static let defaultShowDockIcon = SaneBackgroundAppDefaults.showDockIcon

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showMenuBarIconKey: true,
            showDockIconKey: defaultShowDockIcon,
            showActionNotificationsKey: true
        ])
    }

    static var showMenuBarIcon: Bool {
        UserDefaults.standard.object(forKey: showMenuBarIconKey) as? Bool ?? true
    }

    static var showDockIcon: Bool {
        UserDefaults.standard.object(forKey: showDockIconKey) as? Bool ?? defaultShowDockIcon
    }
}
