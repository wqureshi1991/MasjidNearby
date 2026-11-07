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
            TimetableScanPhotoSection(viewModel: viewModel, photo: $photo)
            if viewModel.hasResults {
                TimetableScanSettingsSection(viewModel: viewModel)
                TimetableScanDaysSection(viewModel: viewModel, editing: $editing)
                PublishDaysSection(
                    title: viewModel.publishTitle,
                    state: viewModel.publishState,
                    canPublish: viewModel.canPublish,
                    footer: viewModel.publishFooter,
                    onPublish: { await viewModel.publish() },
                    onDone: { viewModel.finish() }
                )
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
