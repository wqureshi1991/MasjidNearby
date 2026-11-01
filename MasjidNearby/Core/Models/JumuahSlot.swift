import Foundation

struct JumuahSlot: Sendable, Hashable, Codable {
    let khutbah: WallClockTime
    let iqamah: WallClockTime?

    init(khutbah: WallClockTime, iqamah: WallClockTime? = nil) {
        self.khutbah = khutbah
        self.iqamah = iqamah
    }
}
