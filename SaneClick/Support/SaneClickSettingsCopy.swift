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
        defaultValue: "Choose the folders where SaneClick should appear in Finder. Finder Recents is a smart view, so add the folder that actually contains the files."
    )

    static let showOpenMainWindowMenuItemLabel = String(
        localized: "saneclick.settings.toggle.show_open_main_window_menu_item",
        defaultValue: "Show \"Open SaneClick...\" footer item"
    )

    static let showOpenMainWindowMenuItemHelp = String(
        localized: "saneclick.settings.help.show_open_main_window_menu_item",
        defaultValue: "Keep a shortcut to the main SaneClick window at the bottom of the Finder menu"
    )

    static let foldersInRightClickMenuLabel = String(
        localized: "saneclick.settings.toggle.folders_in_right_click_menu",
        defaultValue: "Group actions into folders"
    )

    static let foldersInRightClickMenuHelp = String(
        localized: "saneclick.settings.help.folders_in_right_click_menu",
        defaultValue: "Put each category in its own submenu in the Finder menu. Hover a folder to see its actions. Turn off to show every action in one flat list."
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

    // MARK: - Action Behavior

    static let outputModeLabel = String(
        localized: "saneclick.editor.label.output_mode",
        defaultValue: "When done"
    )

    static let outputModeStandardOption = String(
        localized: "saneclick.editor.output_mode.standard",
        defaultValue: "Standard"
    )

    static let outputModeShowOption = String(
        localized: "saneclick.editor.output_mode.show",
        defaultValue: "Show result"
    )

    static let outputModeCopyOption = String(
        localized: "saneclick.editor.output_mode.copy",
        defaultValue: "Copy result"
    )

    static let outputModeNotifyOption = String(
        localized: "saneclick.editor.output_mode.notify",
        defaultValue: "Notify with result"
    )

    static let outputModeHelp = String(
        localized: "saneclick.editor.help.output_mode",
        defaultValue: "Choose what happens with this action's output. Standard keeps the usual completion message. Show result opens a window, Copy result puts it on the clipboard, and Notify with result shows it in a notification."
    )

    static let confirmBeforeRunLabel = String(
        localized: "saneclick.editor.label.confirm_before_run",
        defaultValue: "Ask before running"
    )

    static let confirmBeforeRunHelp = String(
        localized: "saneclick.editor.help.confirm_before_run",
        defaultValue: "Show a confirmation first, so you can stop before this action changes your files."
    )
}
