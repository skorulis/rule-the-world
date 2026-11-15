import ASKCore
import Knit
import KnitMacros
import Observation

@Observable
final class ContentViewModel {
    var title: String

    @Resolvable<Resolver>
    init() {
        title = "RuleTheWorld"
    }

    func refreshTitle() {
        title = "RuleTheWorld (updated)"
    }
}
