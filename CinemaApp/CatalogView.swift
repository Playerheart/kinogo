import SwiftUI

enum CatalogSection: String, CaseIterable, Identifiable {
    case films = "Фильмы"
    case news = "Новинки"
    case top = "Топ"
    case series = "Сериалы"

    var id: String { rawValue }

    var path: String {
        switch self {
        case .films: return "/filmy/"
        case .news: return "/v1new/"
        case .top: return "/top-filmy/"
        case .series: return "/serialy/"
        }
    }
}

enum SortOption: String, CaseIterable, Identifiable {
    case latest = "Последние обновления"
    case date = "По дате"
    case views = "По популярности"
    case rating = "По рейтингу"
    case title = "По алфавиту"

    var id: String { rawValue }

    var query: String {
        switch self {
        case .latest: return ""
        case .date: return "?do=sort&sort=date&order=desc"
        case .views: return "?do=sort&sort=views&order=desc"
        case .rating: return "?do=sort&sort=rating&order=desc"
        case .title: return "?do=sort&sort=title&order=asc"
        }
    }
}

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var movies: [Movie] = []
    @Published var isLoading = false
    @Published var errorText: String?
    @Published var query = ""

    private let base = "https://mix.kinogo.mu"

    func load(section: CatalogSection, sort: SortOption) async {
        isLoading = true
        errorText = nil
        do {
            let url: URL
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                url = URL(string: "\(base)\(section.path)\(sort.query)")!
            } else {
                let q = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                url = URL(string: "\(base)/index.php?do=search&subaction=search&story=\(q)")!
            }
            let json = try await SiteParser.shared.extract(
                from: url,
                js: ExtractionScripts.catalog,
                waitAfterLoad: 5.0
            )
            guard let data = json.data(using: .utf8) else { throw ParserError.invalidResult }
            let parsed = try JSONDecoder().decode([Movie].self, from: data)
            self.movies = parsed
            if parsed.isEmpty { self.errorText = "Ничего не найдено" }
        } catch {
            self.errorText = error.localizedDescription
        }
        isLoading = false
    }
}

struct CatalogView: View {
    @StateObject private var vm = CatalogViewModel()
    @State private var section: CatalogSection = .films
    @State private var sort: SortOption = .latest

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    sectionBar
                    sortBar
                    content
                }
            }
            .navigationTitle("Кино")
            .searchable(text: $vm.query, prompt: "Поиск фильма")
            .onSubmit(of: .search) {
                Task { await vm.load(section: section, sort: sort) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.load(section: section, sort: sort) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task(id: "\(section.rawValue)|\(sort.rawValue)") {
                await vm.load(section: section, sort: sort)
            }
            .navigationDestination(for: Movie.self) { movie in
                MovieDetailView(movie: movie)
            }
        }
    }

    private var sectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CatalogSection.allCases) { s in
                    Button {
                        section = s
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color.black)
    }

    private var sortBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundStyle(.white.opacity(0.6))
                .font(.caption)
            Menu {
                ForEach(SortOption.allCases) { opt in
                    Button {
                        sort = opt
                    } label: {
                        if sort == opt {
                            Label(opt.rawValue, systemImage: "checkmark")
                        } else {
                            Text(opt.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Сортировка:")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(sort.rawValue)
                        .font(.caption).bold()
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(Color.black)
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.movies.isEmpty {
            Spacer()
            ProgressView().tint(.white)
            Spacer()
        } else if let err = vm.errorText, vm.movies.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                Text(err).foregroundStyle(.white).multilineTextAlignment(.center)
                Button("Повторить") {
                    Task { await vm.load(section: section, sort: sort) }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            Spacer()
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(vm.movies) { m in
                        NavigationLink(value: m) {
                            card(m)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
            .refreshable { await vm.load(section: section, sort: sort) }
        }
    }

    private func card(_ m: Movie) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                MoviePoster(url: m.poster, width: 130, height: 190)

                if !m.rating.isEmpty {
                    Text(m.rating)
                        .font(.caption2).bold()
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(.black.opacity(0.7))
                        .foregroundStyle(.yellow)
                        .clipShape(Capsule())
                        .padding(6)
                }
            }
            Text(m.title)
                .font(.footnote)
                .foregroundStyle(.white)
                .lineLimit(2)
            if !m.year.isEmpty {
                Text(m.year).font(.caption2).foregroundStyle(.gray)
            }
        }
        .frame(width: 130, alignment: .leading)
    }
}
