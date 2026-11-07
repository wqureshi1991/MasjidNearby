import SwiftUI

/// Today's adhan and iqamah times, with the next prayer highlighted.
struct TodayScheduleSection: View {
    let today: DailyPrayerTimes
    let upcoming: UpcomingPrayer?
    let viewModel: MasjidDetailViewModel

    var body: some View {
        Section {
            PrayerScheduleRow(name: Prayer.fajr.displayName, time: today.fajr, viewModel: viewModel,
                              isNext: viewModel.isNext(.fajr, upcoming: upcoming))
            HStack {
                Text("Sunrise")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.formatted(today.sunrise))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ForEach([Prayer.dhuhr, .asr, .maghrib, .isha], id: \.self) { prayer in
                PrayerScheduleRow(name: prayer.displayName, time: today[prayer], viewModel: viewModel,
                                  isNext: viewModel.isNext(prayer, upcoming: upcoming))
            }
        } header: {
            HStack {
                Text("Today")
                Spacer()
                Text("Adhan · Iqamah")
            }
        } footer: {
            Text(viewModel.todayFooter(for: today))
        }
    }
}
