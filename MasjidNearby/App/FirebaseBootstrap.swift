import FirebaseCore
import Foundation
import OSLog

/// Configures Firebase only when `GoogleService-Info.plist` is bundled,
/// so the scaffold runs before the Firebase project exists.
enum FirebaseBootstrap {
    private static let logger = Logger(subsystem: "com.waqarqureshi.MasjidNearby", category: "Firebase")

    @MainActor
    static func configureIfAvailable() {
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            logger.warning("GoogleService-Info.plist not found. Firebase is not configured.")
            return
        }
        FirebaseApp.configure()
    }
}
