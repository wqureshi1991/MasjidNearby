import Foundation

/// Returns a canned result or throws a canned error. For tests and previews.
struct MockPrayerTimeCalculator: PrayerTimeCalculator {
    let result: Result<DailyPrayerTimes, PrayerCalculationError>

    func times(on day: CalendarDay,
               at coordinates: Coordinates,
               in timeZone: TimeZone,
               parameters: CalculationParameters) throws -> DailyPrayerTimes {
        try result.get()
    }
}
