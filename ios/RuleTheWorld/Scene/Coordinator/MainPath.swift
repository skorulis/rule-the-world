import ASKCoordinator

enum MainPath: CoordinatorPath {
    case signedOut
    case hexMap
    case visitLog
    case profile
    case powerUpInventory(PowerUpInventoryViewModel)
    case titles
    case regionTitles(TitlesViewModel.Item)
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
        case let .regionTitles(item):
            "regionTitles:\(item.id)"
        case .shop:
            "shop"
        }
    }
}
