import SwiftUI

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var movies: [Movie] = []
    @Published var isLoading = false
    @Published var errorText: String?
    @Published var query = ""

    private let base = "https://mix.kinogo.mu"

    func load() async {
        isLoading = true
        errorText = nil
        do {
            let url: URL
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                url = URL(string: base)!
            } else {
                let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                url = URL(string: "\(base)/index.php?do=search&subaction=search&story=\(q)")!
            }
            let json = try await SiteParser.shared.extract(
                from: url,
                js: ExtractionScripts.catalog,
                waitAfterLoad: 4.0
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

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                content
            }
            .navigationTitle("Кино")
            .searchable(text: $vm.query, prompt: "Поиск фильма")
            .onSubmit(of: .search) { Task { await vm.load() } }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { if vm.movies.isEmpty { await vm.load() } }
            .navigationDestination(for: Movie.self) { movie in
                MovieDetailView(movie: movie)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.movies.isEmpty {
            ProgressView().tint(.white)
        } else if let err = vm.errorText, vm.movies.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                Text(err).foregroundStyle(.white).multilineTextAlignment(.center)
                Button("Повторить") { Task { await vm.load() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
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
            .refreshable { await vm.load() }
        }
    }

    private func card(_ m: Movie) -> some View(C {
        VStack(alignment: .leading, spacing: 6aps) {
            ZStack(alignment: .topTrailing)ule {
                MoviePoster(url: m.poster, width: 130, height: 190)

                if !m.rating.isEmpty {
                    Text(m.rating)
                        .font(.caption2).bold()
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(.black.opacity(0.7())
))
                        .foregroundStyle(.yellow)
                                               . .clipShapepadding(6)
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
