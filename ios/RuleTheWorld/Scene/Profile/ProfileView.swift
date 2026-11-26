import ASKCoordinator
import SwiftUI

struct ProfileView: View {
    @Environment(\.coordinator) private var coordinator
    @State var model: ProfileViewModel
    @State private var showSignOutConfirmation = false

    var body: some View {
        StandardListLayout("Profile") {
            Section {
                identityCard
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
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
                Button("Log out", role: .destructive) {
                    showSignOutConfirmation = true
                }
                .buttonStyle(GoldButtonStyle(fillsWidth: true))
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            Section {
                TitledParchmentPanel("Debug") {
                    RewardActionRow(systemName: "list.bullet", text: "Visit Log", isEnabled: true) {
                        coordinator?.push(MainPath.visitLog)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .task { await model.load() }
        .onAppear { model.refreshBanner() }
        .alert("Log out?", isPresented: $showSignOutConfirmation) {
            Button("Log out", role: .destructive) {
                model.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to log out?")
        }
    }

    private var identityCard: some View {
        let ink = Color(red: 0.25, green: 0.12, blue: 0.04)
        return ParchmentPanel(
            style: .thin(borderColor: ink),
            contentInsets: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Button {
                        if let userID = model.userID {
                            coordinator?.push(MainPath.bannerEditor(userID))
                        }
                    } label: {
                        BannerView(configuration: model.banner)
                            .padding(6)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        Color(red: 0.65, green: 0.44, blue: 0.23).gradient
                                            .shadow(.inner(color: ink.opacity(0.4), radius: 4, y: 2))
                                    )
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(BannerColor.ivory.color.opacity(0.5), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.canEditBanner)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Edit banner")
                    .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.subheadline)
                            .foregroundStyle(ink.opacity(0.75))
                        Text(model.userName ?? "—")
                            .font(.system(.title3, design: .serif, weight: .heavy))
                            .foregroundStyle(ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !model.canEditBanner {
                    Text("Connect to load your profile before editing your banner.")
                        .font(.footnote)
                        .foregroundStyle(ink)
                    Button("Retry") { Task { await model.load() } }
                        .buttonStyle(GoldButtonStyle())
                }
            }
        }
    }
}
