import Observation
import OSLog

enum AppFlow {
    case launching
    case onboarding(OnboardingCoordinator)
    case user(UserCoordinator)
    case masjidAdmin(MasjidAdminCoordinator)
}
