import SwiftUI

struct DebugSettingsView: View {
    @State private var endpoint: NetworkEndpoint
    @State private var showRestartAlert = false

    @State private var isAddingVisits = false
    @State private var visitMessage: String?

    private let settings: DebugSettings
    private let locationService: LocationService?
    private let captureService: LocationCaptureService?

    init(
        settings: DebugSettings = DebugSettings(),
        locationService: LocationService?,
        captureService: LocationCaptureService?
    ) {
        self.settings = settings
        self.locationService = locationService
        self.captureService = captureService
        _endpoint = State(initialValue: settings.endpoint)
    }

    var body: some View {
        Form {
            Picker("Network endpoint", selection: $endpoint) {
                ForEach(NetworkEndpoint.allCases) { endpoint in
                    Text(endpoint.title).tag(endpoint)
                }
            }
            Section {
                Button(isAddingVisits ? "Adding visits…" : "Add 5 Nearby Visits") {
                    guard let sample = locationService?.latestSample, let captureService else { return }
                    isAddingVisits = true
                    visitMessage = nil
                    Task {
                        defer { isAddingVisits = false }
                        do {
                            try await captureService.addRandomNearbyVisits(near: sample.coordinate)
                            visitMessage = "Added 5 visits and updated hex scores."
                        } catch {
                            visitMessage = error.localizedDescription
                        }
                    }
                }
                .disabled(isAddingVisits || locationService?.latestSample == nil || captureService == nil)
                if let visitMessage {
                    Text(visitMessage)
                }
            } header: {
                Text("Simulated Visits")
            } footer: {
                Text(locationService?.latestSample == nil
                     ? "Waiting for a location. Set a simulated location if using the Simulator."
                     : "Adds visits in five random hexagons within 500 metres over the last five minutes. Daily scoring limits still apply.")
            }
        }
        .navigationTitle("Debug Settings")
        .onChange(of: endpoint) { _, newValue in
            settings.endpoint = newValue
            showRestartAlert = true
        }
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("Quit App", role: .destructive) {
                exit(0)
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("The endpoint change will take effect next time the app launches.")
        }
    }
}
