import SwiftUI

struct DebugSettingsView: View {
    @State var model: DebugSettingsViewModel

    var body: some View {
        Form {
            Picker("Network endpoint", selection: $model.endpoint) {
                ForEach(NetworkEndpoint.allCases) { endpoint in
                    Text(endpoint.title).tag(endpoint)
                }
            }
            Section {
                Button(model.isAddingVisits ? "Adding visits…" : "Add 5 Nearby Visits") {
                    Task { await model.addNearbyVisits() }
                }
                .disabled(!model.canAddVisits)
                if let visitMessage = model.visitMessage {
                    Text(visitMessage)
                }
            } header: {
                Text("Simulated Visits")
            } footer: {
                Text(!model.hasLocation
                     ? "Waiting for a location. Set a simulated location if using the Simulator."
                     : "Adds visits in five random hexagons within 500 metres over the last five minutes. Daily scoring limits still apply.")
            }
            Section("Power-ups") {
                Button(model.isAddingPowerUp ? "Adding power-up…" : "Add Random Power-up") {
                    Task { await model.addPowerUp() }
                }
                .disabled(model.isAddingPowerUp)
                if let powerUpMessage = model.powerUpMessage {
                    Text(powerUpMessage)
                }
            }
        }
        .navigationTitle("Debug Settings")
        .alert("Restart Required", isPresented: $model.showRestartAlert) {
            Button("Quit App", role: .destructive) {
                exit(0)
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("The endpoint change will take effect next time the app launches.")
        }
    }
}
