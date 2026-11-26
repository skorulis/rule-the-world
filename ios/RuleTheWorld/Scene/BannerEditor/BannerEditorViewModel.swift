import Foundation
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class BannerEditorViewModel {
    enum Tab: String, CaseIterable {
        case pattern = "Pattern"
        case colors = "Colors"
        case emblem = "Emblem"
    }

    private let store: BannerStore
    private let userID: String
    var draft: BannerConfiguration
    var selectedTab: Tab = .pattern
    private(set) var errorMessage: String?

    @Resolvable<Resolver>
    init(store: BannerStore, @Argument userID: String) {
        self.store = store
        self.userID = userID
        self.draft = store.banner(for: userID)
    }

    func shuffle() {
        var generator = SystemRandomNumberGenerator()
        shuffle(using: &generator)
    }

    func shuffle(using generator: inout some RandomNumberGenerator) {
        draft.shuffle(using: &generator)
        errorMessage = nil
    }

    func save() -> Bool {
        do {
            try store.save(draft, for: userID)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Your banner could not be saved. Please try again."
            return false
        }
    }
}
