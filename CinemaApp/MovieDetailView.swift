import SwiftUI

@MainActor
final class MovieDetailViewModel: ObservableObject {
    @Published var detail: MovieDetail?
    @Published var isLoading = false
    @Published var errorText: String?
    @Published var selectedPlayer: Player?
    @Published var pendingDownload: URL?

    func load(_ movie: Movie) async {
        isLoading = true
        errorText = nil
        do {
            guard let url = URL(string: movie.url) else { throw ParserError.noData }
            let json = try await SiteParser.shared.extract(
                from: url,
                js: ExtractionScripts.detail,
                waitAfterLoad: 4.0
            )
            guard let data = json.data(using: .utf8) else { throw ParserError.invalidResult }
            let d = try JSONDecoder().decode(MovieDetail.self, from: data)
            self.detail = d
            self.selectedPlayer = d.players.first
            if d.players.isEmpty && d.downloads.isEmpty {
                self.errorText = "Не удалось найти плеер. Попробуйте открыть страницу фильма в браузере."
            }
        } catch {
            self.errorText = error.localizedDescription
        }
        isLoading = false
    }
}

struct MovieDetailView: View {
    let movie: Movie
    @StateObject private var vm = MovieDetailViewModel()
    @State private var showBrowser = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(movie) }
        .sheet(item: Binding(
            get: { vm.pendingDownload.map { DownloadItem(url: $0) } },
            set: { if $0 == nil { vm.pendingDownload = nil } }
        )) { item in
            ShareSheet(activityItems: [item.url])
        }
        .sheet(isPresented: $showBrowser) {
            if let url = URL(string: movie.url) {
                SafariView(url: url)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.detail == nil {
            ProgressView().tint(.white)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    header

                    if let d = vm.detail, !d.players.isEmpty {
                        SectionTitle("Озвучка")
                        voicePicker(d.players)
                    }

                    if let p = vm.selectedPlayer, let url = URL(string: p.url) {
                        SectionTitle("Плеер")
                        PlayerView(url: url)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        SectionTitle("Плеер")
                        playerFallback
                    }

                    if let d = vm.detail, !d.downloads.isEmpty {
                        SectionTitle("Скачать")
                        downloadsList(d.downloads)
                    }

                    if let err = vm.errorText {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .padding(.top, 8)
                    }

                    Spacer(minLength: 40)
                }
                .padding(16)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            MoviePoster(
                url: vm.detail?.poster.isEmpty == false ? vm.detail!.poster : movie.poster,
                width: 110,
                height: 160
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(vm.detail?.title.isEmpty == false ? vm.detail!.title : movie.title)
                    .font(.headline).foregroundStyle(.white)
                if !movie.year.isEmpty {
                    Text(movie.year).font(.caption).foregroundStyle(.gray)
                }
                if let d = vm.detail, !d.description.isEmpty {
                    Text(d.description)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .lineLimit(6)
                }
            }
        }
    }

    private func voicePicker(_ players: [Player]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(players) { p in
                    Button {
                        vm.selectedPlayer = p
                    } label: {
                        Text(p.name)
                            .font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(vm.selectedPlayer?.id == p.id ? Color.blue : Color.white.opacity(0.1))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var playerFallback: some View {
        VStack(spacing: 10) {
            Text("Плеер не найден автоматически")
                .font(.footnote).foregroundStyle(.gray)
            Button("Открыть страницу фильма в браузере") {
                showBrowser = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func downloadsList(_ items: [DownloadOption]) -> some View {
        VStack(spacing: 8) {
            ForEach(items) { d in
                Button {
                    if let url = URL(string: d.url) {
                        vm.pendingDownload = url
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text(d.quality).lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct DownloadItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.subheadline).bold()
            .foregroundStyle(.white.opacity(0.7))
            .padding(.top, 6)
    }
}
