import SwiftUI

/// Problems that stop a day's times from being published.
struct ScheduleIssuesSection: View {
    let issues: [ScheduleIssue]

    var body: some View {
        if !issues.isEmpty {
            Section {
                ForEach(issues, id: \.self) { issue in
                    Label(issue.description, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
