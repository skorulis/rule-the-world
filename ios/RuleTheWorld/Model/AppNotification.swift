import Foundation

struct AppNotification: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var icon: String?
    var rarity: Rarity?
}
