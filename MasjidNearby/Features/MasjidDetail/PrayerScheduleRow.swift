import SwiftUI

struct PrayerScheduleRow: View {
    let name: String
    let time: PrayerTime
    let viewModel: MasjidDetailViewModel
    let isNext: Bool

    var body: some View {
        HStack {
            Text(name)
                .bold(isNext)
            Spacer()
            Text(viewModel.formatted(time.adhan))
                .monospacedDigit()
                .frame(minWidth: 72, alignment: .trailing)
            Text(time.iqamah.map { viewModel.formatted($0) } ?? "—")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 72, alignment: .trailing)
        }
        .foregroundStyle(isNext ? Color.accentColor : Color.primary)
        .accessibilityElement(children: .combine)
    }
}
