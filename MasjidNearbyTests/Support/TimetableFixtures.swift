import Foundation
import Testing
@testable import MasjidNearby

enum TimetableFixtures {
    /// A US-style timetable: 12-hour times without am/pm, OCR slips on day 3,
    /// a Hijri date on day 5, and header and footer lines.
    static let usLines = [
        "Masjid Al-Noor  October 2026",
        "Date Day Fajr Sunrise Dhuhr Asr Maghrib Isha",
        "1 Thu 5:42 6:58 12:57 4:17 6:49 8:01",
        "2 Fri 5:43 6:59 12:57 4:16 6:48 8:00",
        "3 Sat 5:4O 7:0l 12:57 4:15 6:46 7:58",
        "4 Sun 5:45am 7:02am 12:56pm 4:14pm 6:45pm 7:57pm",
        "5 Mon 23 5:46 7:03 12:56 4:13 6:44 7:56",
        "Jumuah 1:15pm and 2:30pm",
        "Tel 408 555 1234",
    ]

    /// A UK-style timetable: 24-hour adhan and iqamah, a dot separator, one short row.
    static let ukLines = [
        "21 Tue 05:42 06:10 07:04 12:57 13:30 15:46 16:15 18:49 18:54 20:01 20:30",
        "22 Wed 05.43 06:10 07:05 12:57 13:30 15:45 16:15 18:47 18:52 19:59 20:30",
        "23 Thu 05:44 06:10 07:06 12:57 13:30 15:44 16:15 18:46 18:51 19:58",
        "1:15 Jumuah",
    ]

    static func t(_ string: String) -> WallClockTime { Fixtures.time(string) }
}
