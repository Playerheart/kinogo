import SwiftUI

struct CatalogView: View {
    @State private var isLoading = true
    @State private var path: [Movie] = []
    @State private var showSettings = false
    @State private var webViewID = UUID()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar

                    ZStack {
                        ScopedWebView(
                            url: AppConfig.baseURL,
                            isLoading: $isLoading,
                            onMovieTap: { url in
                                let title = url.lastPathComponent
                                    .replacingOccurrences(of: ".html", with: "")
                                    .components(separatedBy: "-")
                                    .dropFirst()
                                    .joined(separator: " ")
                                let m = Movie(title: title,
                                              url: url.absoluteString,
                                              poster: "", year: "", rating: "")
                                path.append(m)
                            }
                        )
                        .id(webViewID)
                        .edgesIgnoringSafeArea(.bottom)

                        if isLoading {
                            ZStack {
                                Color.black.opacity(0.4).ignoresSafeArea()
                                ProgressView()
                                    .scaleEffect(1.6)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Movie.self) { movie in
                MovieDetailView(movie: movie)
            }
            .navigationDestination(for: Actor.self) { actor in
                ActorView(actor: actor)
            }
            .onReceive(NotificationCenter.default.publisher(for: .appConfigChanged)) { _ in
                isLoading = true
                webViewID = UUID()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    // Тонкая полоска сразу под Dynamic Island.
    // Кнопки прижаты к правому краю, слева — пусто,
    // чтобы не мешать шапке KINOGO с сайта (она теперь видна снизу).
    private var topBar: some View {
        HStack(spacing: 8) {
            Spacer()
            Button {
                isLoading = true
                webViewID = UUID()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline).bold()
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.subheadline).bold()
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .padding(.bottom, 6)
        .background(Color.black)
    }
}
