import SwiftUI

/// The masjid's Jumu'ah khutbah and iqamah times.
struct JumuahSection: View {
    let viewModel: MasjidDetailViewModel

    var body: some View {
        Section("Jumu'ah") {
            ForEach(viewModel.masjid.jumuah.enumerated(), id: \.offset) { _, slot in
                HStack {
                    Text("Khutbah \(viewModel.formatted(slot.khutbah))")
                    Spacer()
                    if let iqamah = slot.iqamah {
                        Text("Iqamah \(viewModel.formatted(iqamah))")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
