import ASKCoordinator
import SwiftUI

struct ProfileView: View {
    @Environment(\.coordinator) private var coordinator
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
                    if let coins = model.coins {
                        LabeledContent("Coins", value: coins.formatted())
                    }
                }
            }
            Section("Daily reward") {
                DailyRewardButton(model: model.dailyReward) { response in
                    model.applyInventory(response.powerups)
                }
                StipendButton(model: model.stipend) { response in
                    model.applyCoins(response.coins)
                }
            }
            Section {
                Button {
                    coordinator?.push(MainPath.titles)
                } label: {
                    LabeledContent("Titles", value: (model.titleCount ?? 0).formatted())
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
