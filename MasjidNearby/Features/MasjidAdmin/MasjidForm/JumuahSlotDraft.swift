import Foundation

/// An editable Jumu'ah slot. Identifiable so a form can list and remove slots.
struct JumuahSlotDraft: Sendable, Hashable, Identifiable {
    let id: UUID
    var khutbah: WallClockTime
    var hasIqamah: Bool
    var iqamah: WallClockTime

    init(id: UUID = UUID(), khutbah: WallClockTime, iqamah: WallClockTime?) {
        self.id = id
        self.khutbah = khutbah
        self.hasIqamah = iqamah != nil
        self.iqamah = iqamah ?? khutbah.adding(minutes: 15)
    }

    init(_ slot: JumuahSlot) {
        self.init(khutbah: slot.khutbah, iqamah: slot.iqamah)
    }

    var slot: JumuahSlot {
        JumuahSlot(khutbah: khutbah, iqamah: hasIqamah ? iqamah : nil)
    }
}
