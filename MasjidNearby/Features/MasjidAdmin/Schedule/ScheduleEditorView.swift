import SwiftUI

struct ScheduleEditorView: View {
    @State private var viewModel: ScheduleEditorViewModel

    init(viewModel: ScheduleEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            daySection
            timesSection
            if !viewModel.issues.isEmpty {
                Section {
                    ForEach(viewModel.issues, id: \.self) { issue in
                        Label(issue.description, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            copySection
            publishSection
        }
        .navigationTitle("Prayer Times")
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Sections

    private var daySection: some View {
        Section {
            HStack {
                Button {
                    viewModel.goToPreviousDay()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!viewModel.canGoBack)
                .accessibilityLabel("Previous day")

                Spacer()
                DatePicker("Day", selection: daySelection, in: dayRange, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.timeZone, .gmt)
                Spacer()

                Button {
                    viewModel.goToNextDay()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!viewModel.canGoForward)
                .accessibilityLabel("Next day")
            }
            .buttonStyle(.borderless)

            Label(statusText, systemImage: statusSymbol)
                .foregroundStyle(.secondary)
            if let error = viewModel.loadState.error {
                Text("Couldn't load published times: \(error.localizedDescription)")
                    .foregroundStyle(.red)
            }
        } footer: {
            Text("Times are in \(viewModel.timeZone.identifier).")
        }
    }

    private var timesSection: some View {
        Section("Times") {
            PrayerTimeRow(title: Prayer.fajr.displayName, prayer: $viewModel.editingDay.fajr, timeZone: viewModel.timeZone)
            TimeField(title: "Sunrise", time: $viewModel.editingDay.sunrise, timeZone: viewModel.timeZone)
            PrayerTimeRow(title: Prayer.dhuhr.displayName, prayer: $viewModel.editingDay.dhuhr, timeZone: viewModel.timeZone)
            PrayerTimeRow(title: Prayer.asr.displayName, prayer: $viewModel.editingDay.asr, timeZone: viewModel.timeZone)
            PrayerTimeRow(title: Prayer.maghrib.displayName, prayer: $viewModel.editingDay.maghrib, timeZone: viewModel.timeZone)
            PrayerTimeRow(title: Prayer.isha.displayName, prayer: $viewModel.editingDay.isha, timeZone: viewModel.timeZone)
        }
    }

    private var copySection: some View {
        Section {
            Stepper("Next \(viewModel.copyDayCount) days", value: $viewModel.copyDayCount,
                    in: 1...ScheduleEditorViewModel.maximumCopyDays)
            Button("Copy This Day's Times") {
                viewModel.copyToFollowingDays()
            }
            Button("Revert This Day", role: .destructive) {
                viewModel.revertSelectedDay()
            }
            .disabled(viewModel.selectedDayStatus != .edited)
        } header: {
            Text("Copy")
        } footer: {
            Text("Copies adhan and iqamah times to the following days. Edit any day afterwards.")
        }
    }

    private var publishSection: some View {
        Section {
            Button {
                Task { await viewModel.publish() }
            } label: {
                HStack {
                    Text(publishTitle)
                    Spacer()
                    if viewModel.publishState.isLoading {
                        ProgressView()
                    }
                }
            }
            .disabled(!viewModel.canPublish)

            switch viewModel.publishState {
            case .loaded(let count):
                Label("Published \(count) \(count == 1 ? "day" : "days").", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            case .failed(let error):
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
            case .idle, .loading:
                EmptyView()
            }
        } footer: {
            if viewModel.daysWithIssues > 0 {
                Text("Fix the problems on \(viewModel.daysWithIssues) edited \(viewModel.daysWithIssues == 1 ? "day" : "days") before publishing.")
            }
        }
    }

    // MARK: - Helpers

    private var publishTitle: String {
        switch viewModel.editedDayCount {
        case 0: "Nothing to Publish"
        case 1: "Publish 1 Day"
        default: "Publish \(viewModel.editedDayCount) Days"
        }
    }

    private var statusText: String {
        switch viewModel.selectedDayStatus {
        case .published: "Published"
        case .calculated: "Calculated. Not yet published."
        case .edited: "Edited. Not yet published."
        }
    }

    private var statusSymbol: String {
        switch viewModel.selectedDayStatus {
        case .published: "checkmark.circle"
        case .calculated: "function"
        case .edited: "pencil.circle"
        }
    }

    /// The day picker works in UTC on midday instants, so it shows the same calendar day everywhere.
    private var daySelection: Binding<Date> {
        let day = $viewModel.selectedDay
        return Binding(
            get: { day.wrappedValue.startOfDayUTC.addingTimeInterval(12 * 3_600) },
            set: { day.wrappedValue = CalendarDay(date: $0, in: .gmt) }
        )
    }

    private var dayRange: ClosedRange<Date> {
        viewModel.firstDay.startOfDayUTC...viewModel.lastDay.startOfDayUTC.addingTimeInterval(23 * 3_600)
    }
}
