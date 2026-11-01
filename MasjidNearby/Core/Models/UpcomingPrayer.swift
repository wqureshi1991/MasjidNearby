import Foundation

struct UpcomingPrayer: Sendable, Equatable {
    let prayer: Prayer
    let adhan: Date
    let iqamah: Date?
    /// True when it's tomorrow's Fajr, after tonight's Isha.
    let isTomorrow: Bool
}
