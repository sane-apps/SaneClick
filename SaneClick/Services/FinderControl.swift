import Foundation
import os.log

enum FinderControl {
    private static let logger = Logger(subsystem: "com.saneclick.SaneClick", category: "FinderControl")

    static func restartFinder() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]

        do {
            try process.run()
            process.waitUntilExit()
            logger.info("Restarted Finder (exit: \(process.terminationStatus))")
        } catch {
            logger.error("Failed to restart Finder: \(error.localizedDescription)")
        }
    }
}
