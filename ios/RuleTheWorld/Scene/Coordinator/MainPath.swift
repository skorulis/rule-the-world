import ASKCoordinator

enum MainPath: CoordinatorPath {
    case hexMap
    case visitLog
    case profile
    case powerUpInventory

    var id: String {
        switch self {
        case .hexMap:
            "hexMap"
        case .visitLog:
            "visitLog"
        case .profile:
            "profile"
        case .powerUpInventory:
            "powerUpInventory"
        }
    }
}
