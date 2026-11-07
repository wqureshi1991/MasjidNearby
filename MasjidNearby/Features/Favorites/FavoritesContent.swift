import SwiftUI

/// Saved masjids with their next prayer, or a loading, error or empty state.
struct FavoritesContent: View {
    let viewModel: FavoritesViewModel
    let now: Date

    var body: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let error):
            ContentUnavailableView {
                Label("Couldn't Load Favorites", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.load() }
                }
            }
        case .loaded(let items) where items.isEmpty:
            ContentUnavailableView {
                Label("No Favorites Yet", systemImage: "star")
            } description: {
                Text("Tap the star on a masjid's page to save it here. Saved masjids' times work offline.")
            }
        case .loaded(let items):
            List {
                if let message = viewModel.refreshMessage {
                    Section {
                        Label(message, systemImage: "wifi.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
                Section {
                    ForEach(items) { item in
                        Button {
                            viewModel.select(item)
                        } label: {
                            FavoriteRow(item: item, upcoming: viewModel.upcoming(for: item, at: now),
                                        formatted: { viewModel.formatted($0, for: item) })
                        }
                        .foregroundStyle(.primary)
                        .swipeActions {
                            Button("Remove", role: .destructive) {
                                Task { await viewModel.remove(item) }
                            }
                        }
                    }
                } footer: {
                    Text("Times are saved on this device for the next 30 days.")
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }
}
