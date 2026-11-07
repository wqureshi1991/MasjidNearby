import SwiftUI

/// The month the timetable is for and its column layout.
struct TimetableScanSettingsSection: View {
    @Bindable var viewModel: TimetableScanViewModel

    var body: some View {
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
            Text(viewModel.settingsFooter)
        }
    }
}
