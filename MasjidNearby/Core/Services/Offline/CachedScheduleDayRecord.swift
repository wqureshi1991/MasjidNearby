import Foundation
import OSLog
import SwiftData

/// One cached day of a favorite's published schedule, as a JSON snapshot of `DailyPrayerTimes`.
@Model
final class CachedScheduleDayRecord {
    /// "masjidID|yyyy-MM-dd".
    @Attribute(.unique) var key: String
    var masjidID: String
    var dayKey: String
    var timesData: Data

    init(masjidID: String, dayKey: String, timesData: Data) {
        self.key = "\(masjidID)|\(dayKey)"
        self.masjidID = masjidID
        self.dayKey = dayKey
        self.timesData = timesData
    }
}
