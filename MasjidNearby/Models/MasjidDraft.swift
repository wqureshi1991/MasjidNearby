import Foundation

/// An editable Jumu'ah slot. Identifiable so a form can list and remove slots.
struct JumuahSlotDraft: Sendable, Hashable, Identifiable {
    let id: UUID
    var khutbah: WallClockTime
    var hasIqamah: Bool
    var iqamah: WallClockTime

    init(id: UUID = UUID(), khutbah: WallClockTime, iqamah: WallClockTime?) {
        self.id = id
        self.khutbah = khutbah
        self.hasIqamah = iqamah != nil
        self.iqamah = iqamah ?? khutbah.adding(minutes: 15)
    }

    init(_ slot: JumuahSlot) {
        self.init(khutbah: slot.khutbah, iqamah: slot.iqamah)
    }

    var slot: JumuahSlot {
        JumuahSlot(khutbah: khutbah, iqamah: hasIqamah ? iqamah : nil)
    }
}

enum MasjidDraftProblem: Sendable, Hashable, CustomStringConvertible {
    case missingName
    case missingAddress
    case missingLocation
    case unknownTimeZone
    case jumuahIqamahBeforeKhutbah

    var description: String {
        switch self {
        case .missingName: "Enter the masjid's name."
        case .missingAddress: "Enter the masjid's address."
        case .missingLocation: "Set the masjid's location on the map."
        case .unknownTimeZone: "Choose a valid time zone."
        case .jumuahIqamahBeforeKhutbah: "Each Jumu'ah iqamah must be after its khutbah."
        }
    }
}

/// Form state for registering or editing a masjid.
struct MasjidDraft: Sendable, Equatable {
    var name = ""
    var address = ""
    var coordinates: Coordinates?
    var timeZoneIdentifier = TimeZone.current.identifier
    var method: CalculationMethod = .isna
    var asrMadhab: AsrMadhab = .standard
    var highLatitudeRule: HighLatitudeRule = .middleOfNight
    var jumuah: [JumuahSlotDraft] = []

    init() {}

    init(masjid: Masjid) {
        name = masjid.name
        address = masjid.address
        coordinates = masjid.coordinates
        timeZoneIdentifier = masjid.timeZoneIdentifier
        method = masjid.calculation.method
        asrMadhab = masjid.calculation.asrMadhab
        highLatitudeRule = masjid.calculation.highLatitudeRule
        jumuah = masjid.jumuah.map { JumuahSlotDraft($0) }
    }

    var problems: [MasjidDraftProblem] {
        var problems: [MasjidDraftProblem] = []
        if trimmedName.isEmpty { problems.append(.missingName) }
        if trimmedAddress.isEmpty { problems.append(.missingAddress) }
        if coordinates?.isValid != true { problems.append(.missingLocation) }
        if TimeZone(identifier: timeZoneIdentifier) == nil { problems.append(.unknownTimeZone) }
        let badJumuah = jumuah.contains { slot in
            slot.hasIqamah && (slot.iqamah <= slot.khutbah || slot.khutbah.minutes(until: slot.iqamah) > 120)
        }
        if badJumuah { problems.append(.jumuahIqamahBeforeKhutbah) }
        return problems
    }

    var calculation: CalculationParameters {
        CalculationParameters(method: method, asrMadhab: asrMadhab, highLatitudeRule: highLatitudeRule)
    }

    /// The masjid this draft describes, or nil while it has problems.
    func makeMasjid(id: String, isVerified: Bool) -> Masjid? {
        guard problems.isEmpty, let coordinates else { return nil }
        return Masjid(
            id: id,
            name: trimmedName,
            address: trimmedAddress,
            coordinates: coordinates,
            timeZoneIdentifier: timeZoneIdentifier,
            calculation: calculation,
            jumuah: jumuah.map(\.slot).sorted { $0.khutbah < $1.khutbah },
            isVerified: isVerified
        )
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
