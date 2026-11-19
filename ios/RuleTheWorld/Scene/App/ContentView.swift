import SwiftUI

struct ContentView: View {
    @State var model: ContentViewModel

    var body: some View {
        TabView {
            Tab("Map", systemImage: "map") {
                HexMapView(model: model.hexMap)
            }
            Tab("Visits", systemImage: "list.bullet") {
                HexVisitLogListView(model: model.visitLog)
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                ProfileView(model: model.profile)
            }
        }
    }
}
