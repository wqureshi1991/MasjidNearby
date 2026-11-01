import Foundation

enum MasjidDraftProblem: Sendable, Hashable, CustomStringConvertible {
    case missingName
    case missingAddress
    case missingLocation
    case unknownTimeZone
    case jumuahIqamahBeforeKhutbah

    var description: String {
        switch self {
        case .missingName: "Enter the masjid's name."
        case .missingAddress: "Enter the masjid's address."
        case .missingLocation: "Set the masjid's location on the map."
        case .unknownTimeZone: "Choose a valid time zone."
        case .jumuahIqamahBeforeKhutbah: "Each Jumu'ah iqamah must be after its khutbah."
        }
    }
}
