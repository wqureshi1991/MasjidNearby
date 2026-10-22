import MapKit
import SwiftUI

struct NearbyMapView: View {
    let items: [NearbyMasjidsViewModel.Item]
    let onSelect: @MainActor (NearbyMasjidsViewModel.Item) -> Void

    @State private var selectedID: String? = nil

    var body: some View {
        Map(initialPosition: .automatic, selection: $selectedID) {
            UserAnnotation()
            ForEach(items) { item in
                Marker(item.masjid.name,
                       systemImage: "building.columns",
                       coordinate: CLLocationCoordinate2D(latitude: item.masjid.coordinates.latitude,
                                                          longitude: item.masjid.coordinates.longitude))
                    .tag(item.id)
            }
        }
        .onChange(of: selectedID) { _, newID in
            guard let newID, let item = items.first(where: { $0.id == newID }) else { return }
            selectedID = nil
            onSelect(item)
        }
    }
}
