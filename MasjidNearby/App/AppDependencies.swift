import Foundation

/// Single composition root. Coordinators receive this and hand
/// protocol-typed services to ViewModels.
struct AppDependencies: Sendable {
    let authService: any AuthService
    let masjidRepository: any MasjidRepository
    let addressSearch: any AddressSearchService
    let prayerTimeCalculator: any PrayerTimeCalculator

    init(authService: any AuthService,
         masjidRepository: any MasjidRepository = MockMasjidRepository(),
         addressSearch: any AddressSearchService = MockAddressSearchService(),
         prayerTimeCalculator: any PrayerTimeCalculator = AstronomicalPrayerTimeCalculator()) {
        self.authService = authService
        self.masjidRepository = masjidRepository
        self.addressSearch = addressSearch
        self.prayerTimeCalculator = prayerTimeCalculator
    }

    static func makeDefault(firebaseConfigured: Bool) -> AppDependencies {
        guard firebaseConfigured else {
            return AppDependencies(authService: MockAuthService(), addressSearch: MapKitAddressSearchService())
        }
        return AppDependencies(
            authService: LiveAuthService(backend: FirebaseAuthBackend(), profiles: FirestoreUserProfileStore()),
            masjidRepository: FirestoreMasjidRepository(),
            addressSearch: MapKitAddressSearchService()
        )
    }
}
