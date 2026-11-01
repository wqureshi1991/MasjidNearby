import PhotosUI
import SwiftUI

struct ScannedDayEditor: View {
    let title: String
    @Binding var day: TimetableScanViewModel.ScannedDay
    let timeZone: TimeZone
    let onDone: @MainActor () -> Void

    var body: some View {
        NavigationStack {
            Form {
                if !day.flagged.isEmpty {
                    Section {
                        Label("Check \(flaggedNames)", systemImage: "questionmark.circle")
                            .foregroundStyle(.orange)
                    } footer: {
                        Text("These were hard to read, or couldn't be read and were filled in with calculated or published times.")
                    }
                }
                Section("Times") {
                    PrayerTimeRow(title: Prayer.fajr.displayName, prayer: $day.times.fajr, timeZone: timeZone)
                    TimeField(title: "Sunrise", time: $day.times.sunrise, timeZone: timeZone)
                    PrayerTimeRow(title: Prayer.dhuhr.displayName, prayer: $day.times.dhuhr, timeZone: timeZone)
                    PrayerTimeRow(title: Prayer.asr.displayName, prayer: $day.times.asr, timeZone: timeZone)
                    PrayerTimeRow(title: Prayer.maghrib.displayName, prayer: $day.times.maghrib, timeZone: timeZone)
                    PrayerTimeRow(title: Prayer.isha.displayName, prayer: $day.times.isha, timeZone: timeZone)
                }
                if !day.issues.isEmpty {
                    Section {
                        ForEach(day.issues, id: \.self) { issue in
                            Label(issue.description, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                    }
                }
                Section {
                    Toggle("Publish this day", isOn: $day.isIncluded)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
        }
    }

    private var flaggedNames: String {
        TimetableLayout.adhanAndIqamahWithSunrise.slots
            .filter { day.flagged.contains($0) }
            .map { $0.displayName }
            .joined(separator: ", ")
    }
}
