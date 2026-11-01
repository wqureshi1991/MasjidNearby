import PhotosUI
import SwiftUI

struct ScannedDayRow: View {
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
