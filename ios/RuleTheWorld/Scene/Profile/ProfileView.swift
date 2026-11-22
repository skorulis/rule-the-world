import SwiftUI

struct ProfileView: View {
    @State var model: ProfileViewModel
    @State private var showSignOutConfirmation = false

    var body: some View {
        List {
            if model.visitedHexCount != nil || model.ownedHexCount != nil {
                Section {
                    if let visited = model.visitedHexCount {
                        LabeledContent("Hexes visited", value: visited.formatted())
                    }
                    if let owned = model.ownedHexCount {
                        LabeledContent("Hexes owned", value: owned.formatted())
                    }
                }
            }
            if !model.regions.isEmpty {
                Section("Regions") {
                    ForEach(model.regions) { region in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(region.name).font(.headline)
                            LabeledContent("Hexes visited", value: region.visited.formatted())
                            LabeledContent("Hexes owned", value: region.owned.formatted())
                        }
                    }
                }
            }
            Section {
                Button("Log out", role: .destructive) {
                    showSignOutConfirmation = true
                }
            }
        }
        .navigationTitle("Profile")
        .task { await model.load() }
        .alert("Log out?", isPresented: $showSignOutConfirmation) {
            Button("Log out", role: .destructive) {
                model.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to log out?")
        }
    }
}
