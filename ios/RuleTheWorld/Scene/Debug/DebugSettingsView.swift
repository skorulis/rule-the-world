import SwiftUI

struct DebugSettingsView: View {
    @State private var endpoint: NetworkEndpoint
    @State private var showRestartAlert = false

    private let settings: DebugSettings

    init(settings: DebugSettings = DebugSettings()) {
        self.settings = settings
        _endpoint = State(initialValue: settings.endpoint)
    }

    var body: some View {
        Form {
            Picker("Network endpoint", selection: $endpoint) {
                ForEach(NetworkEndpoint.allCases) { endpoint in
                    Text(endpoint.title).tag(endpoint)
                }
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
