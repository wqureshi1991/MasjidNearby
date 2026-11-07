import Foundation

/// What the user wants to be alerted about. Stored on the device.
struct PrayerAlertSettings: Sendable, Equatable, Codable {
    var isEnabled = false
    var prayers: Set<Prayer> = Set(Prayer.allCases)
    var alertsAtIqamah = false
    /// Favorites the user switched alerts off for. New favorites get alerts by default.
    var mutedMasjidIDs: Set<String> = []

    /// Whether `prayer` gets alerts. Lets views bind a toggle per prayer.
    subscript(alertsFor prayer: Prayer) -> Bool {
        get { prayers.contains(prayer) }
        set {
            if newValue {
                prayers.insert(prayer)
            } else {
                prayers.remove(prayer)
            }
        }
    }

    /// Whether the masjid with `id` gets alerts. Lets views bind a toggle per masjid.
    subscript(alertsForMasjid id: String) -> Bool {
        get { !mutedMasjidIDs.contains(id) }
        set {
            if newValue {
                mutedMasjidIDs.remove(id)
            } else {
                mutedMasjidIDs.insert(id)
            }
        }
    }
}
