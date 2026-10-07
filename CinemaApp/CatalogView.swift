import SwiftUI

enum CatalogSection: String, CaseIterable, Identifiable {
    case films = "Фильмы"
    case news = "Новинки"
    case top = "Топ"
    case series = "Сериалы"

    var id: String { rawValue }

    var path: String {
        switch self {
        case .films: return "filmy/"
        case .news: return "v1new/"
        case .top: return "top-filmy/"
        case .series: return "serialy/"
        }
    }

    var url: URL {
        AppConfig.url(path) ?? AppConfig.baseURL
    }
}

struct CatalogView: View {
    @State private var section: CatalogSection = .films
    @State private var isLoading = true
    @State private var path: [Movie] = []
    @State private var searchQuery = ""
    @State private var suggestions: [Movie] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var currentURL: URL?
    @State private var showSettings = false
    @State private var webViewID = UUID()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    if currentURL == nil {
                        sectionBar
                    } else {
                        activeSearchBar
                    }
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
                        .id(webViewID)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
            .searchable(text: $searchQuery, prompt: "Поиск фильма") {
                ForEach(suggestions) { s in
                    Label(s.title, systemImage: "film")
                        .searchCompletion(s.title)
                }
            }
            .onSubmit(of: .search) { performSearch() }
            .onChange(of: searchQuery) { q in
                searchTask?.cancel()
                let trimmed = q.trimmingCharacters(in: .whitespaces)
                if trimmed.count < 2 {
                    suggestions = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    if Task.isCancelled { return }
                    await fetchSuggestions(trimmed)
                }
            }
            .navigationDestination(for: Movie.self) { movie in
                MovieDetailView(movie: movie)
            }
            .navigationDestination(for: Actor.self) { actor in
                ActorView(actor: actor)
            }
            .onReceive(NotificationCenter.default.publisher(for: .appConfigChanged)) { _ in
                currentURL = nil
                isLoading = true
                webViewID = UUID()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private func performSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let q = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        currentURL = AppConfig.url("index.php?do=search&subaction=search&story=\(q)")
        isLoading = true
        searchQuery = ""
        suggestions = []
    }

    private func fetchSuggestions(_ query: String) async {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = AppConfig.url("index.php?do=search&subaction=search&story=\(q)") else { return }
        do {
            let json = try await SiteParser.shared.extract(
                from: url,
                js: ExtractionScripts.catalog,
                waitAfterLoad: 3.0
            )
            if Task.isCancelled { return }
            if let data = json.data(using: .utf8) {
                let results = try JSONDecoder().decode([Movie].self, from: data)
                await MainActor.run {
                    if !Task.isCancelled {
                        self.suggestions = Array(results.prefix(8))
                    }
                }
            }
        } catch {}
    }

    private func reloadCurrent() {
        currentURL = nil
        isLoading = true
        webViewID = UUID()
    }

    private var sectionBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CatalogSection.allCases) { s in
                        Button {
                            if section != s {
                                section = s
                                isLoading = true
                                webViewID = UUID()
                            }
                        } label: {
                            Text(s.rawValue)
                                .font(.subheadline).bold()
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(section == s ? Color.blue : Color.white.opacity(0.08))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, 4)
                .padding(.vertical, 8)
            }

            Button {
                reloadCurrent()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline).bold()
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.subheadline).bold()
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
        }
        .background(Color.black)
    }

    private var activeSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.6))
            Text("Результаты поиска")
                .font(.subheadline).bold()
                .foregroundStyle(.white)
            Spacer()
            Button {
                currentURL = nil
                isLoading = true
                webViewID = UUID()
            } label: {
                Text("Сбросить")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black)
    }
}
