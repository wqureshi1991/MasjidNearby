import Foundation
import Observation

/// Registers a new masjid or edits an existing one's details.
@MainActor
@Observable
final class MasjidFormViewModel {
    enum Mode {
        case create(adminUID: String)
        case edit(Masjid)
    }

    var draft: MasjidDraft
    /// The latest address-search result. The map recentres on it.
    private(set) var searchState: LoadState<Coordinates> = .idle
    private(set) var saveState: LoadState<Masjid> = .idle

    let mode: Mode
    private let repository: any MasjidRepository
    private let addressSearch: any AddressSearchService
    private let onSaved: @MainActor (Masjid) -> Void

    init(mode: Mode,
         repository: any MasjidRepository,
         addressSearch: any AddressSearchService,
         onSaved: @escaping @MainActor (Masjid) -> Void) {
        self.mode = mode
        self.repository = repository
        self.addressSearch = addressSearch
        self.onSaved = onSaved
        switch mode {
        case .create:
            draft = MasjidDraft()
        case .edit(let masjid):
            draft = MasjidDraft(masjid: masjid)
        }
    }

    var title: String {
        switch mode {
        case .create: "Register Masjid"
        case .edit: "Masjid Details"
        }
    }

    var saveButtonTitle: String {
        switch mode {
        case .create: "Register"
        case .edit: "Save"
        }
    }

    var canSave: Bool {
        draft.problems.isEmpty && !saveState.isLoading
    }

    var canSearchAddress: Bool {
        !draft.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !searchState.isLoading
    }

    /// Message to show after a search that found nothing.
    private(set) var searchMessage: String? = nil

    func findAddress() async {
        guard canSearchAddress else { return }
        searchState = .loading
        searchMessage = nil
        do {
            if let coordinates = try await addressSearch.coordinates(for: draft.address) {
                searchState = .loaded(coordinates)
                draft.coordinates = coordinates
            } else {
                searchState = .idle
                searchMessage = "No match for that address. Move the map to the masjid and tap Use Pin Location."
            }
        } catch {
            searchState = .failed(error)
            searchMessage = error.localizedDescription
        }
    }

    func useLocation(_ coordinates: Coordinates) {
        draft.coordinates = coordinates
    }

    func addJumuahSlot() {
        let khutbah = draft.jumuah.last.map { $0.khutbah.adding(minutes: 60) }
            ?? WallClockTime(wrappingMinutesSinceMidnight: 13 * 60 + 15)
        draft.jumuah.append(JumuahSlotDraft(khutbah: khutbah, iqamah: khutbah.adding(minutes: 15)))
    }

    func removeJumuahSlots(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where draft.jumuah.indices.contains(index) {
            draft.jumuah.remove(at: index)
        }
    }

    func save() async {
        guard canSave else { return }
        saveState = .loading
        do {
            let masjid: Masjid
            switch mode {
            case .create(let adminUID):
                masjid = try await repository.createMasjid(from: draft, adminUID: adminUID)
            case .edit(let existing):
                masjid = try await repository.updateMasjid(existing, with: draft)
            }
            saveState = .loaded(masjid)
            onSaved(masjid)
        } catch {
            saveState = .failed(error)
        }
    }
}
