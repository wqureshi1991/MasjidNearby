import Foundation
import Observation

/// Hands the masjid of a tapped prayer alert to whichever flow can show it. Holds the tap
/// until then, so a tap that launches the app still opens the masjid once the user flow appears.
@MainActor
@Observable
final class AlertTapRouter {
    private(set) var pendingMasjidID: String?

    func alertTapped(masjidID: String) {
        pendingMasjidID = masjidID
    }

    /// Returns the pending masjid ID and clears it, so each tap is handled once.
    func takePendingMasjidID() -> String? {
        defer { pendingMasjidID = nil }
        return pendingMasjidID
    }
}
