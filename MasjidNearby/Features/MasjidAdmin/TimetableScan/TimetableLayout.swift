import Foundation

/// The column layouts masjid timetables commonly use, left to right after the date.
enum TimetableLayout: String, Sendable, CaseIterable, Identifiable {
    case adhanWithSunrise
    case adhanOnly
    case adhanAndIqamahWithSunrise
    case adhanAndIqamah

    var id: String { rawValue }

    var slots: [TimetableSlot] {
        switch self {
        case .adhanWithSunrise:
            [.adhan(.fajr), .sunrise, .adhan(.dhuhr), .adhan(.asr), .adhan(.maghrib), .adhan(.isha)]
        case .adhanOnly:
            [.adhan(.fajr), .adhan(.dhuhr), .adhan(.asr), .adhan(.maghrib), .adhan(.isha)]
        case .adhanAndIqamahWithSunrise:
            [.adhan(.fajr), .iqamah(.fajr), .sunrise, .adhan(.dhuhr), .iqamah(.dhuhr), .adhan(.asr), .iqamah(.asr),
             .adhan(.maghrib), .iqamah(.maghrib), .adhan(.isha), .iqamah(.isha)]
        case .adhanAndIqamah:
            [.adhan(.fajr), .iqamah(.fajr), .adhan(.dhuhr), .iqamah(.dhuhr), .adhan(.asr), .iqamah(.asr),
             .adhan(.maghrib), .iqamah(.maghrib), .adhan(.isha), .iqamah(.isha)]
        }
    }

    var displayName: String {
        switch self {
        case .adhanWithSunrise: "Adhan with sunrise (6 times)"
        case .adhanOnly: "Adhan only (5 times)"
        case .adhanAndIqamahWithSunrise: "Adhan and iqamah with sunrise (11 times)"
        case .adhanAndIqamah: "Adhan and iqamah (10 times)"
        }
    }
}
