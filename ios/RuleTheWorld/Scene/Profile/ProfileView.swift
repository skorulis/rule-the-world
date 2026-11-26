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
                HStack(spacing: 12) {
                    Button {
                        coordinator?.push(MainPath.shop)
                    } label: {
                        SquareCell(title: "Shop", icon: "Shop", value: model.coins ?? 0)
                    }
                    Button {
                        coordinator?.push(MainPath.titles)
                    } label: {
                        SquareCell(title: "Titles", icon: "HexOwned", value: model.titleCount ?? 0)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            Section("Debug") {
                Button {
                    coordinator?.push(MainPath.visitLog)
                } label: {
                    Label("Visit Log", systemImage: "list.bullet")
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
