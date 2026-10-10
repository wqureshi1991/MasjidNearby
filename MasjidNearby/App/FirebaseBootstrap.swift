import FirebaseCore
import Foundation
import OSLog

/// Configures Firebase only when `GoogleService-Info.plist` is bundled,
/// so the app still runs, on in-memory auth, before the Firebase project exists.
enum FirebaseBootstrap {
    private static let logger = Logger(subsystem: "com.waqarqureshi.MasjidNearby", category: "Firebase")

    /// Returns whether Firebase is configured and its services can be used.
    @MainActor
    static func configureIfAvailable() -> Bool {
        if FirebaseApp.app() != nil {
            return true
        }
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            logger.warning("GoogleService-Info.plist not found. Using in-memory auth.")
            return false
        }
        FirebaseApp.configure()
        return true
    }
}
