import SwiftUI

struct ProfileView: View {
    @State var model: ProfileViewModel
    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Hexes visited", value: model.visitedHexCount.formatted())
                }
                Section {
                    Button("Log out", role: .destructive) {
                        showSignOutConfirmation = true
                    }
                }
            }
            .navigationTitle("Profile")
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
}
