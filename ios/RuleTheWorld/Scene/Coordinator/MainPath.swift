import ASKCoordinator

enum MainPath: CoordinatorPath {
    case signedOut
    case hexMap
    case visitLog
    case profile
    case powerUpInventory(PowerUpInventoryViewModel)
    case titles
    case shop

    var id: String {
        switch self {
        case .signedOut:
            "signedOut"
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
        case .shop:
            "shop"
        }
    }
}
