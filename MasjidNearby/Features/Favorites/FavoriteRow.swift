import SwiftUI

struct FavoriteRow: View {
    let item: FavoritesViewModel.Item
    let upcoming: UpcomingPrayer?
    let formatted: @MainActor (Date) -> String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading) {
                Text(item.masjid.name)
                    .font(.headline)
                if let synced = item.lastSyncedAt {
                    Text("Saved \(synced, format: .relative(presentation: .named))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not saved for offline yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let upcoming {
                VStack(alignment: .trailing) {
                    Text(upcoming.prayer.displayName)
                        .font(.subheadline.bold())
                    Text(formatted(upcoming.adhan))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else if item.today != nil {
                Text("Isha has passed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
