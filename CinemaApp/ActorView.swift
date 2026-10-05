import SwiftUI
import WebKit

struct ActorView: View {
    let actor: Actor
    @State private var isLoading = true
    @State private var selectedMovie: Movie?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let url = URL(string: actor.url) {
                ScopedWebView(
                    url: url,
                    isLoading: $isLoading,
                    onMovieTap: { url in
                        let title = url.lastPathComponent
                            .replacingOccurrences(of: ".html", with: "")
                            .components(separatedBy: "-")
                            .dropFirst()
                            .joined(separator: " ")
                        selectedMovie = Movie(
                            title: title,
                            url: url.absoluteString,
                            poster: "",
                            year: "",
                            rating: ""
                        )
                    }
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
        .navigationDestination(item: $selectedMovie) { movie in
            MovieDetailView(movie: movie)
        }
    }
}
