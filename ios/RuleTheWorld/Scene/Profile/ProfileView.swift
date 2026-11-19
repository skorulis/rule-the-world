import SwiftUI

struct ProfileView: View {
    @State var model: ProfileViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Log out", role: .destructive) {
                        model.signOut()
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
