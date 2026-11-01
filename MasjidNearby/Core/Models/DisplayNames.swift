import Foundation

extension Prayer {
    var displayName: String {
        switch self {
        case .fajr: "Fajr"
        case .dhuhr: "Dhuhr"
        case .asr: "Asr"
        case .maghrib: "Maghrib"
        case .isha: "Isha"
        }
    }
}

extension CalculationMethod {
    var displayName: String {
        switch self {
        case .isna: "ISNA (North America)"
        case .muslimWorldLeague: "Muslim World League"
        case .ummAlQura: "Umm al-Qura (Makkah)"
        case .egyptian: "Egyptian General Authority"
        case .karachi: "University of Islamic Sciences, Karachi"
        }
    }
}

extension AsrMadhab {
    var displayName: String {
        switch self {
        case .standard: "Standard (Shafi'i, Maliki, Hanbali)"
        case .hanafi: "Hanafi"
        }
    }
}

extension HighLatitudeRule {
    var displayName: String {
        switch self {
        case .none: "None"
        case .middleOfNight: "Middle of the night"
        case .seventhOfNight: "One-seventh of the night"
        case .twilightAngle: "Twilight angle"
        }
    }
}
