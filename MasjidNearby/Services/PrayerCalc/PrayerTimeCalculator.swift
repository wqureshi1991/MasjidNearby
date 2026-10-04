import Foundation

enum PrayerCalculationError: Error, Sendable, Equatable {
    case invalidCoordinates
    case invalidTimeZone
    /// Polar day or polar night: there is no sunrise or sunset on this date.
    case sunDoesNotRiseOrSet
    /// The Fajr or Isha angle is never reached and no high-latitude rule is set.
    case twilightDoesNotOccur
}

protocol PrayerTimeCalculator: Sendable {
    /// Times for `day` at `coordinates`, expressed in `timeZone`'s wall-clock time.
    func times(on day: CalendarDay,
               at coordinates: Coordinates,
               in timeZone: TimeZone,
               parameters: CalculationParameters) throws -> DailyPrayerTimes
}
