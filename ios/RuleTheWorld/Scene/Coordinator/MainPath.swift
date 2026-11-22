import ASKCoordinator

enum MainPath: CoordinatorPath {
    case hexMap
    case visitLog
    case profile

    var id: String {
        switch self {
        case .hexMap:
            "hexMap"
        case .visitLog:
            "visitLog"
        case .profile:
            "profile"
        }
    }
}
