import SwiftUI

@main
struct CinemaApp: App {
    var body: some Scene {
        WindowGroup {
            CatalogView()
                .preferredColorScheme(.dark)
        }
    }
}

extension Notification.Name {
    static let reloadPlayer = Notification.Name("reloadPlayer")
}
