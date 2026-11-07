import SwiftUI

/// The search result: a prompt, progress, an error, or the masjids as a list or map.
struct NearbyMasjidsContent: View {
    let viewModel: NearbyMasjidsViewModel

    var body: some View {
        switch viewModel.state {
        case .idle:
            ContentUnavailableView {
                Label("Find Masjids", systemImage: "location.magnifyingglass")
            } description: {
                Text(viewModel.idleMessage)
            } actions: {
                if !viewModel.isLocationDenied {
                    Button("Use My Location") {
                        Task { await viewModel.loadNearCurrentLocation() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        case .loading:
            ProgressView("Finding masjids…")
        case .failed(let error):
            ContentUnavailableView {
                Label("Couldn't Load Masjids", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.loadNearCurrentLocation() }
                }
            }
        case .loaded(let items) where items.isEmpty:
            ContentUnavailableView {
                Label("No Masjids Nearby", systemImage: "building.columns")
            } description: {
                Text(viewModel.emptyMessage)
            }
        case .loaded(let items):
            switch viewModel.displayMode {
            case .list:
                NearbyMasjidsList(viewModel: viewModel, items: items)
            case .map:
                NearbyMapView(items: items) { viewModel.select($0) }
            }
        }
    }
}
