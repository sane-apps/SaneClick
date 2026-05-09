import Foundation

enum SaneClickSettingsCopy {
    static let rightClickMenuSectionTitle = String(
        localized: "saneclick.settings.section.right_click_menu",
        defaultValue: "Right-Click Menu"
    )

    static let monitoredFoldersSectionTitle = String(
        localized: "saneclick.settings.section.monitored_folders",
        defaultValue: "Monitored Folders"
    )

    static let monitoredFoldersEmptyStateHint = String(
        localized: "saneclick.settings.hint.monitored_folders_empty",
        defaultValue: "Choose the folders where SaneClick should appear in Finder."
    )

    static let showOpenMainWindowMenuItemLabel = String(
        localized: "saneclick.settings.toggle.show_open_main_window_menu_item",
        defaultValue: "Show \"Open SaneClick...\" footer item"
    )

    static let showOpenMainWindowMenuItemHelp = String(
        localized: "saneclick.settings.help.show_open_main_window_menu_item",
        defaultValue: "Keep a shortcut to the main SaneClick window at the bottom of the Finder menu"
    )

    static let removeButtonTitle = String(
        localized: "saneclick.settings.button.remove",
        defaultValue: "Remove"
    )

    static let addFolderButtonTitle = String(
        localized: "saneclick.settings.button.add_folder",
        defaultValue: "Add Folder"
    )

    static let yourActionsSectionTitle = String(
        localized: "saneclick.settings.section.your_actions",
        defaultValue: "Your Actions"
    )

    static let totalActionsLabel = String(
        localized: "saneclick.settings.label.total_actions",
        defaultValue: "Total actions"
    )

    static let activeActionsLabel = String(
        localized: "saneclick.settings.label.active_actions",
        defaultValue: "Active actions"
    )

    static let appBehaviorSectionTitle = String(
        localized: "saneclick.settings.section.app_behavior",
        defaultValue: "App Behavior"
    )

    static let visibilityTabTitle = String(
        localized: "saneclick.settings.tab.visibility",
        defaultValue: "Visibility"
    )

    static let showMenuBarIconLabel = String(
        localized: "saneclick.settings.toggle.show_menu_bar_icon",
        defaultValue: "Show menu bar icon"
    )

    static let showMenuBarIconHelp = String(
        localized: "saneclick.settings.help.show_menu_bar_icon",
        defaultValue: "Keep SaneClick available in your menu bar"
    )

    static let showActionConfirmationsLabel = String(
        localized: "saneclick.settings.toggle.show_action_confirmations",
        defaultValue: "Show action confirmations"
    )

    static let showActionConfirmationsHelp = String(
        localized: "saneclick.settings.help.show_action_confirmations",
        defaultValue: "Show a notification when an action finishes"
    )

    static let visibleEntryPointHint = String(
        localized: "saneclick.settings.hint.hidden_icons",
        defaultValue: "SaneClick always keeps either the Dock icon or the menu bar icon available."
    )

    static let openSettingsButtonTitle = String(
        localized: "saneclick.settings.button.open_system_settings",
        defaultValue: "Manage Finder Extension"
    )

    static let openSettingsHelp = String(
        localized: "saneclick.settings.help.open_system_settings",
        defaultValue: "Open macOS Extensions settings to enable or disable SaneClick in Finder"
    )

    static let extensionControlsLabel = String(
        localized: "saneclick.settings.label.extension_controls",
        defaultValue: "Finder Extension"
    )

    static let refreshButtonTitle = String(
        localized: "saneclick.settings.button.refresh",
        defaultValue: "Refresh"
    )

    static let refreshingButtonTitle = String(
        localized: "saneclick.settings.button.refreshing",
        defaultValue: "Refreshing..."
    )

    static let refreshHelp = String(
        localized: "saneclick.settings.help.refresh",
        defaultValue: "Refresh the Finder extension status"
    )

    static let restartFinderButtonTitle = String(
        localized: "saneclick.settings.button.restart_finder",
        defaultValue: "Restart Finder"
    )

    static let restartFinderHelp = String(
        localized: "saneclick.settings.help.restart_finder",
        defaultValue: "Restart Finder if the extension is enabled but not yet running"
    )
}
