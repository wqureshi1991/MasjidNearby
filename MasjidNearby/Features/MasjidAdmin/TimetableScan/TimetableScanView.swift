import PhotosUI
import SwiftUI

struct TimetableScanView: View {
    @State private var viewModel: TimetableScanViewModel
    @State private var photo: PhotosPickerItem?
    @State private var editing: ScannedDaySelection?

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
        // PhotosPicker's label closure is @Sendable, so it gets a plain value, not the view model.
        let pickerTitle = viewModel.hasResults ? "Choose a Different Photo" : "Choose Timetable Photo"
        return Section {
            PhotosPicker(selection: $photo, matching: .images) {
                Label(pickerTitle, systemImage: "photo.on.rectangle")
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
                    editing = ScannedDaySelection(id: day.id)
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
