import Foundation

/// Decides which times to show for a masjid on a day:
/// the schedule the masjid published if there is one, otherwise times calculated from its location.
struct PrayerTimeResolver: Sendable {
    let calculator: any PrayerTimeCalculator

    func times(for masjid: Masjid, on day: CalendarDay, published: DailyPrayerTimes?) throws -> DailyPrayerTimes {
        if let published, published.day == day {
            return published
        }
        guard let timeZone = masjid.timeZone else {
            throw PrayerCalculationError.invalidTimeZone
        }
        return try calculator.times(on: day, at: masjid.coordinates, in: timeZone, parameters: masjid.calculation)
    }
}
