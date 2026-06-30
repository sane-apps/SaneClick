import AppKit
import Foundation
@testable import SaneClick
import SaneUI
import Testing

@MainActor
private final class MenuActionTarget: NSObject {
    @objc func action() {}
}

@MainActor
struct AppStoreReviewGuardrailTests {
    @Test("Reopen without visible windows requests the main window")
    func reopenWithoutVisibleWindowsRequestsMainWindow() {
        let delegate = SaneClickAppDelegate()
        let originalOpenWindow = WindowActionStorage.shared.openWindow
        var requestedWindowIDs: [String] = []
        WindowActionStorage.shared.openWindow = { windowID in
            requestedWindowIDs.append(windowID)
        }
        defer { WindowActionStorage.shared.openWindow = originalOpenWindow }

        let handled = delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)

        #expect(handled)
        #expect(requestedWindowIDs == ["main"])
    }

    @Test("Stored settings action is used for review-facing settings buttons")
    func storedSettingsActionIsInvoked() {
        let originalSettingsAction = SettingsActionStorage.shared.openSettings
        var invocationCount = 0
        SettingsActionStorage.shared.openSettings = {
            invocationCount += 1
        }
        defer { SettingsActionStorage.shared.openSettings = originalSettingsAction }

        SettingsActionStorage.shared.showSettings()

        #expect(invocationCount == 1)
    }

    @Test("Stored settings action can route directly to License and About tabs")
    func storedSettingsActionRoutesTabs() {
        let originalSettingsAction = SettingsActionStorage.shared.openSettings
        var invocationCount = 0
        SettingsActionStorage.shared.openSettings = {
            invocationCount += 1
        }
        defer { SettingsActionStorage.shared.openSettings = originalSettingsAction }

        SettingsActionStorage.shared.showSettings(tab: .license)

        #expect(invocationCount == 1)
        #expect(SettingsActionStorage.shared.consumePendingTab() == .license)
    }

    @Test("App menu settings item is owned only by the Settings scene")
    func appMenuSettingsItemIsOwnedOnlyBySettingsScene() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/SaneClickApp.swift"), encoding: .utf8)

        #expect(appSource.contains("Settings {"))
        #expect(appSource.contains("CommandGroup(replacing: .appSettings)") == false)
        #expect(appSource.contains("keyboardShortcut(\",\", modifiers: .command)") == false)
    }

    @Test("Dock and menu bar context menus share customer-critical settings order")
    func dockAndMenuBarContextMenusShareCustomerCriticalOrder() {
        let delegate = SaneClickAppDelegate()
        let dockMenu = delegate.applicationDockMenu(NSApplication.shared)
        let target = MenuActionTarget()
        #if !APP_STORE
            let updateAction: Selector? = #selector(MenuActionTarget.action)
            let restartAction: Selector? = #selector(MenuActionTarget.action)
        #else
            let updateAction: Selector? = nil
            let restartAction: Selector? = nil
        #endif
        let menuBarMenu = SaneClickContextMenu.make(
            target: target,
            openAction: #selector(MenuActionTarget.action),
            settingsAction: #selector(MenuActionTarget.action),
            licenseAction: #selector(MenuActionTarget.action),
            checkForUpdatesAction: updateAction,
            aboutAction: #selector(MenuActionTarget.action),
            restartFinderAction: restartAction,
            toggleDockIconAction: #selector(MenuActionTarget.action),
            quitAction: #selector(MenuActionTarget.action)
        )
        var expectedOrder = [
            "Open SaneClick",
            SaneStandardMenu.settingsTitle,
            SaneStandardMenu.licenseTitle
        ]
        #if !APP_STORE
            expectedOrder.append(SaneStandardMenu.checkForUpdatesTitle)
        #endif
        expectedOrder.append(SaneStandardMenu.aboutAndBugReportTitle)
        #if !APP_STORE
            expectedOrder.append("Restart Finder")
        #endif
        expectedOrder.append(SaneClickContextMenu.showDockIconTitle)
        expectedOrder.append("Quit SaneClick")

        #expect(dockMenu?.items.map(\.title).filter { !$0.isEmpty } == expectedOrder)
        #expect(menuBarMenu.items.map(\.title).filter { !$0.isEmpty } == expectedOrder)
    }

    @Test("Menu bar open action uses shared main-window path")
    func menuBarOpenActionUsesSharedMainWindowPath() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/Services/MenuBarController.swift"), encoding: .utf8)

        #expect(source.contains("@objc private func openApp()"))
        #expect(source.contains("WindowActionStorage.shared.showMainWindow()"))
    }

    @Test("App Store subtitle avoids Apple product names")
    func appStoreSubtitleAvoidsAppleProductNames() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let manifest = try String(contentsOf: projectRoot.appendingPathComponent(".saneprocess"), encoding: .utf8)

        let subtitlePattern = #/subtitle:\s*"([^"]+)"/#
        let matches = manifest.matches(of: subtitlePattern)
        let subtitle = String(matches.first?.output.1 ?? "")

        #expect(subtitle.isEmpty == false)
        #expect(subtitle.localizedCaseInsensitiveContains("finder") == false)
        #expect(subtitle.localizedCaseInsensitiveContains("mac") == false)
    }

    @Test("App Store IAP copy is explicit and product-specific")
    func appStoreIapCopyIsExplicit() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let manifest = try String(contentsOf: projectRoot.appendingPathComponent(".saneprocess"), encoding: .utf8)

        let productIdPattern = #/product_id:\s*"([^"]+)"/#
        let namePattern = #/display_name:\s*"([^"]+)"/#
        let descriptionPattern = #/description:\s*"([^"]+)"/#
        let productId = String(manifest.matches(of: productIdPattern).first?.output.1 ?? "")
        let displayName = String(manifest.matches(of: namePattern).first?.output.1 ?? "")
        let description = String(manifest.matches(of: descriptionPattern).first?.output.1 ?? "")

        #expect(productId == "com.saneclick.app.pro.actions.v4")
        #expect(displayName == "SaneClick Pro Access")
        #expect(description == "Unlock 24 more built-in file actions.")
        #expect(description.localizedCaseInsensitiveContains("one-time purchase") == false)
    }

    @Test("Active App Store lane carries the metadata required to submit")
    func activeAppStoreLaneCarriesSubmissionMetadata() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let manifest = try String(contentsOf: projectRoot.appendingPathComponent(".saneprocess"), encoding: .utf8)

        // The lane is now actively submitting to the Mac App Store.
        #expect(manifest.contains("enabled: true"))
        #expect(!manifest.contains("enabled: false"))

        // Required submission identifiers and StoreKit-only compliance.
        #expect(manifest.contains("app_id: \"6759330868\""))
        #expect(manifest.contains("product_id: \"com.saneclick.app.pro.actions.v4\""))
        #expect(manifest.contains("scheme: SaneClick-AppStore"))
        #expect(manifest.contains("configuration: Release-AppStore"))

        // Metadata, review notes, IAP block, and screenshots needed to pass preflight/submit.
        #expect(manifest.localizedCaseInsensitiveContains("whats_new:"))
        #expect(manifest.localizedCaseInsensitiveContains("review_notes_by_platform:"))
        #expect(manifest.localizedCaseInsensitiveContains("display_name: \"SaneClick Pro Access\""))
        #expect(manifest.contains("docs/screenshots/appstore-*.png"))

        // No external-purchase escape hatch in the App Store lane. An in-app
        // "Settings > License / Unlock Pro" path is allowed and expected (App Review
        // needs it), and the notes may reassure that there is "no license key" / "no
        // external checkout" — so the guard targets external storefront URLs and
        // third-party checkout providers, not that reassurance language.
        #expect(!manifest.localizedCaseInsensitiveContains("Paste your API key"))
        #expect(!manifest.localizedCaseInsensitiveContains("saneclick.com/checkout"))
        #expect(!manifest.localizedCaseInsensitiveContains("lemonsqueezy"))
        #expect(!manifest.localizedCaseInsensitiveContains("gumroad"))
        // The IAP review note must affirm there is no external checkout / license key flow.
        #expect(manifest.localizedCaseInsensitiveContains("does not unlock scripts, external checkout, or license keys"))
    }

    @Test("App Store welcome claims match the actual native action split")
    func appStoreWelcomeCopyMatchesNativeActionSplit() {
        let basic = Set(AppStoreActionCatalog.basicActions)
        let pro = Set(AppStoreActionCatalog.proActions)

        #expect(basic.count == 13)
        #expect(pro.count == 24)
        #expect(basic.intersection(pro).isEmpty)
        #expect(basic.union(pro).count == AppStoreNativeAction.allCases.count)
    }

    @Test("App Store upsell is visible across onboarding library sidebar and settings")
    func appStoreUpsellIsVisibleAcrossPrimarySurfaces() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let saneAppsRoot = projectRoot
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/SaneClickApp.swift"), encoding: .utf8)
        let contentSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/Views/ContentView.swift"), encoding: .utf8)
        let librarySource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/Views/ScriptLibraryView.swift"), encoding: .utf8)
        let settingsSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/Views/SettingsView.swift"), encoding: .utf8)
        let licenseSettingsSource = try String(
            contentsOf: saneAppsRoot.appendingPathComponent("infra/SaneUI/Sources/SaneUI/License/LicenseSettingsView.swift"),
            encoding: .utf8
        )

        #expect(appSource.contains("WelcomeGateView("))
        #expect(appSource.contains("proTierPriceOverride: SaneClickWelcomeCopy.proPrice"))
        #expect(contentSource.contains("title: \"Unlock Pro\""))
        #expect(contentSource.contains("isLocked: true"))
        #expect(librarySource.contains("Unlock Pro — \\(licenseService.displayPriceLabel)"))
        #expect(librarySource.contains("Text(\"\\(totalInCategory) scripts included with Pro\")"))
        #expect(librarySource.contains("isLocked: true"))
        #expect(settingsSource.contains("SaneSettingsContainer(defaultTab: .general, selection: $selectedTab, windowSizing: .embedded)"))
        #expect(settingsSource.contains("LicenseSettingsView(licenseService: licenseService, style: .panel)"))
        #expect(licenseSettingsSource.contains("Unlock Pro —"))
        #expect(licenseSettingsSource.contains("Restore Purchases"))
    }

    @Test("Returning users do not keep the welcome sheet presenter attached")
    func returningUsersDoNotKeepWelcomeSheetPresenterAttached() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/SaneClickApp.swift"), encoding: .utf8)

        #expect(appSource.contains("if shouldAttachWelcomeGate"))
        #expect(appSource.contains("showWelcomeGate || !WelcomeGateState.hasSeenWelcome()"))
        #expect(appSource.contains("WelcomeGateState.purgeRestoredSheetState()"))
    }

    @Test("Normal app launch does not touch App Group execution files")
    func normalLaunchDoesNotTouchAppGroupExecutionFiles() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/SaneClickApp.swift"), encoding: .utf8)
        let executorSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/Services/ScriptExecutor.swift"), encoding: .utf8)
        let extensionSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClickExtension/FinderSync.swift"), encoding: .utf8)

        #expect(appSource.contains("ProcessInfo.processInfo.arguments.contains(\"--saneclick-execution-requested\")"))
        #expect(extensionSource.contains("configuration.arguments = [\"--saneclick-execution-requested\"]"))
        #expect(executorSource.contains("processPendingExecutionAfterLaunchRequest()"))
        let initStart = try #require(executorSource.range(of: "private init()"))
        let launchRequestStart = try #require(executorSource.range(of: "func processPendingExecutionAfterLaunchRequest()"))
        let initSection = String(executorSource[initStart.lowerBound ..< launchRequestStart.lowerBound])
        #expect(initSection.contains("addObserver"))
        #expect(initSection.contains("asyncAfter") == false)
        #expect(executorSource.contains("setupFileWatcher()") == false)
    }

    @Test("Settings use shared SaneUI shell and standardized direct license copy")
    func settingsUseSharedShellAndStandardCopy() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settingsSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/Views/SettingsView.swift"), encoding: .utf8)
        let directSupportSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/DirectDistributionSupport.swift"), encoding: .utf8)

        #expect(settingsSource.contains("SaneSettingsContainer(defaultTab: .general, selection: $selectedTab, windowSizing: .embedded)"))
        #expect(settingsSource.contains("SaneClickSettingsCopy.appBehaviorSectionTitle"))
        #expect(settingsSource.contains("SaneLanguageSettingsRow()"))
        #expect(settingsSource.contains("SaneClickSettingsCopy.openSettingsButtonTitle"))
        #expect(settingsSource.contains("SaneSparkleRow("))
        #expect(settingsSource.contains("SaneClickSettingsCopy.yourActionsSectionTitle") == false)
        #expect(settingsSource.contains("Enter License Key") == false)
        #expect(settingsSource.contains("TabView(selection: $selectedTab)") == false)
        #expect(directSupportSource.contains("struct SaneSparkleRow") == false)
        #expect(directSupportSource.contains("alternateUnlockLabel: \"Unlock Pro\""))
        #expect(directSupportSource.contains("alternateEntryLabel: \"Enter License Key\""))
        #expect(directSupportSource.contains("accessManagementLabel: \"Deactivate Pro\""))
    }

    @Test("Direct builds expose monitored folder setup instead of silent empty Finder registration")
    func directBuildsExposeMonitoredFolderSetup() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settingsSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/Views/SettingsView.swift"), encoding: .utf8)
        let contentSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/Views/ContentView.swift"), encoding: .utf8)
        let monitoredFoldersSource = try String(contentsOf: projectRoot.appendingPathComponent("Shared/MonitoredFolders.swift"), encoding: .utf8)

        #expect(settingsSource.contains("SaneClickSettingsCopy.monitoredFoldersSectionTitle"))
        #expect(settingsSource.contains("#if APP_STORE\n                    CompactSection(SaneClickSettingsCopy.monitoredFoldersSectionTitle") == false)
        #expect(contentSource.contains("QuickActionRow(\n                    title: \"Manage Folders\""))
        #expect(contentSource.contains("if monitoredFolderService.monitoredFolderCount == 0"))
        #expect(contentSource.contains("#if APP_STORE\n        private var monitoredFoldersNotice") == false)
        #expect(monitoredFoldersSource.contains("seedInitialDefaultFoldersIfNeeded()"))
        #expect(monitoredFoldersSource.contains("monitoredFoldersUserConfigured"))
        #expect(monitoredFoldersSource.contains("initialDefaultFolders()"))
        #expect(monitoredFoldersSource.contains("Downloads"))
        #expect(monitoredFoldersSource.contains("Pictures"))
    }

    @Test("Direct source build metadata stays on the direct lane")
    func directSourceBuildMetadataStaysDirect() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let infoPlistSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/Info.plist"), encoding: .utf8)
        let appStoreInfoPlistSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/Info-AppStore.plist"), encoding: .utf8)
        let projectManifest = try String(contentsOf: projectRoot.appendingPathComponent("project.yml"), encoding: .utf8)

        #expect(Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String == "https://saneclick.com/appcast.xml")
        #expect(Bundle.main.object(forInfoDictionaryKey: "AppStoreProductID") == nil)
        #expect(infoPlistSource.contains("<key>SUFeedURL</key>"))
        #expect(infoPlistSource.contains("<key>SUPublicEDKey</key>"))
        #expect(infoPlistSource.contains("<key>AppStoreProductID</key>") == false)
        #expect(infoPlistSource.contains("<key>NSAppDataUsageDescription</key>"))
        #expect(appStoreInfoPlistSource.contains("<key>AppStoreProductID</key>"))
        #expect(appStoreInfoPlistSource.contains("com.saneclick.app.pro.actions.v4"))
        #expect(appStoreInfoPlistSource.contains("<key>NSAppleEventsUsageDescription</key>") == false)
        #expect(appStoreInfoPlistSource.contains("<key>NSAppDataUsageDescription</key>"))
        #expect(appStoreInfoPlistSource.contains("<key>SUFeedURL</key>") == false)
        #expect(projectManifest.contains("INFOPLIST_FILE: SaneClick/Info.plist"))
        #expect(projectManifest.contains("INFOPLIST_FILE: SaneClick/Info-AppStore.plist"))
        #expect(projectManifest.contains("INFOPLIST_KEY_AppStoreProductID: com.saneclick.app.pro.actions.v4"))
    }

    @Test("Direct welcome claims match the script library split")
    func directWelcomeCopyMatchesScriptLibrarySplit() {
        let freeCount = ScriptLibrary.availableScripts(for: .universal).count
        let proCount = ScriptLibrary
            .availableCategories
            .filter { $0 != .universal }
            .map { ScriptLibrary.availableScripts(for: $0).count }
            .reduce(0, +)

        #expect(freeCount == 14)
        #expect(proCount == 48)
    }
}
