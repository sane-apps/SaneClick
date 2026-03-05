import Foundation
#if !APP_STORE
    import Sparkle
#endif
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
    #endif

    // MARK: - Initialization

    override private init() {
        super.init()

        #if !APP_STORE
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
            logger.info("User triggered check for updates")
            updaterController?.checkForUpdates(nil)
        #endif
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            #if !APP_STORE
                updaterController?.updater.automaticallyChecksForUpdates ?? false
            #else
                false
            #endif
        }
        set {
            #if !APP_STORE
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
                updaterController?.updater.updateCheckInterval = newValue.interval
            #endif
        }
    }

    private func normalizeUpdateCheckFrequency() {
        #if !APP_STORE
            guard let updater = updaterController?.updater else { return }
            updater.updateCheckInterval = SaneSparkleCheckFrequency.normalizedInterval(from: updater.updateCheckInterval)
        #endif
    }
}
