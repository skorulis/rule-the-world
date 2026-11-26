import ASKCoordinator
import SwiftUI

struct ProfileView: View {
    @Environment(\.coordinator) private var coordinator
    @State var model: ProfileViewModel
    @State private var showSignOutConfirmation = false

    var body: some View {
        StandardListLayout("Profile") {
            if let userName = model.userName {
                Section {
                    LabeledContent("Name", value: userName)
                }
            }
            if model.visitedHexCount != nil || model.ownedHexCount != nil {
                Section {
                    ProfileStatsCard(visited: model.visitedHexCount, owned: model.ownedHexCount)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            Section {
                TitledParchmentPanel("Daily rewards") {
                    VStack(spacing: 16) {
                        DailyRewardButton(model: model.dailyReward) { response in
                            model.applyInventory(response.powerups)
                        }
                        StipendButton(model: model.stipend) { response in
                            model.applyCoins(response.coins)
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            Section {
                HStack(spacing: 12) {
                    Button {
                        coordinator?.push(MainPath.shop)
                    } label: {
                        SquareCell(title: "Shop", icon: "Shop", value: model.coins ?? 0)
                            .frame(maxWidth: .infinity)
                    }
                    Button {
                        coordinator?.push(MainPath.titles)
                    } label: {
                        SquareCell(title: "Titles", icon: "HexOwned", value: model.titleCount ?? 0)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            Section {
                Button {
                    coordinator?.push(MainPath.visitLog)
                } label: {
                    Label("Visit Log", systemImage: "list.bullet")
                }
            } header: {
                Text("Debug")
                    .foregroundStyle(Color(red: 1, green: 0.9, blue: 0.7))
            }
            Section {
                Button("Log out", role: .destructive) {
                    showSignOutConfirmation = true
                }
            }
        }
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
