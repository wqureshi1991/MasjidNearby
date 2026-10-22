import Foundation

enum ScheduleIssue: Sendable, Hashable, CustomStringConvertible {
    /// `earlier` should come before `later` but doesn't.
    case outOfOrder(earlier: String, later: String)
    case iqamahBeforeAdhan(Prayer)
    case iqamahTooLate(Prayer)

    var description: String {
        switch self {
        case .outOfOrder(let earlier, let later):
            "\(earlier) must be before \(later)."
        case .iqamahBeforeAdhan(let prayer):
            "\(prayer.displayName) iqamah is before its adhan."
        case .iqamahTooLate(let prayer):
            "\(prayer.displayName) iqamah is more than \(ScheduleValidator.maximumIqamahDelay) minutes after its adhan."
        }
    }
}

/// Catches typing mistakes before a schedule is published.
enum ScheduleValidator {
    static let maximumIqamahDelay = 120

    static func issues(in times: DailyPrayerTimes) -> [ScheduleIssue] {
        var issues: [ScheduleIssue] = []

        let sequence: [(String, WallClockTime)] = [
            (Prayer.fajr.displayName, times.fajr.adhan),
            ("Sunrise", times.sunrise),
            (Prayer.dhuhr.displayName, times.dhuhr.adhan),
            (Prayer.asr.displayName, times.asr.adhan),
            (Prayer.maghrib.displayName, times.maghrib.adhan),
        ]
        for (earlier, later) in zip(sequence, sequence.dropFirst()) where earlier.1 >= later.1 {
            issues.append(.outOfOrder(earlier: earlier.0, later: later.0))
        }
        // Isha is after Maghrib, or after midnight (earlier than Fajr) at high latitudes.
        let isha = times.isha.adhan
        if !(isha > times.maghrib.adhan || isha < times.fajr.adhan) {
            issues.append(.outOfOrder(earlier: Prayer.maghrib.displayName, later: Prayer.isha.displayName))
        }

        for prayer in Prayer.allCases {
            let time = times[prayer]
            guard let iqamah = time.iqamah else { continue }
            let delay = time.adhan.minutes(until: iqamah)
            if delay > 12 * 60 {
                issues.append(.iqamahBeforeAdhan(prayer))
            } else if delay > maximumIqamahDelay {
                issues.append(.iqamahTooLate(prayer))
            }
        }
        return issues
    }
}
