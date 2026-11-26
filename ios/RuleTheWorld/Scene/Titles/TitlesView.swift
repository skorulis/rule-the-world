import ASKCoordinator
import SwiftUI

struct TitlesView: View {
    @Environment(\.coordinator) private var coordinator
    @State var model: TitlesViewModel
    @State private var isHelpPresented = false

    var body: some View {
        StandardListLayout("Titles") {
            if let message = model.message, !model.items.isEmpty {
                Section {
                    Text(message).foregroundStyle(.secondary)
                    Button("Retry") { Task { await model.load() } }
                        .disabled(model.isLoading)
                }
            }
            ForEach(model.items) { item in
                Button {
                    coordinator?.push(MainPath.regionTitles(item))
                } label: {
                    TitleCell(item: item)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
            }
        }
        .overlay {
            if model.items.isEmpty {
                ParchmentPanel {
                    if model.isLoading || (!model.hasLoaded && model.message == nil) {
                        ProgressView("Loading titles…")
                            .frame(maxWidth: .infinity)
                    } else if let message = model.message {
                        ContentUnavailableView {
                            Label("Unable to load titles", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(message)
                        } actions: {
                            Button("Retry") { Task { await model.load() } }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ContentUnavailableView(
                            "No titles yet",
                            systemImage: "crown",
                            description: Text("Titles you are awarded will appear here.")
                        )
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Color(red: 0.3, green: 0.15, blue: 0.08))
                .padding(20)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Help", systemImage: "questionmark.circle") {
                    isHelpPresented = true
                }
            }
        }
        .sheet(isPresented: $isHelpPresented) {
            NavigationStack {
                TitlesHelpView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isHelpPresented = false }
                        }
                    }
            }
        }
        .task { await model.load() }
        .refreshable { await model.load() }
    }
}
