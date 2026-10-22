import MapKit
import SwiftUI

/// A map with a fixed centre pin. The admin pans the map under the pin, then confirms.
struct LocationPickerMap: View {
    /// The masjid's saved location, if any.
    let selected: Coordinates?
    /// Changes when an address search finds a match; the map recentres on it.
    let searchResult: Coordinates?
    let onUseLocation: @MainActor (Coordinates) -> Void

    @State private var position: MapCameraPosition
    @State private var pinCenter: Coordinates?

    init(selected: Coordinates?,
         searchResult: Coordinates?,
         onUseLocation: @escaping @MainActor (Coordinates) -> Void) {
        self.selected = selected
        self.searchResult = searchResult
        self.onUseLocation = onUseLocation
        _position = State(initialValue: Self.cameraPosition(for: selected))
        _pinCenter = State(initialValue: selected)
    }

    var body: some View {
        Group {
            Map(position: $position)
                .onMapCameraChange(frequency: .onEnd) { context in
                    pinCenter = Coordinates(latitude: context.region.center.latitude,
                                            longitude: context.region.center.longitude)
                }
                .overlay {
                    Image(systemName: "mappin")
                        .font(.title)
                        .foregroundStyle(.red)
                        .offset(y: -14)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .frame(height: 240)
                .listRowInsets(EdgeInsets())
                .onChange(of: searchResult) { _, newResult in
                    if let newResult {
                        position = Self.cameraPosition(for: newResult)
                    }
                }

            Button("Use Pin Location") {
                if let pinCenter {
                    onUseLocation(pinCenter)
                }
            }
            .disabled(pinCenter == nil || pinCenter == selected)
        }
    }

    private static func cameraPosition(for coordinates: Coordinates?) -> MapCameraPosition {
        guard let coordinates else {
            // Contiguous United States until a location is chosen.
            return .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
                span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)
            ))
        }
        return .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude),
            latitudinalMeters: 500,
            longitudinalMeters: 500
        ))
    }
}
