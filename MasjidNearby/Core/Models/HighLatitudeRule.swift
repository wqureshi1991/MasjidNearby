import Foundation

/// What to do where twilight lasts all night, or nearly, and Fajr/Isha angles are never reached.
enum HighLatitudeRule: String, Sendable, Hashable, Codable, CaseIterable {
    /// No adjustment. Calculation fails where the angle is never reached.
    case none
    /// Fajr and Isha are at most half the night from sunrise and sunset.
    case middleOfNight
    /// Fajr and Isha are at most one seventh of the night from sunrise and sunset.
    case seventhOfNight
    /// The night portion is angle / 60 of the night.
    case twilightAngle
}
