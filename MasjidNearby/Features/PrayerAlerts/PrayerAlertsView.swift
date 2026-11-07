import SwiftUI

struct PrayerAlertsView: View {
    @State private var viewModel: PrayerAlertsViewModel

    init(viewModel: PrayerAlertsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Prayer Alerts", isOn: $viewModel.settings.isEnabled)
                    .disabled(viewModel.isDenied)
            } footer: {
                Text(viewModel.statusText)
            }

            if viewModel.settings.isEnabled {
                Section {
                    ForEach(Prayer.allCases, id: \.self) { prayer in
                        Toggle(prayer.displayName, isOn: $viewModel.settings[dynamicMember: \.[alertsFor: prayer]])
                    }
                    Toggle("Also Alert at Iqamah", isOn: $viewModel.settings.alertsAtIqamah)
                } header: {
                    Text("Prayers")
                } footer: {
                    Text("Iqamah alerts are only for masjids that publish iqamah times.")
                }

                Section {
                    if viewModel.favorites.isEmpty {
                        Text("Save a masjid to Favorites to get its alerts.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.favorites) { masjid in
                        Toggle(masjid.name, isOn: $viewModel.settings[dynamicMember: \.[alertsForMasjid: masjid.id]])
                    }
                } header: {
                    Text("Masjids")
                } footer: {
                    Text("Alerts use the times saved on this phone, so they work offline. Open the app at least once a week to keep them coming.")
                }
            }

            if let message = viewModel.message {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Prayer Alerts")
        .task {
            await viewModel.load()
        }
    }
}
