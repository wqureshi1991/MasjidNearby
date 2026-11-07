import PhotosUI
import SwiftUI

/// Chooses the timetable photo and shows recognition progress or errors.
struct TimetableScanPhotoSection: View {
    let viewModel: TimetableScanViewModel
    @Binding var photo: PhotosPickerItem?

    var body: some View {
        // PhotosPicker's label closure is @Sendable, so it gets a plain value, not the view model.
        let pickerTitle = viewModel.photoPickerTitle
        Section {
            PhotosPicker(selection: $photo, matching: .images) {
                Label(pickerTitle, systemImage: "photo.on.rectangle")
            }
            .disabled(viewModel.scanState.isLoading)

            if viewModel.scanState.isLoading {
                HStack {
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
}
