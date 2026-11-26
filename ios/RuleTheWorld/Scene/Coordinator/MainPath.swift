import ASKCoordinator
import Foundation

enum MainPath: CoordinatorPath {
    case signedOut
    case hexMap
    case visitLog
    case profile
    case bannerEditor(String)
    case powerUpInventory(PowerUpInventoryViewModel)
    case titles
    case regionTitles(TitlesViewModel.Item)
    case shop
    case notification(AppNotification, UUID)

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
        case let .bannerEditor(userID):
            "bannerEditor:\(userID)"
        case .powerUpInventory:
            "powerUpInventory"
        case .titles:
            "titles"
        case let .regionTitles(item):
            "regionTitles:\(item.id)"
        case .shop:
            "shop"
        case let .notification(notification, sessionID):
            "notification:\(sessionID):\(notification.id)"
        }
    }
}
