import SwiftUI

/// The next prayer, with a live countdown.
struct NextPrayerSection: View {
    let upcoming: UpcomingPrayer
    let viewModel: MasjidDetailViewModel

    var body: some View {
        Section("Next Prayer") {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading) {
                    Text(upcoming.isTomorrow ? "\(upcoming.prayer.displayName) (tomorrow)" : upcoming.prayer.displayName)
                        .font(.title2.bold())
                    Text(upcoming.adhan, style: .relative)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(viewModel.formatted(upcoming.adhan))
                        .font(.title2.monospacedDigit())
                    if let iqamah = upcoming.iqamah {
                        Text("Iqamah \(viewModel.formatted(iqamah))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
