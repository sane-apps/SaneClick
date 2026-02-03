import AppKit
import os.log

enum ActivationPolicyManager {
    private static let logger = Logger(subsystem: "com.saneclick.SaneClick", category: "ActivationPolicy")

    @MainActor
    static func applyPolicy(showDockIcon: Bool) {
        let policy: NSApplication.ActivationPolicy = showDockIcon ? .regular : .accessory
        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
            logger.info("Applied activation policy: \(policy == .regular ? "regular" : "accessory")")
        }
    }
}
