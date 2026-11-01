import SwiftUI

struct MasjidFormView: View {
    @State private var viewModel: MasjidFormViewModel

    init(viewModel: MasjidFormViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            Section("Masjid") {
                TextField("Name", text: $viewModel.draft.name)
                    .textContentType(.organizationName)
                TextField("Street address, city", text: $viewModel.draft.address, axis: .vertical)
                    .textContentType(.fullStreetAddress)
                Button {
                    Task { await viewModel.findAddress() }
                } label: {
                    HStack {
                        Text("Find Address on Map")
                        Spacer()
                        if viewModel.searchState.isLoading {
                            ProgressView()
                        }
                    }
                }
                .disabled(!viewModel.canSearchAddress)
            }

            Section {
                LocationPickerMap(
                    selected: viewModel.draft.coordinates,
                    searchResult: searchResultCoordinates,
                    onUseLocation: { viewModel.useLocation($0) }
                )
            } header: {
                Text("Location")
            } footer: {
                if let message = viewModel.searchMessage {
                    Text(message)
                } else if let coordinates = viewModel.draft.coordinates {
                    Text("Pin set at \(coordinates.latitude, specifier: "%.5f"), \(coordinates.longitude, specifier: "%.5f").")
                } else {
                    Text("Find the address, then drag the map so the pin is on the masjid.")
                }
            }

            Section {
                Picker("Time zone", selection: $viewModel.draft.timeZoneIdentifier) {
                    ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { identifier in
                        Text(identifier).tag(identifier)
                    }
                }
                .pickerStyle(.navigationLink)
                Picker("Calculation method", selection: $viewModel.draft.method) {
                    ForEach(CalculationMethod.allCases, id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                Picker("Asr", selection: $viewModel.draft.asrMadhab) {
                    ForEach(AsrMadhab.allCases, id: \.self) { madhab in
                        Text(madhab.displayName).tag(madhab)
                    }
                }
                Picker("High latitudes", selection: $viewModel.draft.highLatitudeRule) {
                    ForEach(HighLatitudeRule.allCases, id: \.self) { rule in
                        Text(rule.displayName).tag(rule)
                    }
                }
            } header: {
                Text("Prayer Time Settings")
            } footer: {
                Text("Used to calculate times on days you haven't published. All times are in this time zone.")
            }

            Section {
                ForEach($viewModel.draft.jumuah) { $slot in
                    VStack(alignment: .leading, spacing: 8) {
                        TimeField(title: "Khutbah", time: $slot.khutbah, timeZone: formTimeZone)
                        Toggle("Iqamah", isOn: $slot.hasIqamah)
                        if slot.hasIqamah {
                            TimeField(title: "Iqamah", time: $slot.iqamah, timeZone: formTimeZone)
                        }
                    }
                }
                .onDelete { offsets in
                    viewModel.removeJumuahSlots(at: offsets)
                }
                Button("Add Jumu'ah") {
                    viewModel.addJumuahSlot()
                }
            } header: {
                Text("Jumu'ah")
            } footer: {
                Text("Swipe left on a Jumu'ah to remove it.")
            }

            Section {
                ForEach(viewModel.draft.problems, id: \.self) { problem in
                    Label(problem.description, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                }
                if let error = viewModel.saveState.error {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                }
                Button {
                    Task { await viewModel.save() }
                } label: {
                    HStack {
                        Text(viewModel.saveButtonTitle)
                        Spacer()
                        if viewModel.saveState.isLoading {
                            ProgressView()
                        }
                    }
                }
                .disabled(!viewModel.canSave)
            }
        }
        .navigationTitle(viewModel.title)
    }

    private var searchResultCoordinates: Coordinates? {
        if case .loaded(let coordinates) = viewModel.searchState { coordinates } else { nil }
    }

    private var formTimeZone: TimeZone {
        TimeZone(identifier: viewModel.draft.timeZoneIdentifier) ?? .current
    }
}
