import Foundation
import Sparkle

/// Owns the Sparkle updater for in-app downloads from GitHub Releases.
final class UpdateController {
    static let shared = UpdateController()

    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    private init() {}

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
