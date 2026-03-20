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

        #expect(manifest.localizedCaseInsensitiveContains("Settings > License"))
        #expect(manifest.localizedCaseInsensitiveContains("Browse Library"))
        #expect(manifest.localizedCaseInsensitiveContains("Unlock Pro"))
    }
}
