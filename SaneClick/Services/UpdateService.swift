import Foundation
#if !APP_STORE
    import Sparkle
#endif
import os.log

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
}
