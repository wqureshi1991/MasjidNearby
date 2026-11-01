import SwiftUI

struct MasjidRow: View {
    let item: NearbyMasjidsViewModel.Item

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.masjid.name)
                    .font(.headline)
                Text(item.masjid.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Measurement(value: item.distanceMeters, unit: UnitLength.meters),
                 format: .measurement(width: .abbreviated, usage: .road))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}
