import SwiftUI

struct ScheduleEditorView: View {
    @State private var viewModel: ScheduleEditorViewModel

    init(viewModel: ScheduleEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            ScheduleDaySection(viewModel: viewModel)
            ScheduleTimesSection(viewModel: viewModel)
            ScheduleIssuesSection(issues: viewModel.issues)
            ScheduleCopySection(viewModel: viewModel)
            PublishDaysSection(
                title: viewModel.publishTitle,
                state: viewModel.publishState,
                canPublish: viewModel.canPublish,
                footer: viewModel.publishFooter,
                onPublish: { await viewModel.publish() }
            )
        }
        .navigationTitle("Prayer Times")
        .task {
            await viewModel.load()
        }
    }
}
