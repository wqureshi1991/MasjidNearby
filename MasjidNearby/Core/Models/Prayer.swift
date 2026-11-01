import Foundation

enum Prayer: String, Sendable, Hashable, Codable, CaseIterable {
    case fajr
    case dhuhr
    case asr
    case maghrib
    case isha
}
