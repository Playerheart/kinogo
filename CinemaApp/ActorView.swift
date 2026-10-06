import SwiftUI
import WebKit

struct ActorView: View {
    let actor: Actor
    @State private var isLoading = true
    @State private var selectedMovie: Movie?
    @State private var showMovie = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let url = URL(string: actor.url) {
                ScopedWebView(
                    url: url,
                    isLoading: $isLoading,
                    onMovieTap: { movieURL in
                        let title = ActorView.titleFromURL(movieURL)
                        selectedMovie = Movie(
                            title: title,
                            url: movieURL.absoluteString,
                            poster: "",
                            year: "",
                            rating: ""
                        )
                        showMovie = true
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
        .background(
            NavigationLink(
                isActive: $showMovie,
                destination: {
                    if let m = selectedMovie {
                        MovieDetailView(movie: m)
                    } else {
                        EmptyView()
                    }
                },
                label: { EmptyView() }
            )
            .hidden()
        )
    }

    static func titleFromURL(_ url: URL) -> String {
        let raw = url.lastPathComponent
            .replacingOccurrences(of: ".html", with: "")
        let parts = raw.components(separatedBy: "-")
        // Первый элемент — обычно числовой ID, отрезаем его
        let withoutID = parts.dropFirst()
        let title = withoutID.isEmpty ? raw : withoutID.joined(separator: " ")
        return title
    }
}
