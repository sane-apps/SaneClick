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

        #expect(productId == "com.saneclick.app.pro.unlock.v3")
        #expect(displayName == "SaneClick Pro Actions")
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
        #expect(settingsSource.contains("Label(\"License\", systemImage: \"key\")"))
        #expect(settingsSource.contains("LicenseSettingsView(licenseService: licenseService)"))
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
        #expect(settingsSource.contains("LicenseSettingsView(licenseService: licenseService)"))
        #expect(licenseSettingsSource.contains("Unlock Pro —"))
        #expect(licenseSettingsSource.contains("Restore Purchases"))
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
        #expect(proCount == 40)
    }
}
