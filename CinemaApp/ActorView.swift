import SwiftUI
import WebKit

struct ActorView: View {
    let actor: Actor
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let url = URL(string: actor.url) {
                ScopedWebView(
                    url: url,
                    isLoading: $isLoading,
                    onMovieTap: { _ in }
                )
                .edgesIgnoringSafeArea(.bottom)
            }
            if isLoading {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView().scaleEffect(1.6).tint(.white)
                }
            }
        }
        .navigationTitle(actor.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
