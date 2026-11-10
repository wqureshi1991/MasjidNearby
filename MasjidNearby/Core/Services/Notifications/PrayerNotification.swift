import Foundation

/// One alert for one prayer at one masjid.
struct PrayerNotification: Sendable, Equatable, Identifiable {
    enum Kind: String, Sendable {
        case adhan
        case iqamah
    }

    /// Every prayer alert's identifier starts with this, so they can be replaced without
    /// touching any other notification.
    static let identifierPrefix = "prayer-alert."
    /// The `userInfo` key holding the masjid's ID, so a tapped alert can open it.
    static let masjidIDKey = "masjidID"

    let masjidID: String
    let masjidName: String
    let prayer: Prayer
    let kind: Kind
    let fireDate: Date
    /// The masjid's time zone, for the time shown in the alert.
    let timeZone: TimeZone

    var id: String {
        "\(Self.identifierPrefix)\(masjidID).\(Int(fireDate.timeIntervalSince1970)).\(prayer.rawValue).\(kind.rawValue)"
    }

    var title: String {
        "\(prayer.displayName) · \(masjidName)"
    }

    var body: String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        let time = fireDate.formatted(style)
        return switch kind {
        case .adhan: "Adhan at \(time)"
        case .iqamah: "Iqamah at \(time)"
        }
    }
}
