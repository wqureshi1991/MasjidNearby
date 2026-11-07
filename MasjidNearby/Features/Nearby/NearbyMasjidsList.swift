import SwiftUI

/// Nearby masjids, nearest first.
struct NearbyMasjidsList: View {
    let viewModel: NearbyMasjidsViewModel
    let items: [NearbyMasjidsViewModel.Item]

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    Button {
                        viewModel.select(item)
                    } label: {
                        MasjidRow(item: item)
                    }
                    .foregroundStyle(.primary)
                }
            } header: {
                if let origin = viewModel.originDescription {
                    Text(origin)
                }
            }
        }
        .refreshable {
            await viewModel.loadNearCurrentLocation()
        }
    }
}
