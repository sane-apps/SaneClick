import AppKit
import Foundation
import SaneUI
import SwiftUI
import Testing
@testable import SaneClick

@MainActor
struct AppStoreScreenshotRenderTests {
    @Test("Render App Store screenshots")
    func renderAppStoreScreenshots() throws {
        guard let rawOutputDir = ProcessInfo.processInfo.environment["SANECLICK_SCREENSHOT_DIR"],
              !rawOutputDir.isEmpty
        else {
            return
        }

        let outputDir = URL(fileURLWithPath: rawOutputDir, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let licenseService = LicenseService(
            appName: "SaneClick",
            purchaseBackend: .appStore(productID: "com.saneclick.app.pro.unlock.v2")
        )
        let scriptStore = ScriptStore.shared
        try seedScreenshotState(store: scriptStore)

        let monitoredFolderService = MonitoredFolderService.shared
        monitoredFolderService.refresh()

        try renderPNG(
            welcomeView(licenseService: licenseService),
            to: outputDir.appendingPathComponent("onboarding.png")
        )

        try renderPNG(
            ContentView(licenseService: licenseService)
                .environment(scriptStore)
                .environment(monitoredFolderService)
                .preferredColorScheme(.dark)
                .frame(width: 1100, height: 760),
            to: outputDir.appendingPathComponent("main-window.png")
        )

        try renderPNG(
            ZStack {
                Color.saneNavy.opacity(0.3)
                    .ignoresSafeArea()
                SettingsView(licenseService: licenseService)
                    .environment(scriptStore)
                    .environment(monitoredFolderService)
                    .preferredColorScheme(.dark)
            }
            .frame(width: 1000, height: 640),
            to: outputDir.appendingPathComponent("finder-context-menu.png")
        )

        try renderPNG(
            ScriptLibraryView(licenseService: licenseService)
                .environment(scriptStore)
                .preferredColorScheme(.dark)
                .frame(width: 1100, height: 760),
            to: outputDir.appendingPathComponent("script-library.png")
        )

        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("onboarding.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("main-window.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("finder-context-menu.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("script-library.png").path))
    }

    private func welcomeView(licenseService: LicenseService) -> some View {
        WelcomeGateView(
            appName: "SaneClick",
            appIcon: "cursorarrow.click.2",
            freeFeatures: [
                ("star.fill", "9 built-in Finder actions"),
                ("folder.badge.gearshape", "Choose the folders SaneClick watches"),
                ("checkmark.shield", "No account or signup needed")
            ],
            proFeatures: [
                ("folder.fill", "7 Files & Folders actions"),
                ("wrench.and.screwdriver.fill", "2 Advanced hashing actions")
            ],
            licenseService: licenseService
        )
        .preferredColorScheme(.dark)
    }

    private func seedScreenshotState(store: ScriptStore) throws {
        AppPreferences.registerDefaults()

        for script in Array(store.scripts) {
            store.deleteScript(script)
        }

        let featuredActions =
            ScriptLibrary.availableScripts(for: .universal) +
            ScriptLibrary.availableScripts(for: .organization).prefix(3) +
            ScriptLibrary.availableScripts(for: .powerUser)

        for action in featuredActions {
            store.addScript(action.toScript())
        }

        try MonitoredFolders.save([])
        let demoRoot = FileManager.default.temporaryDirectory.appendingPathComponent("SaneClick Screenshot Demo", isDirectory: true)
        try FileManager.default.createDirectory(at: demoRoot, withIntermediateDirectories: true)
        try "Client notes".write(to: demoRoot.appendingPathComponent("Client Notes.txt"), atomically: true, encoding: .utf8)
        _ = try MonitoredFolders.addFolder(url: demoRoot, to: [])
    }

    private func renderPNG<Content: View>(_ view: Content, to url: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else {
            Issue.record("Failed to render screenshot for \(url.lastPathComponent)")
            return
        }

        try png.write(to: url, options: .atomic)
    }
}
