import Foundation

/// Single composition root. Coordinators receive this and hand
/// protocol-typed services to ViewModels.
struct AppDependencies: Sendable {
    let authService: any AuthService
    let masjidRepository: any MasjidRepository
    let addressSearch: any AddressSearchService
    let locationService: any LocationService
    let prayerTimeCalculator: any PrayerTimeCalculator

    init(authService: any AuthService,
         masjidRepository: any MasjidRepository = MockMasjidRepository(),
         addressSearch: any AddressSearchService = MockAddressSearchService(),
         locationService: any LocationService = MockLocationService(),
         prayerTimeCalculator: any PrayerTimeCalculator = AstronomicalPrayerTimeCalculator()) {
        self.authService = authService
        self.masjidRepository = masjidRepository
        self.addressSearch = addressSearch
        self.locationService = locationService
        self.prayerTimeCalculator = prayerTimeCalculator
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
                locationService: CoreLocationService()
            )
        }
        return AppDependencies(
            authService: LiveAuthService(backend: FirebaseAuthBackend(), profiles: FirestoreUserProfileStore()),
            masjidRepository: FirestoreMasjidRepository(),
            addressSearch: MapKitAddressSearchService(),
            locationService: CoreLocationService()
        )
    }
}
