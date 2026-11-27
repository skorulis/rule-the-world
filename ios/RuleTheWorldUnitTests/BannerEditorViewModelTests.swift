import ASKCore
import Testing
@testable import RuleTheWorld

@MainActor
struct BannerEditorViewModelTests {
    @Test func editingAndAbandoningDraftDoesNotSave() {
        let store = BannerStore(keyValueStore: InMemoryKeyValueStore())
        let model = BannerEditorViewModel(store: store, userID: "alice")
        model.draft.pattern = .cross
        model.draft.emblem = .lion
        #expect(store.banner(for: "alice") == .default)
        let reopened = BannerEditorViewModel(store: store, userID: "alice")
        #expect(reopened.draft == .default)
    }

    @Test func savePersistsAndReopeningLoadsSavedBanner() {
        let store = BannerStore(keyValueStore: InMemoryKeyValueStore())
        let model = BannerEditorViewModel(store: store, userID: "alice")
        model.draft.backgroundColor = .forest
        #expect(model.save())
        #expect(model.errorMessage == nil)
        #expect(store.banner(for: "alice") == model.draft)
        let reopened = BannerEditorViewModel(store: store, userID: "alice")
        #expect(reopened.draft == model.draft)
        #expect(store.banner(for: "bob") == .default)
    }

    @Test func shufflePreservesTabAndDoesNotSave() {
        let store = BannerStore(keyValueStore: InMemoryKeyValueStore())
        let model = BannerEditorViewModel(store: store, userID: "alice")
        model.selectedTab = .emblem
        var generator = BannerTestRandom(seed: 73)
        model.shuffle(using: &generator)
        #expect(model.selectedTab == .emblem)
        #expect(model.draft != .default)
        #expect(store.banner(for: "alice") == .default)
    }

    @Test func failedSaveKeepsDraftAndReportsError() {
        let model = BannerEditorViewModel(
            store: BannerStore(keyValueStore: DiscardingBannerKeyValueStore()), userID: "alice"
        )
        model.draft.emblem = .wave
        let draft = model.draft
        #expect(!model.save())
        #expect(model.draft == draft)
        #expect(model.errorMessage != nil)
    }
}
