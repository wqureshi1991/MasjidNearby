import SwiftUI

/// An adhan time plus an optional iqamah time.
struct PrayerTimeRow: View {
    let title: String
    @Binding var prayer: EditablePrayer
    let timeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading) {
            TimeField(title: "\(title) adhan", time: $prayer.adhan, timeZone: timeZone)
            Toggle("Iqamah", isOn: $prayer.hasIqamah)
            if prayer.hasIqamah {
                TimeField(title: "\(title) iqamah", time: $prayer.iqamah, timeZone: timeZone)
            }
        }
    }
}
