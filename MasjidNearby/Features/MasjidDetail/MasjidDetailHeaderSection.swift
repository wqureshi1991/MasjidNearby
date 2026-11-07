import SwiftUI

/// Name, address, distance and directions, plus offline or favorite notices.
struct MasjidDetailHeaderSection: View {
    let viewModel: MasjidDetailViewModel

    var body: some View {
        Section {
            VStack(alignment: .leading) {
                Text(viewModel.masjid.name)
                    .font(.title3.bold())
                Text(viewModel.masjid.address)
                    .foregroundStyle(.secondary)
                if let distance = viewModel.formattedDistance {
                    Text("\(distance) away")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let url = viewModel.directionsURL {
                Link(destination: url) {
                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                }
            }
            if let notice = viewModel.notice {
                Label(notice, systemImage: "wifi.exclamationmark")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            if let favoriteError = viewModel.favoriteError {
                Label(favoriteError, systemImage: "star.slash")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }
}
