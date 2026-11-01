import Foundation

/// A masjid the user saved, as stored on the device.
struct FavoriteMasjid: Sendable, Equatable, Identifiable {
    let masjid: Masjid
    let addedAt: Date
    /// When its schedule was last downloaded for offline use.
    let lastSyncedAt: Date?

    var id: String { masjid.id }
}
