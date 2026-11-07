import SwiftUI

/// Copies the selected day's times forward, or reverts the day.
struct ScheduleCopySection: View {
    @Bindable var viewModel: ScheduleEditorViewModel

    var body: some View {
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
}
