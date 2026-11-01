import Foundation

enum PrayerCalculationError: Error, Sendable, Equatable {
    case invalidCoordinates
    case invalidTimeZone
    /// Polar day or polar night: there is no sunrise or sunset on this date.
    case sunDoesNotRiseOrSet
    /// The Fajr or Isha angle is never reached and no high-latitude rule is set.
    case twilightDoesNotOccur
}
