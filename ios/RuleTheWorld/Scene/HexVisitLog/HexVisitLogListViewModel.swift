import ASKCore
import Foundation
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class HexVisitLogListViewModel {
    private(set) var entries: [HexVisitLog] = []
    private(set) var errorMessage: String?
    private let store: HexVisitLogStore

    @Resolvable<Resolver>
    init(store: HexVisitLogStore) {
        self.store = store
    }

    func load() async {
        do {
            entries = try await store.all().reversed()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
