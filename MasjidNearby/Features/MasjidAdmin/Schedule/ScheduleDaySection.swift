import SwiftUI

/// Picks the day being edited and shows whether it's published.
struct ScheduleDaySection: View {
    @Bindable var viewModel: ScheduleEditorViewModel

    var body: some View {
        Section {
            HStack {
                Button("Previous day", systemImage: "chevron.left") {
                    viewModel.goToPreviousDay()
                }
                .labelStyle(.iconOnly)
                .disabled(!viewModel.canGoBack)

                Spacer()
                DatePicker("Day", selection: $viewModel.selectedDate, in: viewModel.selectableDates,
                           displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.timeZone, .gmt)
                Spacer()

                Button("Next day", systemImage: "chevron.right") {
                    viewModel.goToNextDay()
                }
                .labelStyle(.iconOnly)
                .disabled(!viewModel.canGoForward)
            }
            .buttonStyle(.borderless)

            Label(viewModel.statusText, systemImage: viewModel.statusSymbol)
                .foregroundStyle(.secondary)
            if let error = viewModel.loadState.error {
                Text("Couldn't load published times: \(error.localizedDescription)")
                    .foregroundStyle(.red)
            }
        } footer: {
            Text("Times are in \(viewModel.timeZone.identifier).")
        }
    }
}
