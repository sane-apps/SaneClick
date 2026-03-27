import AppKit
import Foundation
import SaneUI
import SwiftUI
import Testing
@testable import SaneClick

@MainActor
struct AppStoreScreenshotRenderTests {
    private let outputHintFile = URL(fileURLWithPath: "/tmp/saneclick_screenshot_dir.txt")

    @Test("Render App Store screenshots")
    func renderAppStoreScreenshots() throws {
        let outputDir = try screenshotOutputDirectory()
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let licenseService = LicenseService(
            appName: "SaneClick",
            purchaseBackend: .appStore(productID: "com.saneclick.app.pro.unlock.v3")
        )
        let scriptStore = ScriptStore.shared
        try seedScreenshotState(store: scriptStore)

        let monitoredFolderService = MonitoredFolderService.shared
        monitoredFolderService.refresh()

        try renderPNG(
            welcomeView(licenseService: licenseService),
            size: CGSize(width: 700, height: 520),
            to: outputDir.appendingPathComponent("onboarding.png")
        )

        try renderPNG(
            mainWindowShowcaseView(licenseService: licenseService),
            size: CGSize(width: 1100, height: 760),
            to: outputDir.appendingPathComponent("main-window.png")
        )

        try renderPNG(
            ZStack {
                Color.saneNavy.opacity(0.3)
                    .ignoresSafeArea()
                SettingsView(licenseService: licenseService, initialTab: .license)
                    .environment(scriptStore)
                    .environment(monitoredFolderService)
                    .preferredColorScheme(.dark)
            }
            .frame(width: 1000, height: 640),
            size: CGSize(width: 1000, height: 640),
            to: outputDir.appendingPathComponent("finder-context-menu.png")
        )

        try renderPNG(
            scriptLibraryShowcaseView()
                .environment(scriptStore)
                .preferredColorScheme(.dark)
                .frame(width: 1100, height: 760),
            size: CGSize(width: 1100, height: 760),
            to: outputDir.appendingPathComponent("script-library.png")
        )

        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("onboarding.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("main-window.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("finder-context-menu.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("script-library.png").path))
    }

    private func screenshotOutputDirectory() throws -> URL {
        let rawOutputDir =
            ProcessInfo.processInfo.environment["SANECLICK_SCREENSHOT_DIR"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let rawOutputDir, !rawOutputDir.isEmpty {
            return URL(fileURLWithPath: rawOutputDir, isDirectory: true)
        }

        if let hintedOutputDir = try? String(contentsOf: outputHintFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !hintedOutputDir.isEmpty
        {
            return URL(fileURLWithPath: hintedOutputDir, isDirectory: true)
        }

        Issue.record("Missing screenshot output directory. Expected SANECLICK_SCREENSHOT_DIR or \(outputHintFile.path).")
        throw CocoaError(.fileNoSuchFile)
    }

    private func welcomeView(licenseService: LicenseService) -> some View {
        WelcomeGateView(
            appName: "SaneClick",
            appIcon: "cursorarrow.click.2",
            freeFeatures: SaneClickWelcomeCopy.freeFeatures,
            proFeatures: SaneClickWelcomeCopy.proFeatures,
            freeTierPrice: SaneClickWelcomeCopy.basicPrice,
            proTierPriceOverride: SaneClickWelcomeCopy.proPrice,
            licenseService: licenseService,
            initialPage: 6
        )
        .preferredColorScheme(.dark)
    }

    private func mainWindowShowcaseView(licenseService: LicenseService) -> some View {
        let essentials = Array(ScriptLibrary.availableScripts(for: .universal).prefix(8))

        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Quick Actions", systemImage: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))

                    QuickActionRow(
                        title: "Browse Library",
                        subtitle: "\(ScriptLibrary.availableAllScripts.count) built-in Finder actions",
                        icon: "books.vertical.fill",
                        color: .saneTeal
                    ) {}

                    QuickActionRow(
                        title: "Unlock Pro",
                        subtitle: "Get 9 more built-in file actions",
                        icon: "lock.open.fill",
                        color: .teal
                    ) {}

                    QuickActionRow(
                        title: "Manage Folders",
                        subtitle: "Choose where SaneClick appears in Finder",
                        icon: "folder.badge.gearshape",
                        color: .green
                    ) {}
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Your Actions", systemImage: "square.stack.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))

                    CategoryRow(category: .universal, totalCount: 9, activeCount: 9)
                    CategoryRow(category: .organization, totalCount: 4, activeCount: 0, isLocked: true)
                    CategoryRow(category: .powerUser, totalCount: 5, activeCount: 0, isLocked: true)
                }

                Spacer()
            }
            .padding(20)
            .frame(width: 300)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(Color.saneNavy.opacity(0.55))

            Rectangle()
                .fill(Color.saneSmoke.opacity(0.45))
                .frame(width: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Essentials")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)

                            HStack(spacing: 4) {
                                Text("9")
                                    .foregroundStyle(Color(red: 0.13, green: 0.77, blue: 0.37))
                                Text("of 9 enabled")
                                    .foregroundStyle(Color.saneSilver)
                            }
                            .font(.subheadline)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Toggle("", isOn: .constant(true))
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .tint(.blue)

                            Text("All On")
                                .font(.caption)
                                .foregroundStyle(Color.saneSilver)
                        }
                    }

