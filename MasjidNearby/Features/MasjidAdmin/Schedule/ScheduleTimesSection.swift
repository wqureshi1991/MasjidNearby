import SwiftUI

/// The selected day's adhan and iqamah times.
struct ScheduleTimesSection: View {
    @Bindable var viewModel: ScheduleEditorViewModel

    var body: some View {
        Section("Times") {
            PrayerTimeRow(title: Prayer.fajr.displayName, prayer: $viewModel.editingDay.fajr, timeZone: viewModel.timeZone)
            TimeField(title: "Sunrise", time: $viewModel.editingDay.sunrise, timeZone: viewModel.timeZone)
            PrayerTimeRow(title: Prayer.dhuhr.displayName, prayer: $viewModel.editingDay.dhuhr, timeZone: viewModel.timeZone)
            PrayerTimeRow(title: Prayer.asr.displayName, prayer: $viewModel.editingDay.asr, timeZone: viewModel.timeZone)
            PrayerTimeRow(title: Prayer.maghrib.displayName, prayer: $viewModel.editingDay.maghrib, timeZone: viewModel.timeZone)
            PrayerTimeRow(title: Prayer.isha.displayName, prayer: $viewModel.editingDay.isha, timeZone: viewModel.timeZone)
        }
    }
}
