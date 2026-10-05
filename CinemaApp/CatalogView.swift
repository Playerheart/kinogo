import SwiftUI

enum CatalogSection: String, CaseIterable, Identifiable {
    case films = "Фильмы"
    case news = "Новинки"
    case top = "Топ"
    case series = "Сериалы"

    var id: String { rawValue }
    var url: URL {
        switch self {
        case .films: return URL(string: "https://mix.kinogo.mu/filmy/")!
        case .news: return URL(string: "https://mix.kinogo.mu/v1new/")!
        case .top: return URL(string: "https://mix.kinogo.mu/top-filmy/")!
        case .series: return URL(string: "https://mix.kinogo.mu/serialy/")!
        }
    }
}

struct CatalogView: View {
    @State private var section: CatalogSection = .films
    @State private var isLoading = true
    @State private var path: [Movie] = []
    @State private var searchQuery = ""
    @State private var currentURL: URL?

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    sectionBar
                    ZStack {
                        ScopedWebView(
                            url: currentURL ?? section.url,
                            isLoading: $isLoading,
                            onMovieTap: { url in
                                let title = url.lastPathComponent
                                    .replacingOccurrences(of: ".html", with: "")
                                    .components(separatedBy: "-")
                                    .dropFirst()
                                    .joined(separator: " ")
                                let m = Movie(title: title, url: url.absoluteString,
                                              poster: "", year: "", rating: "")
                                path.append(m)
                            }
                        )
                        .id(currentURL ?? section.url)
                        .edgesIgnoringSafeArea(.bottom)

                        if isLoading {
                            ZStack {
                                Color.black.opacity(0.4).ignoresSafeArea()
                                ProgressView().scaleEffect(1.6)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Кино")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchQuery, prompt: "Поиск фильма")
            .onSubmit(of: .search) { performSearch() }
            .navigationDestination(for: Movie.self) { movie in
                MovieDetailView(movie: movie)
            }
        }
    }

    private func performSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let q = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        currentURL = URL(string: "https://mix.kinogo.mu/index.php?do=search&subaction=search&story=\(q)")
        isLoading = true
    }

    private var sectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CatalogSection.allCases) { s in
                    Button {
                        if section != s || currentURL != nil {
                            section = s
                            currentURL = nil
                            isLoading = true
                        }
                    } label: {
                        Text(s.rawValue)
                            .font(.subheadline).bold()
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(section == s && currentURL == nil ? Color.blue : Color.white.opacity(0.08))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color.black)
    }
}
