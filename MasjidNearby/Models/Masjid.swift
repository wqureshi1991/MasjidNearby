import Foundation

struct JumuahSlot: Sendable, Hashable, Codable {
    let khutbah: WallClockTime
    let iqamah: WallClockTime?

    init(khutbah: WallClockTime, iqamah: WallClockTime? = nil) {
        self.khutbah = khutbah
        self.iqamah = iqamah
    }
}

struct Masjid: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let address: String
    let coordinates: Coordinates
    /// IANA identifier, e.g. "America/Los_Angeles". All of this masjid's times are in this zone.
    let timeZoneIdentifier: String
    let calculation: CalculationParameters
    /// Many masjids hold more than one Jumu'ah.
    let jumuah: [JumuahSlot]
    let isVerified: Bool

    var timeZone: TimeZone? {
        TimeZone(identifier: timeZoneIdentifier)
    }
}
