import SwiftUI

// swiftlint:disable line_length
struct TitlesHelpView: View {
    var body: some View {
        List {
            Section {
                Label {
                    Text("Titles are awarded for your activity in each region — the world, countries, states, and suburbs. Exploring and claiming hexes earns you higher ranks.")
                } icon: {
                    Image(systemName: "crown")
                }
                Label {
                    Text("Each title has requirements such as minimum hexes visited and owned. Tap a title to see every rank in its region, from highest to lowest.")
                } icon: {
                    Image(systemName: "list.bullet")
                }
            }
            Section("Limited titles") {
                Label {
                    Text("Some titles only allow a limited number of holders, either a fixed count or a percentage of a region's visitors. Meeting the requirements doesn't guarantee the title — you also have to outrank the competition.")
                } icon: {
                    Image(systemName: "person.3")
                }
            }
            Section("Stipends") {
                Label {
                    Text("Titles marked with a coin grant a daily stipend. The higher the title, the bigger the payout.")
                } icon: {
                    Image("Coin")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
            }
        }
        .navigationTitle("About titles")
        .navigationBarTitleDisplayMode(.inline)
    }
}
// swiftlint:enable line_length
