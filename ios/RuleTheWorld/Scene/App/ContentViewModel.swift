import ASKCore
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class ContentViewModel {
    let hexMap: HexMapViewModel
    let visitLog: HexVisitLogListViewModel
    let profile: ProfileViewModel

    @Resolvable<Resolver>
    init(hexMap: HexMapViewModel, visitLog: HexVisitLogListViewModel, profile: ProfileViewModel) {
        self.hexMap = hexMap
        self.visitLog = visitLog
        self.profile = profile
    }
}
