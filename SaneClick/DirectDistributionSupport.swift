#if os(macOS) && !APP_STORE && !SETAPP
import AppKit
import SaneUI
import SwiftUI

extension LicenseService.DirectCopy {
    static let saneClick = Self(
        alternateUnlockLabel: "Buy SaneClick",
        alternateEntryLabel: "Enter License Key",
        accessManagementLabel: "Deactivate License",
        alternateEntryInstruction: "Paste your activation code from the confirmation email."
    )
}

enum SaneClickInstallPrompt {
    static let standard = SaneAppMover.Prompt(
        messageText: "Move to Applications?",
        informativeText: "{appName} works best from your Applications folder. Move it there now? You may be asked for your password.",
        moveButtonTitle: "Move to Applications",
        cancelButtonTitle: "Not Now"
    )
}

/// Direct-download support link. The shared library ships no title or
/// destination of its own, so the direct build supplies them at launch.
enum SaneClickDirectSupport {
    @MainActor
    static func install() {
        SaneDirectSupportCopy.current = SaneDirectSupportCopy(
            buttonTitle: "Donate",
            buttonHelp: "Donate on GitHub Sponsors",
            accessibilityLabel: "Donate",
            destinationURL: URL(string: "https://github.com/sponsors/MrSaneApps")!,
            aboutRowTitle: "Donate",
            freeAppTitle: "This app is free now",
            freeAppDetail: "Every feature stays unlocked. Donate only if you want to support it.",
            welcomeIncludedDetail: "Every feature is included. Setup stays the same. Donate only if you want to support it.",
            expiredOpenSourceDetail: "SaneApps open-sourced this app. Every feature stays unlocked. Donate only if you want to support it.",
            expiredCardTitle: "Donate",
            expiredCardSubtitle: "Optional. The app stays free."
        )
    }
}

enum SaneAppMover {
    typealias Prompt = SaneApplicationMover.Prompt

    @MainActor
    @discardableResult
    static func moveToApplicationsFolderIfNeeded(prompt: Prompt) -> Bool {
        SaneApplicationMover.moveToApplicationsFolderIfNeeded(prompt: prompt)
    }
}

#endif
