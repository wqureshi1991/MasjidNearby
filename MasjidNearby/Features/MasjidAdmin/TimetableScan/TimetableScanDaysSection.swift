import SwiftUI

/// The scanned days. Tapping one opens it for checking.
struct TimetableScanDaysSection: View {
    let viewModel: TimetableScanViewModel
    @Binding var editing: ScannedDaySelection?

    var body: some View {
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
            Text(viewModel.daysFooter)
        }
    }
}