                    ForEach(essentials, id: \.name) { script in
                        LibraryScriptRow(
                            libraryScript: script,
                            isInstalled: true,
                            isEnabled: true,
                            categoryColor: .blue,
                            onToggle: { _ in }
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Need more?")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("Unlock Pro for advanced organization, developer, and power-user actions.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.92))

                        HStack(spacing: 12) {
                            Button("Unlock Pro") {}
                                .buttonStyle(.borderedProminent)
                                .tint(.teal)

                            Button("Restore Purchases") {}
                                .buttonStyle(.bordered)
                                .tint(.white)
                        }
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.saneCarbon))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.saneSmoke, lineWidth: 1))
                }
                .padding(24)
            }
            .background(Color.saneNavy.opacity(0.3))
        }
        .preferredColorScheme(.dark)
        .frame(width: 1100, height: 760)
        .background(Color.saneNavy.opacity(0.3))
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

    private func scriptLibraryShowcaseView() -> some View {
        let proCategory = ScriptLibrary.ScriptCategory.organization
        let categoryColor = Color(red: 0.13, green: 0.77, blue: 0.37)
        let proScripts = Array(ScriptLibrary.availableScripts(for: proCategory).prefix(4))

        return VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Script Library")
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 4) {
                        Text("14")
                            .foregroundStyle(Color(red: 0.13, green: 0.77, blue: 0.37))
                        Text("of 18 enabled")
                            .foregroundStyle(Color.saneSilver)
                    }
                    .font(.subheadline)
                }

                Spacer()

                Button("Done") {}
                    .buttonStyle(.borderedProminent)
                    .tint(.saneTeal)
            }
            .padding()

            Divider()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("Search scripts...")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.saneCarbon)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 12) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.saneSilver)
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.saneTeal)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("All Scripts")
                                        .font(.headline)
                                    HStack(spacing: 4) {
                                        Text("14")
                                            .foregroundStyle(Color(red: 0.13, green: 0.77, blue: 0.37))
                                        Text("of 18 enabled")
                                            .foregroundStyle(Color.saneSilver)
                                    }
                                    .font(.caption)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Toggle("", isOn: .constant(false))
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                    .tint(Color.saneTeal)
                                Text("Enable All")
                                    .font(.caption)
                                    .foregroundStyle(Color.saneSilver)
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.saneCarbon))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 12) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .rotationEffect(.degrees(90))
                                    .foregroundStyle(Color.saneSilver)
                                Image(systemName: proCategory.icon)
                                    .font(.title2)
                                    .foregroundStyle(categoryColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(proCategory.rawValue)
                                            .font(.headline)
                                        proBadge
                                    }
                                    Text("\(proScripts.count) scripts included with Pro")
                                        .font(.caption)
                                        .foregroundStyle(Color.saneSilver)
                                }
                            }

                            Spacer()

                            Button {
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 11))
                                    Text("Unlock Pro")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.teal)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(spacing: 8) {
                            ForEach(proScripts, id: \.name) { libraryScript in
                                LibraryScriptRow(
                                    libraryScript: libraryScript,
                                    isInstalled: false,
                                    isEnabled: false,
                                    categoryColor: categoryColor,
                                    isLocked: true,
                                    onToggle: { _ in }
                                )
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.saneCarbon))
                }
                .padding(24)
            }
            .background(Color.saneNavy.opacity(0.3))
        }
        .background(Color.saneNavy.opacity(0.3))
    }

    private var proBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
            Text("Pro")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.teal)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.teal.opacity(0.15))
        .clipShape(Capsule())
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

        guard let bitmap = renderView.bitmapImageRepForCachingDisplay(in: renderView.bounds)
        else {
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
