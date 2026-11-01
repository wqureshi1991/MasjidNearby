import Foundation
import OSLog
import SwiftData

/// A saved masjid. Details are kept as a JSON snapshot of `Masjid` so the schema
/// doesn't have to mirror every field.
@Model
final class FavoriteMasjidRecord {
    @Attribute(.unique) var masjidID: String
    var masjidData: Data
    var addedAt: Date
    var lastSyncedAt: Date?

    init(masjidID: String, masjidData: Data, addedAt: Date, lastSyncedAt: Date? = nil) {
        self.masjidID = masjidID
        self.masjidData = masjidData
        self.addedAt = addedAt
        self.lastSyncedAt = lastSyncedAt
    }
}
