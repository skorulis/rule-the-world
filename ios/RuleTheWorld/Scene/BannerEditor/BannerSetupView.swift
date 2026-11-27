import ASKCore
import Knit
import SwiftUI

/// Shown right after sign-up: requires the user to create a banner before entering the game.
/// The draft is saved under `BannerStore.setupUserID` and migrated to the real user ID
/// once the profile is loaded.
struct BannerSetupView: View {
    @Environment(\.resolver) private var resolver
    let onNext: () -> Void

    var body: some View {
        if let resolver {
            BannerEditorView(
                model: BannerEditorViewModel.make(resolver: resolver, userID: BannerStore.setupUserID),
                onNext: onNext
            )
        }
    }
}
