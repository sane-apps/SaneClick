import AppKit
import os.log
import SaneUI

@MainActor
enum SaneClickContextMenu {
    static let showDockIconTitle = "Show Dock Icon"

    static func make(
        target: AnyObject,
        openAction: Selector,
        settingsAction: Selector,
        licenseAction: Selector,
        checkForUpdatesAction: Selector?,
        configureCheckForUpdates: ((NSMenuItem) -> Void)? = nil,
        aboutAction: Selector,
        restartFinderAction: Selector?,
        toggleDockIconAction: Selector?,
        quitAction: Selector
    ) -> NSMenu {
        let menu = NSMenu()

        #if APP_STORE
            menu.addItem(NSMenuItem(
                title: "Open SaneClick",
                action: openAction,
                keyEquivalent: ""
            ))
            menu.items.last?.target = target
            menu.addItem(.separator())

            menu.addItem(NSMenuItem(
                title: "Settings...",
                action: settingsAction,
                keyEquivalent: ""
            ))
            menu.items.last?.target = target

            menu.addItem(NSMenuItem(
                title: "License...",
                action: licenseAction,
                keyEquivalent: ""
            ))
            menu.items.last?.target = target

            menu.addItem(NSMenuItem(
                title: "About / Report a Bug...",
                action: aboutAction,
                keyEquivalent: ""
            ))
            menu.items.last?.target = target

            if let toggleDockIconAction {
                menu.addItem(.separator())
                menu.addItem(dockIconItem(target: target, action: toggleDockIconAction))
            }

            menu.addItem(.separator())
            menu.addItem(NSMenuItem(
                title: "Quit SaneClick",
                action: quitAction,
                keyEquivalent: "q"
            ))
            menu.items.last?.target = target
            return menu
        #endif

        menu.addItem(SaneStandardMenu.openAppItem(
            appName: "SaneClick",
            target: target,
            action: openAction
        ))
        menu.addItem(.separator())

        var extraUtilityItems: [NSMenuItem] = []
        if let restartFinderAction {
            extraUtilityItems.append(SaneStandardMenu.item(
                title: "Restart Finder",
                target: target,
                action: restartFinderAction
            ))
        }
        if let toggleDockIconAction {
            extraUtilityItems.append(dockIconItem(target: target, action: toggleDockIconAction))
        }

        SaneStandardMenu.addCoreUtilityItems(
            to: menu,
            appName: "SaneClick",
            target: target,
            settingsAction: settingsAction,
            licenseAction: licenseAction,
            checkForUpdatesAction: checkForUpdatesAction,
            configureCheckForUpdates: configureCheckForUpdates,
            aboutAndBugReportAction: aboutAction,
            extraUtilityItems: extraUtilityItems,
            quitAction: quitAction,
            settingsKeyEquivalent: ""
        )

        return menu
    }

    static func refreshDynamicItems(in menu: NSMenu) {
        menu.item(withTitle: showDockIconTitle)?.state = AppPreferences.showDockIcon ? .on : .off
    }

    private static func dockIconItem(target: AnyObject, action: Selector) -> NSMenuItem {
        SaneStandardMenu.item(
            title: showDockIconTitle,
            target: target,
            action: action,
            state: AppPreferences.showDockIcon ? .on : .off
        )
    }
}

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    static let shared = MenuBarController()

    private let logger = Logger(subsystem: "com.saneclick.SaneClick", category: "MenuBar")
    private var statusItem: NSStatusItem?
    private lazy var menu: NSMenu = {
        let menu = NSMenu()
        menu.delegate = self
        return menu
    }()

    override private init() {
        super.init()
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            installStatusItemIfNeeded()
        } else {
            removeStatusItem()
        }
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "SaneClick")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "SaneClick"
        }

        item.menu = menu
        statusItem = item
        rebuildMenu()
        logger.info("Menu bar icon enabled")
    }

    private func removeStatusItem() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
        logger.info("Menu bar icon disabled")
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        let rebuiltMenu = SaneClickContextMenu.make(
            target: self,
            openAction: #selector(openApp),
            settingsAction: #selector(openSettings),
            licenseAction: #selector(openLicense),
            checkForUpdatesAction: directUpdateAction,
            configureCheckForUpdates: directUpdateConfigurator,
            aboutAction: #selector(openAbout),
            restartFinderAction: directRestartFinderAction,
            toggleDockIconAction: #selector(toggleDockIcon),
            quitAction: #selector(quitApp)
        )
        rebuiltMenu.items.forEach { item in
            rebuiltMenu.removeItem(item)
            menu.addItem(item)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        SaneClickContextMenu.refreshDynamicItems(in: menu)
    }

    #if !APP_STORE
        private var directUpdateAction: Selector? {
            #selector(checkForUpdates)
        }

        private var directUpdateConfigurator: ((NSMenuItem) -> Void)? {
            { item in
                let updateService = UpdateService.shared
                item.isEnabled = updateService.isUpdateChannelEnabled
                item.toolTip = updateService.isUpdateChannelEnabled ? nil : updateService.updateUnavailableStatus
            }
        }

        private var directRestartFinderAction: Selector? {
            #selector(restartFinder)
        }
    #else
        private var directUpdateAction: Selector? { nil }
        private var directUpdateConfigurator: ((NSMenuItem) -> Void)? { nil }
        private var directRestartFinderAction: Selector? { nil }
    #endif

    @MainActor
    @objc private func openApp() {
        WindowActionStorage.shared.showMainWindow()
    }

    @MainActor
    @objc private func openSettings() {
        SettingsActionStorage.shared.showSettings()
    }

    @MainActor
    @objc private func openLicense() {
        SettingsActionStorage.shared.showSettings(tab: .license)
    }

    @MainActor
    @objc private func openAbout() {
        SettingsActionStorage.shared.showSettings(tab: .about)
    }

    #if !APP_STORE
        @objc private func checkForUpdates() {
            UpdateService.shared.checkForUpdates()
        }

        @objc private func restartFinder() {
            FinderControl.restartFinder()
        }
    #endif

    @MainActor
    @objc private func toggleDockIcon() {
        let newValue = !AppPreferences.showDockIcon
        let state = AppVisibilityCoordinator.setDockIconVisible(newValue)
        if state.showDockIcon {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
