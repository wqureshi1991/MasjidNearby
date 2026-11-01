import Foundation
import Observation

enum TimetableScanError: LocalizedError, Sendable {
    case imageUnavailable
    case noRowsFound

    var errorDescription: String? {
        switch self {
        case .imageUnavailable:
            "That photo couldn't be loaded. Try another one."
        case .noRowsFound:
            "No prayer times were found. Try a straight, well-lit photo that shows the whole timetable."
        }
    }
}
