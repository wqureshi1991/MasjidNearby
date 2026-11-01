import Foundation

protocol PrayerTimeCalculator: Sendable {
    /// Times for `day` at `coordinates`, expressed in `timeZone`'s wall-clock time.
    func times(on day: CalendarDay,
               at coordinates: Coordinates,
               in timeZone: TimeZone,
               parameters: CalculationParameters) throws -> DailyPrayerTimes
}
