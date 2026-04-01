import AppKit
import Foundation
import Testing
@testable import SaneClick

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
        #expect(description == "Unlock 9 more built-in file actions.")
        #expect(description.localizedCaseInsensitiveContains("one-time purchase") == false)
    }

    @Test("App Store review notes explain where review can find Pro")
    func appStoreReviewNotesExplainProPath() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let manifest = try String(contentsOf: projectRoot.appendingPathComponent(".saneprocess"), encoding: .utf8)
        let source = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/Views/ContentView.swift"), encoding: .utf8)
        let settingsSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/Views/SettingsView.swift"), encoding: .utf8)

        #expect(manifest.localizedCaseInsensitiveContains("Settings > License"))
        #expect(manifest.localizedCaseInsensitiveContains("Unlock Pro"))
        #expect(manifest.localizedCaseInsensitiveContains("sidebar Quick Actions section"))
        #expect(manifest.localizedCaseInsensitiveContains("Donate") || manifest.localizedCaseInsensitiveContains("GitHub Sponsors"))
        #expect(source.contains("title: \"Unlock Pro\""))
        #expect(settingsSource.contains("SaneSettingsContainer(defaultTab: .general, selection: $selectedTab)"))
        #expect(settingsSource.contains("LicenseSettingsView(licenseService: licenseService, style: .panel)"))
    }

    @Test("App Store welcome claims match the actual native action split")
    func appStoreWelcomeCopyMatchesNativeActionSplit() {
        let basic = Set(AppStoreActionCatalog.basicActions)
        let pro = Set(AppStoreActionCatalog.proActions)

        #expect(basic.count == 9)
        #expect(pro.count == 9)
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
        #expect(librarySource.contains("Text(\"Unlock Pro\")"))
        #expect(librarySource.contains("Text(\"\\(totalInCategory) scripts included with Pro\")"))
        #expect(librarySource.contains("isLocked: true"))
        #expect(settingsSource.contains("SaneSettingsContainer(defaultTab: .general, selection: $selectedTab)"))
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

    @Test("Settings use shared SaneUI shell and standardized direct license copy")
    func settingsUseSharedShellAndStandardCopy() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settingsSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/Views/SettingsView.swift"), encoding: .utf8)
        let directSupportSource = try String(contentsOf: projectRoot.appendingPathComponent("SaneClick/DirectDistributionSupport.swift"), encoding: .utf8)

        #expect(settingsSource.contains("SaneSettingsContainer(defaultTab: .general, selection: $selectedTab)"))
        #expect(settingsSource.contains("SaneClickSettingsCopy.appBehaviorSectionTitle"))
        #expect(settingsSource.contains("SaneLanguageSettingsRow()"))
        #expect(settingsSource.contains("SaneClickSettingsCopy.openSettingsButtonTitle"))
        #expect(settingsSource.contains("SaneSparkleRow("))
        #expect(settingsSource.contains("Enter License Key") == false)
        #expect(settingsSource.contains("TabView(selection: $selectedTab)") == false)
        #expect(directSupportSource.contains("struct SaneSparkleRow") == false)
        #expect(directSupportSource.contains("alternateUnlockLabel: \"Unlock Pro\""))
        #expect(directSupportSource.contains("alternateEntryLabel: \"Enter License Key\""))
        #expect(directSupportSource.contains("accessManagementLabel: \"Deactivate Pro\""))
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
        #expect(appStoreInfoPlistSource.contains("<key>AppStoreProductID</key>"))
        #expect(appStoreInfoPlistSource.contains("com.saneclick.app.pro.actions.v4"))
        #expect(appStoreInfoPlistSource.contains("<key>NSAppleEventsUsageDescription</key>") == false)
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

        #expect(freeCount == 10)
        #expect(proCount == 43)
    }
}
