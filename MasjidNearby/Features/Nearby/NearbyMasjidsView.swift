import SwiftUI

struct NearbyMasjidsView: View {
    @Bindable var viewModel: NearbyMasjidsViewModel

    var body: some View {
        VStack {
            Picker("View", selection: $viewModel.displayMode) {
                Text("List").tag(NearbyMasjidsViewModel.DisplayMode.list)
                Text("Map").tag(NearbyMasjidsViewModel.DisplayMode.map)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            NearbyMasjidsContent(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Masjids")
        .searchable(text: $viewModel.searchText, prompt: "Search a city or address")
        .onSubmit(of: .search) {
            Task { await viewModel.searchPlace() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Use my location", systemImage: "location") {
                    Task { await viewModel.loadNearCurrentLocation() }
                }
                .labelStyle(.iconOnly)
                .disabled(viewModel.state.isLoading)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }
}
