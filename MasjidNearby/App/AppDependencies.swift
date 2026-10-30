import Foundation

/// Single composition root. Coordinators receive this and hand
/// protocol-typed services to ViewModels.
struct AppDependencies: Sendable {
    let authService: any AuthService
    let masjidRepository: any MasjidRepository
    let addressSearch: any AddressSearchService
    let locationService: any LocationService
    let prayerTimeCalculator: any PrayerTimeCalculator
    let offlineStore: any OfflineStore
    let textRecognizer: any TextRecognizer

    init(authService: any AuthService,
         masjidRepository: any MasjidRepository = MockMasjidRepository(),
         addressSearch: any AddressSearchService = MockAddressSearchService(),
         locationService: any LocationService = MockLocationService(),
         prayerTimeCalculator: any PrayerTimeCalculator = AstronomicalPrayerTimeCalculator(),
         offlineStore: any OfflineStore = InMemoryOfflineStore(),
         textRecognizer: any TextRecognizer = VisionTextRecognizer()) {
        self.authService = authService
        self.masjidRepository = masjidRepository
        self.addressSearch = addressSearch
        self.locationService = locationService
        self.prayerTimeCalculator = prayerTimeCalculator
        self.offlineStore = offlineStore
        self.textRecognizer = textRecognizer
    }

    @MainActor
    static func makeDefault(firebaseConfigured: Bool) -> AppDependencies {
        guard firebaseConfigured else {
            // No Firebase yet: in-memory sign-in and clearly-labelled sample masjids,
            // with real location and address search.
            return AppDependencies(
                authService: MockAuthService(),
                masjidRepository: DemoData.repository(),
                addressSearch: MapKitAddressSearchService(),
                locationService: CoreLocationService(),
                offlineStore: SwiftDataOfflineStore.makeDefault()
            )
        }
        return AppDependencies(
            authService: LiveAuthService(backend: FirebaseAuthBackend(), profiles: FirestoreUserProfileStore()),
            masjidRepository: FirestoreMasjidRepository(),
            addressSearch: MapKitAddressSearchService(),
            locationService: CoreLocationService(),
            offlineStore: SwiftDataOfflineStore.makeDefault()
        )
    }
}
