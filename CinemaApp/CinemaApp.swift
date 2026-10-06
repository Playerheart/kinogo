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
