import AppKit
import os.log

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

        let openItem = NSMenuItem(
            title: "Open SaneClick",
            action: #selector(openApp),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        #if !APP_STORE
            let updatesItem = NSMenuItem(
                title: "Check for Updates...",
                action: #selector(checkForUpdates),
                keyEquivalent: ""
            )
            updatesItem.target = self
            menu.addItem(updatesItem)
        #endif

        menu.addItem(NSMenuItem.separator())

        #if !APP_STORE
            let restartItem = NSMenuItem(
                title: "Restart Finder",
                action: #selector(restartFinder),
                keyEquivalent: ""
            )
            restartItem.target = self
            menu.addItem(restartItem)
        #endif

        let dockItem = NSMenuItem(
            title: "Show Dock Icon",
            action: #selector(toggleDockIcon),
            keyEquivalent: ""
        )
        dockItem.target = self
        dockItem.state = AppPreferences.showDockIcon ? .on : .off
        menu.addItem(dockItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit SaneClick",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    func menuWillOpen(_ menu: NSMenu) {
        for item in menu.items where item.title == "Show Dock Icon" {
            item.state = AppPreferences.showDockIcon ? .on : .off
        }
    }

    @MainActor
    @objc private func openApp() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
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
        UserDefaults.standard.set(newValue, forKey: AppPreferences.showDockIconKey)
        ActivationPolicyManager.applyPolicy(showDockIcon: newValue)
        if newValue {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
