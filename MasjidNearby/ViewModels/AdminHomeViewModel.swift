import Foundation
import Observation

@MainActor
@Observable
final class AdminHomeViewModel {
    /// Loaded nil means this admin hasn't registered a masjid yet.
    private(set) var state: LoadState<Masjid?> = .idle

    @ObservationIgnored var onRegister: (@MainActor () -> Void)?
    @ObservationIgnored var onEditDetails: (@MainActor (Masjid) -> Void)?
    @ObservationIgnored var onEditSchedule: (@MainActor (Masjid) -> Void)?

    private let adminUID: String
    private let repository: any MasjidRepository

    init(adminUID: String, repository: any MasjidRepository) {
        self.adminUID = adminUID
        self.repository = repository
    }

    var masjid: Masjid? {
        if case .loaded(let masjid) = state { masjid } else { nil }
    }

    func load() async {
        guard !state.isLoading else { return }
        let previous = masjid
        state = .loading
        do {
            state = .loaded(try await repository.masjid(administeredBy: adminUID))
        } catch {
            // Keep showing what we had if a refresh fails.
            if let previous {
                state = .loaded(previous)
            } else {
                state = .failed(error)
            }
        }
    }

    /// Shows a masjid that was just created or edited, without a round trip.
    func show(_ masjid: Masjid) {
        state = .loaded(masjid)
    }

    func registerMasjid() {
        onRegister?()
    }

    func editDetails() {
        guard let masjid else { return }
        onEditDetails?(masjid)
    }

    func editSchedule() {
        guard let masjid else { return }
        onEditSchedule?(masjid)
    }
}
