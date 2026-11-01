import SwiftUI

/// A time-of-day picker bound to a `WallClockTime`, shown in the masjid's time zone
/// whatever zone the device is in.
struct TimeField: View {
    let title: String
    @Binding var time: WallClockTime
    let timeZone: TimeZone

    var body: some View {
        DatePicker(title, selection: dateSelection, displayedComponents: .hourAndMinute)
            .environment(\.timeZone, timeZone)
    }

    private var dateSelection: Binding<Date> {
        // Capture plain values, not `self`, so the closures don't depend on the view's isolation.
        let time = $time
        let zone = timeZone
        return Binding(
            get: { time.wrappedValue.pickerDate(in: zone) },
            set: { time.wrappedValue = WallClockTime(date: $0, in: zone) }
        )
    }
}
