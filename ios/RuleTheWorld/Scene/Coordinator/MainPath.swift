import ASKCoordinator

enum MainPath: CoordinatorPath {
    case content
    case hexMap

    var id: String {
        switch self {
        case .content:
            "content"
        case .hexMap:
            "hexMap"
        }
    }
}
