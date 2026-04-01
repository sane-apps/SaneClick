import AppKit
import Foundation
@testable import SaneClick
import SaneUI
import SwiftUI
import Testing

@MainActor
struct VisualVerificationRenderTests {
    private let outputDirectory = URL(fileURLWithPath: "/tmp/saneclick-visual-check", isDirectory: true)

    @Test("Render settings and custom action surfaces")
    func renderSettingsAndCustomActionSurfaces() throws {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let licenseService = LicenseService(
            appName: "SaneClick",
            checkoutURL: LicenseService.directCheckoutURL(appSlug: "saneclick"),
            directCopy: LicenseService.DirectCopy.saneClick
        )
        let scriptStore = ScriptStore.shared
        let originalScripts = Array(scriptStore.scripts)
        let monitoredFolderService = MonitoredFolderService.shared
        let customScript = Script(name: "Zip And Upload", content: "echo custom", icon: "shippingbox")
        let replaceSpacesScript = try #require(
            ScriptLibrary.allScripts.first(where: { $0.name == "Replace Spaces with Underscores" })
        )
        let defaults = try #require(SaneClickSharedDefaults.userDefaults)
        let key = SaneClickSharedDefaults.showOpenMainWindowMenuItemKey
        let hadStoredValue = defaults.object(forKey: key) != nil
        let originalFooterValue = SaneClickSharedDefaults.showOpenMainWindowMenuItem(in: defaults)

        defer {
            resetScripts(in: scriptStore, to: originalScripts)
            if hadStoredValue {
                defaults.set(originalFooterValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        resetScripts(in: scriptStore, to: [customScript])
        monitoredFolderService.refresh()

        defaults.set(true, forKey: key)
        try renderPNG(
            SettingsView(licenseService: licenseService, initialTab: .general)
                .environment(scriptStore)
                .environment(monitoredFolderService)
                .preferredColorScheme(.dark),
            size: CGSize(width: 980, height: 760),
            to: outputDirectory.appendingPathComponent("settings-footer-on.png")
        )

        defaults.set(false, forKey: key)
        try renderPNG(
            SettingsView(licenseService: licenseService, initialTab: .general)
                .environment(scriptStore)
                .environment(monitoredFolderService)
                .preferredColorScheme(.dark),
            size: CGSize(width: 980, height: 760),
            to: outputDirectory.appendingPathComponent("settings-footer-off.png")
        )

        try renderPNG(
            ContentView(licenseService: licenseService)
                .environment(scriptStore)
                .environment(monitoredFolderService)
                .preferredColorScheme(.dark),
            size: CGSize(width: 1100, height: 760),
            to: outputDirectory.appendingPathComponent("content-custom-actions.png")
        )

        try renderPNG(
            CustomActionsManagerView(
                scripts: [customScript],
                onToggle: { _ in },
                onEdit: { _ in },
                onDelete: { _ in }
            )
            .preferredColorScheme(.dark),
            size: CGSize(width: 700, height: 520),
            to: outputDirectory.appendingPathComponent("custom-actions-manager.png")
        )

        try renderPNG(
            ScriptRow(
                script: Script(
                    name: replaceSpacesScript.name,
                    type: replaceSpacesScript.type,
                    content: replaceSpacesScript.content,
                    isEnabled: true,
                    icon: replaceSpacesScript.icon,
                    appliesTo: replaceSpacesScript.appliesTo,
                    fileExtensions: replaceSpacesScript.fileExtensions
                ),
                categoryColor: .orange,
                onToggle: {},
                onEdit: {},
                onDelete: {}
            )
            .padding(20)
            .frame(width: 720, height: 120)
            .background(Color.saneNavy),
            size: CGSize(width: 720, height: 120),
            to: outputDirectory.appendingPathComponent("replace-spaces-row.png")
        )

        #expect(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("settings-footer-on.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("settings-footer-off.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("content-custom-actions.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("custom-actions-manager.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("replace-spaces-row.png").path))
    }

    private func resetScripts(in store: ScriptStore, to scripts: [Script]) {
        for script in Array(store.scripts) {
            store.deleteScript(script)
        }

        for script in scripts {
            store.addScript(script)
        }
    }

    private func renderPNG<Content: View>(_ view: Content, size: CGSize, to url: URL) throws {
        let controller = NSHostingController(rootView: view.frame(width: size.width, height: size.height))

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.backgroundColor = .windowBackgroundColor
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        controller.view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.35))

        let renderView = controller.view

        guard let bitmap = renderView.bitmapImageRepForCachingDisplay(in: renderView.bounds) else {
            Issue.record("Failed to render screenshot for \(url.lastPathComponent)")
            return
        }

        renderView.cacheDisplay(in: renderView.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            Issue.record("Failed to encode screenshot for \(url.lastPathComponent)")
            return
        }

        try png.write(to: url, options: .atomic)
        window.orderOut(nil)
    }
}
