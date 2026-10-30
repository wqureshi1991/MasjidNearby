import PhotosUI
import SwiftUI

struct TimetableScanView: View {
    @State private var viewModel: TimetableScanViewModel
    @State private var photo: PhotosPickerItem?
    @State private var editing: EditingDay?

    init(viewModel: TimetableScanViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            photoSection
            if viewModel.hasResults {
                settingsSection
                daysSection
                publishSection
            }
        }
        .navigationTitle("Scan Timetable")
        .task {
            await viewModel.load()
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task { await scan(item) }
        }
        .sheet(item: $editing) { selection in
            if let index = viewModel.days.firstIndex(where: { $0.id == selection.id }) {
                ScannedDayEditor(
                    title: viewModel.dayTitle(selection.id),
                    day: $viewModel.days[index],
                    timeZone: viewModel.timeZone,
                    onDone: {
                        viewModel.markReviewed(selection.id)
                        editing = nil
                    }
                )
            }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section {
            PhotosPicker(selection: $photo, matching: .images) {
                Label(viewModel.hasResults ? "Choose a Different Photo" : "Choose Timetable Photo",
                      systemImage: "photo.on.rectangle")
            }
            .disabled(viewModel.scanState.isLoading)

            if viewModel.scanState.isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Reading the timetable…")
                        .foregroundStyle(.secondary)
                }
            }
            if let error = viewModel.scanState.error {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        } footer: {
            Text("Photograph the printed monthly timetable flat and well lit, then choose the photo here. Nothing is published until you've checked it.")
        }
    }

    private var settingsSection: some View {
        Section {
            Picker("Month", selection: $viewModel.month) {
                ForEach(viewModel.months, id: \.self) { month in
                    Text(viewModel.monthTitle(month)).tag(month)
                }
            }
            Picker("Columns", selection: $viewModel.layout) {
                ForEach(TimetableLayout.allCases) { layout in
                    Text(layout.displayName).tag(layout)
                }
            }
        } footer: {
            Text("Found \(viewModel.days.count) of \(viewModel.dayCountInMonth) days. Changing the month or columns reads the photo again and discards your edits.")
        }
    }

    private var daysSection: some View {
        Section {
            ForEach(viewModel.days) { day in
                Button {
                    editing = EditingDay(id: day.id)
                } label: {
                    ScannedDayRow(title: viewModel.dayTitle(day.day), day: day)
                }
                .foregroundStyle(.primary)
            }
        } header: {
            Text("Days")
        } footer: {
            if viewModel.reviewCount > 0 {
                Text("Tap the \(viewModel.reviewCount) marked \(viewModel.reviewCount == 1 ? "day" : "days") to check them against the timetable.")
            } else {
                Text("Tap any day to correct it.")
            }
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
                Button("Done") {
                    viewModel.finish()
                }
            case .failed(let error):
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
            case .idle, .loading:
                EmptyView()
            }
        } footer: {
            if viewModel.daysWithIssues > 0 {
                Text("Fix the problems on \(viewModel.daysWithIssues) \(viewModel.daysWithIssues == 1 ? "day" : "days"), or switch them off, before publishing.")
            }
        }
    }

    // MARK: - Helpers

    private var publishTitle: String {
        switch viewModel.includedCount {
        case 0: "Nothing to Publish"
        case 1: "Publish 1 Day"
        default: "Publish \(viewModel.includedCount) Days"
        }
    }

    private func scan(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                await viewModel.scan(imageData: data)
            } else {
                viewModel.photoUnavailable()
            }
        } catch {
            viewModel.photoUnavailable()
        }
        photo = nil
    }
}

/// Identifies the day being edited in the sheet.
private struct EditingDay: Identifiable {
    let id: CalendarDay
}

private struct ScannedDayRow: View {
    let title: String
    let day: TimetableScanViewModel.ScannedDay

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(Prayer.allCases.map { day.times[$0].adhan.description }.joined(separator: "  "))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !day.isIncluded {
                Text("Skipped")
                    .foregroundStyle(.secondary)
            } else if !day.issues.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Has problems")
            } else if !day.flagged.isEmpty {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Needs checking")
            }
        }
        .opacity(day.isIncluded ? 1 : 0.5)
        .contentShape(Rectangle())
    }
}

private struct ScannedDayEditor: View {
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
