import ASKCore
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class ContentViewModel {
    let hexMap: HexMapViewModel
    let visitLog: HexVisitLogListViewModel

    @Resolvable<Resolver>
    init(hexMap: HexMapViewModel, visitLog: HexVisitLogListViewModel) {
        self.hexMap = hexMap
        self.visitLog = visitLog
    }
}
