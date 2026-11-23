import ASKCoordinator

enum MainPath: CoordinatorPath {
    case hexMap
    case visitLog
    case profile
    case powerUpInventory
    case titles

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
        case .titles:
            "titles"
        }
    }
}
