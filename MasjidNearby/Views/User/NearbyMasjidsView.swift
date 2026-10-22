import SwiftUI

struct NearbyMasjidsView: View {
    @Bindable var viewModel: NearbyMasjidsViewModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $viewModel.displayMode) {
                Text("List").tag(NearbyMasjidsViewModel.DisplayMode.list)
                Text("Map").tag(NearbyMasjidsViewModel.DisplayMode.map)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Masjids")
        .searchable(text: $viewModel.searchText, prompt: "Search a city or address")
        .onSubmit(of: .search) {
            Task { await viewModel.searchPlace() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.loadNearCurrentLocation() }
                } label: {
                    Image(systemName: "location")
                }
                .accessibilityLabel("Use my location")
                .disabled(viewModel.state.isLoading)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            ContentUnavailableView {
                Label("Find Masjids", systemImage: "location.magnifyingglass")
            } description: {
                Text(viewModel.isLocationDenied
                     ? "Location access is off. Search for a city or address above, or allow location in Settings."
                     : "Use your location, or search for a city or address.")
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
                Text("No verified masjids within \(Int(NearbyMasjidsViewModel.searchRadiusMeters / 1_000)) km. Try searching another city.")
            }
        case .loaded(let items):
            switch viewModel.displayMode {
            case .list:
                list(of: items)
            case .map:
                NearbyMapView(items: items) { viewModel.select($0) }
            }
        }
    }

    private func list(of items: [NearbyMasjidsViewModel.Item]) -> some View {
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

private struct MasjidRow: View {
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
