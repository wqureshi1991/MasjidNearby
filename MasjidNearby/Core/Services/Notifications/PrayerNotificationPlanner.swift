import Foundation

/// Works out which prayer alerts to schedule.
enum PrayerNotificationPlanner {
    /// iOS keeps at most 64 pending notifications per app; leave room for others.
    static let maximumPending = 60
    static let daysAhead = 7

    /// The next alerts, soonest first, at most `maximumPending`. Days without saved times
    /// use calculated times.
    static func notifications(for schedules: [MasjidSchedule],
                              settings: PrayerAlertSettings,
                              calculator: any PrayerTimeCalculator,
                              now: Date) -> [PrayerNotification] {
        guard settings.isEnabled, !settings.prayers.isEmpty else { return [] }
        let resolver = PrayerTimeResolver(calculator: calculator)
        var planned: [PrayerNotification] = []

        for schedule in schedules where settings[alertsForMasjid: schedule.masjid.id] {
            let masjid = schedule.masjid
            guard let timeZone = masjid.timeZone else { continue }
            let published = Dictionary(schedule.published.map { ($0.day, $0) }, uniquingKeysWith: { _, latest in latest })
            let today = CalendarDay(date: now, in: timeZone)
            // From yesterday: its Isha can fall after midnight, today.
            for offset in -1..<daysAhead {
                let day = today.adding(days: offset)
                guard let times = try? resolver.times(for: masjid, on: day, published: published[day]) else { continue }
                for prayer in Prayer.allCases where settings[alertsFor: prayer] {
                    let time = times[prayer]
                    let adhan = adhanInstant(of: prayer, in: times, on: day, timeZone: timeZone)
                    planned.append(PrayerNotification(masjidID: masjid.id, masjidName: masjid.name, prayer: prayer,
                                                      kind: .adhan, fireDate: adhan, timeZone: timeZone))
                    if settings.alertsAtIqamah, let iqamah = time.iqamah {
                        let fireDate = adhan.addingTimeInterval(Double(time.adhan.minutes(until: iqamah) * 60))
                        planned.append(PrayerNotification(masjidID: masjid.id, masjidName: masjid.name, prayer: prayer,
                                                          kind: .iqamah, fireDate: fireDate, timeZone: timeZone))
                    }
                }
            }
        }

        let upcoming = planned.filter { $0.fireDate > now }.sorted { $0.fireDate < $1.fireDate }
        return Array(upcoming.prefix(maximumPending))
    }

    private static func adhanInstant(of prayer: Prayer, in times: DailyPrayerTimes,
                                     on day: CalendarDay, timeZone: TimeZone) -> Date {
        // An Isha earlier than Maghrib is after midnight, on the next calendar day.
        let isAfterMidnight = prayer == .isha && times.isha.adhan < times.maghrib.adhan
        return times[prayer].adhan.instant(on: isAfterMidnight ? day.adding(days: 1) : day, in: timeZone)
    }
}
