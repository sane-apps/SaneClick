#if !APP_STORE
import AppKit
import Foundation
    import Sparkle
import os.log
import SaneUI

private let logger = Logger(subsystem: "com.saneclick.SaneClick", category: "UpdateService")

/// Wrapper around Sparkle's SPUStandardUpdaterController.
/// Handles app updates securely and privately.
@MainActor
final class UpdateService: NSObject, ObservableObject {
    // MARK: - Singleton

    static let shared = UpdateService()

    // MARK: - Properties

    #if !APP_STORE
        private var updaterController: SPUStandardUpdaterController?
        private let updateEligibility: SaneUpdateEligibility
    #endif

    // MARK: - Initialization

    override private init() {
        #if !APP_STORE
            self.updateEligibility = Self.sparkleUpdateEligibility(
                bundleIdentifier: Bundle.main.bundleIdentifier,
                bundlePath: Bundle.main.bundlePath
            )
        #endif
        super.init()

        #if !APP_STORE
            guard updateEligibility.canUseInAppUpdates else {
                logger.info("Sparkle disabled: \(self.updateEligibility.userFacingStatus, privacy: .public)")
                return
            }

            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
            normalizeUpdateCheckFrequency()
            logger.info("Sparkle updater initialized")

            if let profiling = Bundle.main.object(forInfoDictionaryKey: "SUEnableSystemProfiling") as? Bool,
               profiling == true {
                logger.fault("CRITICAL: SUEnableSystemProfiling is ENABLED. This violates the privacy policy.")
            }
        #endif
    }

    // MARK: - Public API

    func checkForUpdates() {
        #if !APP_STORE
            guard updateEligibility.canUseInAppUpdates else {
                logger.info("Ignoring Check for Updates: \(self.updateEligibility.userFacingStatus, privacy: .public)")
                NSSound.beep()
                return
            }
            logger.info("User triggered check for updates")
            updaterController?.checkForUpdates(nil)
        #endif
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            #if !APP_STORE
                updateEligibility.canUseInAppUpdates && (updaterController?.updater.automaticallyChecksForUpdates ?? false)
            #else
                false
            #endif
        }
        set {
            #if !APP_STORE
                guard updateEligibility.canUseInAppUpdates else { return }
                updaterController?.updater.automaticallyChecksForUpdates = newValue
            #endif
        }
    }

    var updateCheckFrequency: SaneSparkleCheckFrequency {
        get {
            #if !APP_STORE
                let interval = updaterController?.updater.updateCheckInterval ?? SaneSparkleCheckFrequency.daily.interval
                return SaneSparkleCheckFrequency.resolve(updateCheckInterval: interval)
            #else
                .daily
            #endif
        }
        set {
            #if !APP_STORE
                guard updateEligibility.canUseInAppUpdates else { return }
                updaterController?.updater.updateCheckInterval = newValue.interval
            #endif
        }
    }

    #if !APP_STORE
        var isUpdateChannelEnabled: Bool {
            updateEligibility.canUseInAppUpdates
        }

        var updateUnavailableStatus: String {
            updateEligibility.userFacingStatus
        }

        var isMissingApplicationsInstall: Bool {
            updateEligibility == .notInstalledInApplications
        }

        nonisolated static let releaseBundleIdentifier = "com.saneclick.SaneClick"

        nonisolated static func sparkleUpdateEligibility(
            bundleIdentifier: String?,
            bundlePath: String = Bundle.main.bundlePath,
            homeDirectory: String = NSHomeDirectory()
        ) -> SaneUpdateEligibility {
            SaneUpdateEligibility.resolve(
                bundleIdentifier: bundleIdentifier,
                releaseBundleIdentifier: releaseBundleIdentifier,
                bundlePath: bundlePath,
                homeDirectory: homeDirectory
            )
        }
    #endif

    private func normalizeUpdateCheckFrequency() {
        guard let updater = updaterController?.updater else { return }
        updater.updateCheckInterval = SaneSparkleCheckFrequency.normalizedInterval(from: updater.updateCheckInterval)
    }
}
#endif
