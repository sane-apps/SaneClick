#if os(macOS) && !APP_STORE && !SETAPP
import AppKit
import SaneUI
import SwiftUI

extension LicenseService.DirectCopy {
    static let saneClick = Self(
        alternateUnlockLabel: "Unlock Pro",
        alternateEntryLabel: "Enter License Key",
        accessManagementLabel: "Deactivate Pro",
        alternateEntryInstruction: "Paste your activation code from the confirmation email."
    )
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
