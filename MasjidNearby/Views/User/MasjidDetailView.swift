import SwiftUI

struct MasjidDetailView: View {
    @State private var viewModel: MasjidDetailViewModel
    /// Advanced every 30 seconds so "next prayer" moves on by itself.
    @State private var now = Date()

    init(viewModel: MasjidDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            headerSection
            switch viewModel.state {
            case .idle, .loading:
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            case .failed(let error):
                Section {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                    Button("Try Again") {
                        Task { await viewModel.load() }
                    }
                }
            case .loaded(let schedule):
                nextPrayerSection(viewModel.upcoming(at: now))
                todaySection(schedule.today, next: viewModel.upcoming(at: now))
                if !viewModel.masjid.jumuah.isEmpty {
                    jumuahSection
                }
            }
        }
        .navigationTitle(viewModel.masjid.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .task {
            await advanceClock()
        }
        .refreshable {
            await viewModel.load()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.masjid.name)
                    .font(.title3.bold())
                Text(viewModel.masjid.address)
                    .foregroundStyle(.secondary)
                if let distance = viewModel.formattedDistance {
                    Text("\(distance) away")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let url = viewModel.directionsURL {
                Link(destination: url) {
                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                }
            }
            if let notice = viewModel.notice {
                Label(notice, systemImage: "wifi.exclamationmark")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func nextPrayerSection(_ upcoming: UpcomingPrayer?) -> some View {
        if let upcoming {
            Section("Next Prayer") {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(upcoming.isTomorrow ? "\(upcoming.prayer.displayName) (tomorrow)" : upcoming.prayer.displayName)
                            .font(.title2.bold())
                        Text(upcoming.adhan, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(format(upcoming.adhan))
                            .font(.title2.monospacedDigit())
                        if let iqamah = upcoming.iqamah {
                            Text("Iqamah \(format(iqamah))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func todaySection(_ today: DailyPrayerTimes, next upcoming: UpcomingPrayer?) -> some View {
        Section {
            PrayerScheduleRow(name: Prayer.fajr.displayName, time: today.fajr, viewModel: viewModel,
                              isNext: isNext(.fajr, upcoming))
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
                                  isNext: isNext(prayer, upcoming))
            }
        } header: {
            HStack {
                Text("Today")
                Spacer()
                Text("Adhan · Iqamah")
            }
        } footer: {
            if today.source == .calculated {
                Text("This masjid hasn't published today's times. These are calculated for its location, without iqamah.")
            } else {
                Text("Times are in \(viewModel.timeZone.identifier).")
            }
        }
    }

    private var jumuahSection: some View {
        Section("Jumu'ah") {
            ForEach(Array(viewModel.masjid.jumuah.enumerated()), id: \.offset) { _, slot in
                HStack {
                    Text("Khutbah \(viewModel.formatted(slot.khutbah))")
                    Spacer()
                    if let iqamah = slot.iqamah {
                        Text("Iqamah \(viewModel.formatted(iqamah))")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func advanceClock() async {
        while !Task.isCancelled {
            now = Date()
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                return
            }
        }
    }

    private func isNext(_ prayer: Prayer, _ upcoming: UpcomingPrayer?) -> Bool {
        guard let upcoming, !upcoming.isTomorrow else { return false }
        return upcoming.prayer == prayer
    }

    private func format(_ date: Date) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = viewModel.timeZone
        return date.formatted(style)
    }
}

private struct PrayerScheduleRow: View {
    let name: String
    let time: PrayerTime
    let viewModel: MasjidDetailViewModel
    let isNext: Bool

    var body: some View {
        HStack {
            Text(name)
                .fontWeight(isNext ? .bold : .regular)
            Spacer()
            Text(viewModel.formatted(time.adhan))
                .monospacedDigit()
                .frame(minWidth: 72, alignment: .trailing)
            Text(time.iqamah.map { viewModel.formatted($0) } ?? "—")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 72, alignment: .trailing)
        }
        .foregroundStyle(isNext ? Color.accentColor : Color.primary)
        .accessibilityElement(children: .combine)
    }
}
