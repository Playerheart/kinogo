import SwiftUI

struct MovieDetailView: View {
    let movie: Movie
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let url = URL(string: movie.url) {
                ScopedWebView(url: url, isLoading: $isLoading)
                    .edgesIgnoringSafeArea(.bottom)
            } else {
                Text("Неверный адрес фильма")
                    .foregroundStyle(.white)
            }

            if isLoading {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.6)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
        }
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
